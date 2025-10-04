import 'dart:convert';
import 'package:http/http.dart' as http;

class ShippingRate {
  final String serviceName;
  final double amount;
  final int estimatedDays;
  final String carrier;
  final String serviceLevel;

  ShippingRate({
    required this.serviceName,
    required this.amount,
    required this.estimatedDays,
    required this.carrier,
    required this.serviceLevel,
  });

  factory ShippingRate.fromJson(Map<String, dynamic> json) {
    return ShippingRate(
      serviceName: json['servicelevel']['name'] ?? 'Standard',
      amount: double.parse(json['amount'] ?? '0.0'),
      estimatedDays: json['estimated_days'] ?? 5,
      carrier: json['provider'] ?? 'USPS',
      serviceLevel: json['servicelevel']['token'] ?? 'usps_ground_advantage',
    );
  }

  factory ShippingRate.fromApiResponse(Map<String, dynamic> json) {
    return ShippingRate(
      serviceName: json['serviceName'] ?? 'Standard',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      estimatedDays: json['estimatedDays'] ?? 5,
      carrier: json['carrier'] ?? 'USPS',
      serviceLevel: json['serviceLevel'] ?? 'usps_ground_advantage',
    );
  }
}

class ShippingService {
  final String endpointBase;
  final http.Client httpClient;

  ShippingService({
    required this.endpointBase,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Calculate shipping rates using GoShippo API
  Future<List<ShippingRate>> calculateShippingRates({
    required Map<String, String> toAddress,
    Map<String, String>? fromAddress,
    Map<String, dynamic>? parcel,
  }) async {
    try {
      final uri = Uri.parse('${endpointBase.replaceAll(RegExp(r'/+$'), '')}/calculate-shipping');
      print('🌐 DEBUG ShippingService: Calling API at $uri');

      // Default warehouse address (your actual warehouse)
      final defaultFromAddress = fromAddress ?? {
        'name': 'Dissonant Music',
        'street1': '789 9th Ave',
        'city': 'New York',
        'state': 'NY',
        'zip': '10019',
        'country': 'US',
      };

      // Default package dimensions for your albums
      final defaultParcel = parcel ?? {
        'length': '9.0',
        'width': '7.0',
        'height': '0.5',
        'distance_unit': 'in',
        'weight': '0.31',
        'mass_unit': 'lb',
      };

      final payload = {
        'address_from': defaultFromAddress,
        'address_to': toAddress,
        'parcel': defaultParcel,
      };

      print('📤 DEBUG ShippingService: Sending payload: ${jsonEncode(payload)}');

      final response = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      print('📥 DEBUG ShippingService: Response status: ${response.statusCode}');
      print('📥 DEBUG ShippingService: Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Shipping calculation failed: ${response.statusCode} ${response.body}');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      
      if (responseData['success'] != true) {
        throw Exception('Shipping calculation failed: ${responseData['error'] ?? 'Unknown error'}');
      }

      final List<dynamic> rates = responseData['rates'] ?? [];
      print('📊 DEBUG ShippingService: Found ${rates.length} rates');
      
      if (rates.isEmpty) {
        print('❌ DEBUG ShippingService: No rates returned from API');
        return _getFallbackRates();
      }
      
      final parsedRates = rates
          .map((rate) => ShippingRate.fromApiResponse(rate))
          .where((rate) => rate.amount > 0) // Filter out invalid rates
          .toList();

      print('✅ DEBUG ShippingService: Returning ${parsedRates.length} valid rates');
      for (final rate in parsedRates) {
        print('   💰 ${rate.serviceName} (${rate.carrier}): \$${rate.amount}');
        if (rate.serviceName == 'Ground Advantage' && rate.carrier == 'USPS') {
          print('   ✅ USPS Ground Advantage rate confirmed!');
        }
      }

      return parsedRates;

    } catch (e) {
      print('❌ DEBUG ShippingService: Error calculating shipping rates: $e');
      print('❌ DEBUG ShippingService: Error type: ${e.runtimeType}');
      // Return fallback rates if API fails
      return _getFallbackRates();
    }
  }

  /// Get the cheapest available shipping rate
  Future<ShippingRate?> getCheapestRate({
    required Map<String, String> toAddress,
    Map<String, String>? fromAddress,
    Map<String, dynamic>? parcel,
  }) async {
    final rates = await calculateShippingRates(
      toAddress: toAddress,
      fromAddress: fromAddress,
      parcel: parcel,
    );
    
    return rates.isNotEmpty ? rates.first : null;
  }

  /// Get shipping rate for a specific service level
  Future<ShippingRate?> getRateForService({
    required Map<String, String> toAddress,
    required String serviceLevel,
    Map<String, String>? fromAddress,
    Map<String, dynamic>? parcel,
  }) async {
    final rates = await calculateShippingRates(
      toAddress: toAddress,
      fromAddress: fromAddress,
      parcel: parcel,
    );
    
    return rates.firstWhere(
      (rate) => rate.serviceLevel == serviceLevel,
      orElse: () => rates.isNotEmpty ? rates.first : _getFallbackRates().first,
    );
  }

  /// Fallback rates when API is unavailable
  List<ShippingRate> _getFallbackRates() {
    print('⚠️ DEBUG ShippingService: Using fallback USPS Ground Advantage rate');
    return [
      ShippingRate(
        serviceName: 'Ground Advantage',
        amount: 4.99, // Typical USPS Ground Advantage rate for small packages
        estimatedDays: 5,
        carrier: 'USPS',
        serviceLevel: 'usps_ground_advantage',
      ),
    ];
  }

  /// Create shipping label using GoShippo
  Future<Map<String, dynamic>?> createShippingLabel({
    required Map<String, String> toAddress,
    required String serviceLevel,
    required String orderId,
    Map<String, String>? fromAddress,
    Map<String, dynamic>? parcel,
  }) async {
    try {
      final uri = Uri.parse('${endpointBase.replaceAll(RegExp(r'/+$'), '')}/create-shipping-labels');

      final defaultFromAddress = fromAddress ?? {
        'name': 'Dissonant Warehouse',
        'street1': '123 Music St',
        'city': 'Nashville',
        'state': 'TN',
        'zip': '37203',
        'country': 'US',
      };

      final defaultParcel = parcel ?? {
        'length': '5.5',
        'width': '5.0',
        'height': '0.5',
        'distance_unit': 'in',
        'weight': '0.2',
        'mass_unit': 'lb',
      };

      final payload = {
        'address_from': defaultFromAddress,
        'address_to': toAddress,
        'parcel': defaultParcel,
        'service_level': serviceLevel,
        'order_id': orderId,
      };

      final response = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception('Label creation failed: ${response.statusCode} ${response.body}');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      
      if (responseData['success'] != true) {
        throw Exception('Label creation failed: ${responseData['error'] ?? 'Unknown error'}');
      }

      return responseData;

    } catch (e) {
      print('Error creating shipping label: $e');
      return null;
    }
  }

  /// Validate shipping address using GoShippo
  Future<Map<String, dynamic>?> validateAddress({
    required Map<String, String> address,
  }) async {
    try {
      final uri = Uri.parse('${endpointBase.replaceAll(RegExp(r'/+$'), '')}/validate-address');

      final response = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(address),
      );

      if (response.statusCode != 200) {
        throw Exception('Address validation failed: ${response.statusCode} ${response.body}');
      }

      final Map<String, dynamic> responseData = jsonDecode(response.body);
      
      if (responseData['isValid'] == true) {
        return responseData['address'];
      }

      return null;

    } catch (e) {
      print('Error validating address: $e');
      return null;
    }
  }

  /// Track package using GoShippo
  Future<Map<String, dynamic>?> trackPackage({
    required String trackingNumber,
    required String carrier,
  }) async {
    try {
      final uri = Uri.parse('${endpointBase.replaceAll(RegExp(r'/+$'), '')}/track-package');

      final payload = {
        'tracking_number': trackingNumber,
        'carrier': carrier,
      };

      final response = await httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception('Package tracking failed: ${response.statusCode} ${response.body}');
      }

      return jsonDecode(response.body);

    } catch (e) {
      print('Error tracking package: $e');
      return null;
    }
  }
}
