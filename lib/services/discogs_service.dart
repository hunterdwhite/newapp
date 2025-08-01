import 'dart:convert';
import 'package:oauth1/oauth1.dart' as oauth1;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Simple service for managing Discogs API interactions with hardcoded credentials
class DiscogsService {
  static const String _baseUrl = 'https://api.discogs.com';
  
  // Hardcoded OAuth credentials
  static const String _consumerKey = 'EzVdIgMVbCnRNcwacndA';
  static const String _consumerSecret = 'CUqIDOCeEoFmREnzjKqTmKpstenTGnsE';
  
  late final oauth1.ClientCredentials _clientCredentials;
  late final oauth1.SignatureMethod _signatureMethod;
  
  DiscogsService() {
    _clientCredentials = oauth1.ClientCredentials(_consumerKey, _consumerSecret);
    _signatureMethod = oauth1.SignatureMethods.hmacSha1;
  }
  
  /// Start OAuth flow and return authorization URL
  Future<Map<String, dynamic>> startOAuthFlow() async {
    final platform = oauth1.Platform(
      '$_baseUrl/oauth/request_token',
      'https://www.discogs.com/oauth/authorize',
      '$_baseUrl/oauth/access_token',
      _signatureMethod,
    );
    
    final auth = oauth1.Authorization(_clientCredentials, platform);
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
    final platform = oauth1.Platform(
      '$_baseUrl/oauth/request_token',
      'https://www.discogs.com/oauth/authorize', 
      '$_baseUrl/oauth/access_token',
      _signatureMethod,
    );
    
    final auth = oauth1.Authorization(_clientCredentials, platform);
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
    final client = oauth1.Client(
      _signatureMethod,
      _clientCredentials,
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
    String accessSecret, {
    int perPage = 100, // Fetch 100 items per page
  }) async {
    final client = oauth1.Client(
      _signatureMethod,
      _clientCredentials,
      oauth1.Credentials(accessToken, accessSecret),
    );
    
    final items = <Map<String, String>>[];
    int page = 1;
    bool hasMorePages = true;
    
    while (hasMorePages) {
      final uri = Uri.parse('$_baseUrl/users/$username/collection/folders/0/releases')
          .replace(queryParameters: {
        'page': page.toString(),
        'per_page': perPage.toString(),
      });
      
      final response = await client.get(uri);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final releases = data['releases'] as List<dynamic>;
        
        // If no releases returned, we've reached the end
        if (releases.isEmpty) {
          hasMorePages = false;
          break;
        }
        
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
        
        // If we got fewer items than requested, we've reached the end
        if (releases.length < perPage) {
          hasMorePages = false;
        }
        
        page++;
      } else {
        throw Exception('Failed to fetch collection: ${response.statusCode}');
      }
    }
    
    return items;
  }
  
  /// Get user's Discogs wantlist
  Future<List<Map<String, String>>> getWantlist(
    String username,
    String accessToken,
    String accessSecret,
  ) async {
    final client = oauth1.Client(
      _signatureMethod,
      _clientCredentials,
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