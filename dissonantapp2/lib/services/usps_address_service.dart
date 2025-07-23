import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple POJO for the standardized address
class ValidatedAddress {
  final String street;
  final String city;
  final String state;
  final String zip5;
  final String? zip4;
  ValidatedAddress({
    required this.street,
    required this.city,
    required this.state,
    required this.zip5,
    this.zip4,
  });
  factory ValidatedAddress.fromJson(Map<String, dynamic> json) {
    final addr = json['address'] as Map<String, dynamic>;
    return ValidatedAddress(
      street: addr['streetAddress'],
      city: addr['city'],
      state: addr['state'],
      zip5: addr['ZIPCode'],
      zip4: addr['ZIPPlus4'],
    );
  }
}

class UspsAddressService {
  static const _tokenUrl = 'https://apis.usps.com/oauth2/v3/token';
  static const _baseUrl  = 'apis.usps.com';
  static const _addressPath = '/addresses/v3/address';

  // Never hard‑code secrets; pull them from env, Firebase Remote Config, etc.
  final String clientId;
  final String clientSecret;

  String? _cachedToken;
  DateTime? _tokenExpiry;

  UspsAddressService({required this.clientId, required this.clientSecret});

  Future<String> _getToken() async {
    final now = DateTime.now();
    if (_cachedToken != null && _tokenExpiry!.isAfter(now)) return _cachedToken!;

    final res = await http.post(
      Uri.parse(_tokenUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'client_credentials',
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('OAuth error ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    _cachedToken  = data['access_token'];
    _tokenExpiry  = now.add(Duration(seconds: data['expires_in'] ?? 3500));
    return _cachedToken!;
  }

  /// Returns a standardized address or `null` if USPS says it’s undeliverable.
  Future<ValidatedAddress?> validate({
    required String street,
    String? secondary,
    required String city,
    required String state,
    String? zip,
  }) async {
    final token = await _getToken();
    final uri = Uri.https(_baseUrl, _addressPath, {
      'streetAddress': street,
      if (secondary?.isNotEmpty == true) 'secondaryAddress': secondary,
      'city': city,
      'state': state,
      if (zip?.isNotEmpty == true) 'ZIPCode': zip,
    });

    final resp = await http.get(uri, headers: {
      'accept': 'application/json',
      'authorization': 'Bearer $token',
    });

    if (resp.statusCode != 200) {
      throw Exception('USPS validation failed: ${resp.body}');
    }
    final json = jsonDecode(resp.body);

    // “Y” means DPV confirmed deliverable.
    final confirmed = (json['addressAdditionalInfo']?['DPVConfirmation'] ?? '') == 'Y';
    return confirmed ? ValidatedAddress.fromJson(json) : null;
  }
}
