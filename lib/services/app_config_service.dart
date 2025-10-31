import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to manage app-wide configuration that can be changed remotely
/// without redeploying the app.
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache config to avoid repeated Firestore reads
  Map<String, dynamic>? _cachedConfig;
  DateTime? _lastFetch;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Get the app configuration from Firestore
  /// Uses caching to reduce Firestore reads
  Future<Map<String, dynamic>> getConfig() async {
    // Return cached config if it's still fresh
    if (_cachedConfig != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < _cacheDuration) {
      return _cachedConfig!;
    }

    try {
      final configDoc = await _firestore
          .collection('config')
          .doc('app')
          .get();

      if (configDoc.exists) {
        _cachedConfig = configDoc.data() ?? _getDefaultConfig();
        _lastFetch = DateTime.now();
        return _cachedConfig!;
      } else {
        // Config doesn't exist, create it with defaults
        await _initializeConfig();
        return _getDefaultConfig();
      }
    } catch (e) {
      print('❌ Error fetching app config: $e');
      // Return defaults if there's an error
      return _getDefaultConfig();
    }
  }

  /// Get default configuration values
  Map<String, dynamic> _getDefaultConfig() {
    return {
      'freeOrderForNewUsers': true,
      'freeOrdersCount': 1,
      'eventName': '1 Year Anniversary Event',
      'eventDescription': 'Free order for all new users!',
      'maintenanceMode': false,
      'minAppVersion': '1.0.0',
      'forceUpdate': false,
    };
  }

  /// Initialize config document in Firestore with defaults
  Future<void> _initializeConfig() async {
    try {
      await _firestore
          .collection('config')
          .doc('app')
          .set({
        ..._getDefaultConfig(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ App config initialized in Firestore');
    } catch (e) {
      print('❌ Error initializing app config: $e');
    }
  }

  /// Check if new users should get free orders
  Future<bool> shouldGrantFreeOrderToNewUsers() async {
    final config = await getConfig();
    return config['freeOrderForNewUsers'] ?? true;
  }

  /// Get the number of free orders to grant new users
  Future<int> getFreeOrdersCountForNewUsers() async {
    final config = await getConfig();
    return config['freeOrdersCount'] ?? 1;
  }

  /// Check if app is in maintenance mode
  Future<bool> isMaintenanceMode() async {
    final config = await getConfig();
    return config['maintenanceMode'] ?? false;
  }

  /// Get event name for display
  Future<String> getEventName() async {
    final config = await getConfig();
    return config['eventName'] ?? '';
  }

  /// Get event description
  Future<String> getEventDescription() async {
    final config = await getConfig();
    return config['eventDescription'] ?? '';
  }

  /// Force refresh config (bypasses cache)
  Future<Map<String, dynamic>> refreshConfig() async {
    _cachedConfig = null;
    _lastFetch = null;
    return await getConfig();
  }

  /// Clear config cache
  void clearCache() {
    _cachedConfig = null;
    _lastFetch = null;
  }

  /// Listen to real-time config updates
  Stream<Map<String, dynamic>> watchConfig() {
    return _firestore
        .collection('config')
        .doc('app')
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() ?? _getDefaultConfig();
        _cachedConfig = data;
        _lastFetch = DateTime.now();
        return data;
      }
      return _getDefaultConfig();
    });
  }
}

