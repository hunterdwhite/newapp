import 'package:cloud_firestore/cloud_firestore.dart';

class PricingConfig {
  final List<double> dissonantPrices;
  final List<double> communityPrices;
  final double defaultShippingCost;
  final bool giveNewUsersFreeOrder;
  final int newUserFreeOrderCount;
  final bool showAnniversaryCard;

  PricingConfig({
    required this.dissonantPrices,
    required this.communityPrices,
    required this.defaultShippingCost,
    required this.giveNewUsersFreeOrder,
    required this.newUserFreeOrderCount,
    required this.showAnniversaryCard,
  });

  factory PricingConfig.fromFirestore(Map<String, dynamic> data) {
    return PricingConfig(
      dissonantPrices: _parsePrices(data['dissonantPrices']),
      communityPrices: _parsePrices(data['communityPrices']),
      defaultShippingCost: _parseDouble(data['defaultShippingCost'], 4.99),
      giveNewUsersFreeOrder: data['giveNewUsersFreeOrder'] ?? false,
      newUserFreeOrderCount: _parseInt(data['newUserFreeOrderCount'], 1),
      showAnniversaryCard: data['showAnniversaryCard'] ?? false,
    );
  }

  static List<double> _parsePrices(dynamic pricesData) {
    if (pricesData is List) {
      return pricesData.map((price) => _parseDouble(price, 0.0)).toList();
    }
    return [];
  }

  static double _parseDouble(dynamic value, double defaultValue) {
    if (value is num) {
      return value.toDouble();
    }
    return defaultValue;
  }

  static int _parseInt(dynamic value, int defaultValue) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return defaultValue;
  }

  // Default fallback configuration
  factory PricingConfig.defaultConfig() {
    return PricingConfig(
      dissonantPrices: [7.99, 9.99, 12.99],
      communityPrices: [5.99, 7.99, 9.99],
      defaultShippingCost: 4.99,
      giveNewUsersFreeOrder: false, // Default to OFF
      newUserFreeOrderCount: 1,
      showAnniversaryCard: false, // Default to OFF
    );
  }
}

class PricingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _configDocument = 'pricing_config';
  static const String _configCollection = 'app_config';

  // Cache the pricing config to avoid repeated reads
  PricingConfig? _cachedConfig;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 30);

  /// Fetches the pricing configuration from Firestore
  /// Returns cached config if available and not expired
  Future<PricingConfig> getPricingConfig() async {
    // Return cached config if it's still valid
    if (_cachedConfig != null && _lastFetchTime != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      if (timeSinceLastFetch < _cacheDuration) {
        return _cachedConfig!;
      }
    }

    try {
      final docSnapshot = await _firestore
          .collection(_configCollection)
          .doc(_configDocument)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        if (data != null) {
          _cachedConfig = PricingConfig.fromFirestore(data);
          _lastFetchTime = DateTime.now();
          return _cachedConfig!;
        }
      }
    } catch (e) {
      print('Error fetching pricing config from Firestore: $e');
    }

    // Fallback to default configuration
    _cachedConfig = PricingConfig.defaultConfig();
    _lastFetchTime = DateTime.now();
    return _cachedConfig!;
  }

  /// Gets price options for a specific product type
  Future<List<double>> getPriceOptions(String productType) async {
    final config = await getPricingConfig();
    if (productType == 'community') {
      return config.communityPrices;
    } else {
      return config.dissonantPrices;
    }
  }

  /// Gets the default shipping cost
  Future<double> getDefaultShippingCost() async {
    final config = await getPricingConfig();
    return config.defaultShippingCost;
  }

  /// Gets whether new users should receive a free order
  Future<bool> shouldGiveNewUsersFreeOrder() async {
    final config = await getPricingConfig();
    return config.giveNewUsersFreeOrder;
  }

  /// Gets the number of free orders to give new users
  Future<int> getNewUserFreeOrderCount() async {
    final config = await getPricingConfig();
    return config.newUserFreeOrderCount;
  }

  /// Gets whether to show the anniversary event card on home screen
  Future<bool> shouldShowAnniversaryCard() async {
    final config = await getPricingConfig();
    return config.showAnniversaryCard;
  }

  /// Clears the cached configuration to force a fresh fetch
  void clearCache() {
    _cachedConfig = null;
    _lastFetchTime = null;
  }

  /// Listens to real-time updates of the pricing configuration
  Stream<PricingConfig> watchPricingConfig() {
    return _firestore
        .collection(_configCollection)
        .doc(_configDocument)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          final config = PricingConfig.fromFirestore(data);
          _cachedConfig = config;
          _lastFetchTime = DateTime.now();
          return config;
        }
      }
      return PricingConfig.defaultConfig();
    });
  }
}


