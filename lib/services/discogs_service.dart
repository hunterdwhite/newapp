import 'dart:convert';
import 'package:oauth1/oauth1.dart' as oauth1;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Secure service for managing Discogs API interactions
/// Handles OAuth credentials securely through Firebase Cloud Functions
class DiscogsService {
  static const String _baseUrl = 'https://api.discogs.com';
  
  // Cache for OAuth credentials
  oauth1.ClientCredentials? _clientCredentials;
  oauth1.SignatureMethod? _signatureMethod;
  
  /// Initialize the service by fetching secure credentials
  Future<void> initialize() async {
    try {
      // Fetch OAuth credentials securely from Cloud Function
      final credentials = await _getOAuthCredentials();
      _clientCredentials = oauth1.ClientCredentials(
        credentials['consumerKey']!,
        credentials['consumerSecret']!,
      );
      _signatureMethod = oauth1.SignatureMethods.hmacSha1;
    } catch (e) {
      print('Error initializing DiscogsService: $e');
      rethrow;
    }
  }
  
  /// Securely fetch OAuth credentials from Cloud Function
  Future<Map<String, String>> _getOAuthCredentials() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User must be authenticated to access Discogs credentials');
    }
    
    try {
      // Call secure Cloud Function to get credentials
      final callable = FirebaseFunctions.instance.httpsCallable('getDiscogsCredentials');
      final result = await callable.call();
      
      final data = result.data as Map<String, dynamic>;
      return {
        'consumerKey': data['consumerKey'] as String,
        'consumerSecret': data['consumerSecret'] as String,
      };
    } catch (e) {
      print('Error fetching Discogs credentials: $e');
      throw Exception('Failed to fetch Discogs credentials securely');
    }
  }
  
  /// Start OAuth flow and return authorization URL
  Future<Map<String, dynamic>> startOAuthFlow() async {
    if (_clientCredentials == null) {
      await initialize();
    }
    
    final platform = oauth1.Platform(
      '$_baseUrl/oauth/request_token',
      'https://www.discogs.com/oauth/authorize',
      '$_baseUrl/oauth/access_token',
      _signatureMethod!,
    );
    
    final auth = oauth1.Authorization(_clientCredentials!, platform);
    final response = await auth.requestTemporaryCredentials('oob');
    
    final authUrl = auth.getResourceOwnerAuthorizationURI(response.credentials.token);
    
    return {
      'authUrl': authUrl,
      'tempCredentials': {
        'token': response.credentials.token,
        'tokenSecret': response.credentials.tokenSecret,
      },
    };
  }
  
  /// Exchange PIN for access tokens
  Future<Map<String, String>> exchangePinForTokens(
    Map<String, String> tempCredentials,
    String pin,
  ) async {
    if (_clientCredentials == null) {
      await initialize();
    }
    
    final platform = oauth1.Platform(
      '$_baseUrl/oauth/request_token',
      'https://www.discogs.com/oauth/authorize', 
      '$_baseUrl/oauth/access_token',
      _signatureMethod!,
    );
    
    final auth = oauth1.Authorization(_clientCredentials!, platform);
    final tempCreds = oauth1.Credentials(
      tempCredentials['token']!,
      tempCredentials['tokenSecret']!,
    );
    
    final response = await auth.requestTokenCredentials(tempCreds, pin);
    
    return {
      'accessToken': response.credentials.token,
      'accessSecret': response.credentials.tokenSecret,
    };
  }
  
  /// Get authenticated Discogs username
  Future<String> getUsername(String accessToken, String accessSecret) async {
    if (_clientCredentials == null) {
      await initialize();
    }
    
    final client = oauth1.Client(
      _signatureMethod!,
      _clientCredentials!,
      oauth1.Credentials(accessToken, accessSecret),
    );
    
    final response = await client.get(Uri.parse('$_baseUrl/oauth/identity'));
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['username'] ?? '';
    } else {
      throw Exception('Failed to fetch username: ${response.statusCode}');
    }
  }
  
  /// Get user's Discogs collection
  Future<List<Map<String, String>>> getCollection(
    String username,
    String accessToken,
    String accessSecret,
  ) async {
    if (_clientCredentials == null) {
      await initialize();
    }
    
    final client = oauth1.Client(
      _signatureMethod!,
      _clientCredentials!,
      oauth1.Credentials(accessToken, accessSecret),
    );
    
    final response = await client.get(
      Uri.parse('$_baseUrl/users/$username/collection/folders/0/releases'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final releases = data['releases'] as List<dynamic>;
      final items = <Map<String, String>>[];
      
      for (var item in releases) {
        final info = item['basic_information'];
        if (info != null) {
          items.add({
            'image': info['cover_image'] ?? '',
            'album': (info['title'] ?? '').toString().replaceAll(RegExp(r'[^\x00-\x7F]'), ''),
            'artist': (info['artists']?[0]?['name'] ?? '').toString().replaceAll(RegExp(r'[^\x00-\x7F]'), ''),
          });
        }
      }
      
      return items;
    } else {
      throw Exception('Failed to fetch collection: ${response.statusCode}');
    }
  }
  
  /// Get user's Discogs wantlist
  Future<List<Map<String, String>>> getWantlist(
    String username,
    String accessToken,
    String accessSecret,
  ) async {
    if (_clientCredentials == null) {
      await initialize();
    }
    
    final client = oauth1.Client(
      _signatureMethod!,
      _clientCredentials!,
      oauth1.Credentials(accessToken, accessSecret),
    );
    
    final response = await client.get(
      Uri.parse('$_baseUrl/users/$username/wants'),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final wants = data['wants'] as List<dynamic>;
      final items = <Map<String, String>>[];
      
      for (var item in wants) {
        final info = item['basic_information'];
        if (info != null) {
          items.add({
            'image': info['cover_image'] ?? '',
            'album': (info['title'] ?? '').toString().replaceAll(RegExp(r'[^\x00-\x7F]'), ''),
            'artist': (info['artists']?[0]?['name'] ?? '').toString().replaceAll(RegExp(r'[^\x00-\x7F]'), ''),
          });
        }
      }
      
      return items;
    } else {
      throw Exception('Failed to fetch wantlist: ${response.statusCode}');
    }
  }
  
  /// Store Discogs authentication data in Firestore
  Future<void> storeAuthData(
    String accessToken,
    String accessSecret,
    String username,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated');
    }
    
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'discogsAccessToken': accessToken,
      'discogsTokenSecret': accessSecret,
      'discogsUsername': username,
      'discogsLinked': true,
    });
  }
  
  /// Load stored Discogs authentication data
  Future<Map<String, String>?> loadAuthData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final data = userDoc.data();
      if (data == null || data['discogsLinked'] != true) {
        return null;
      }
      
      return {
        'accessToken': data['discogsAccessToken'] ?? '',
        'accessSecret': data['discogsTokenSecret'] ?? '',
        'username': data['discogsUsername'] ?? '',
      };
    } catch (e) {
      print('Error loading Discogs auth data: $e');
      return null;
    }
  }
}