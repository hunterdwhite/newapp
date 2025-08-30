import 'dart:convert';
import 'package:http/http.dart' as http;

/// Standardized address model used by the order form after validation.
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

  /// Build from Shippo address response
  factory ValidatedAddress.fromShippo(Map<String, dynamic> json) {
    final street1 = (json['street1'] ?? '').toString().trim();
    final street2 = (json['street2'] ?? '').toString().trim();
    final mergedStreet = street2.isNotEmpty ? '$street1 $street2' : street1;

    final zipRaw = (json['zip'] ?? '').toString();
    String zip5 = zipRaw;
    String? zip4;
    if (zipRaw.contains('-')) {
      final parts = zipRaw.split('-');
      if (parts.isNotEmpty) {
        zip5 = parts[0];
        if (parts.length > 1 && parts[1].isNotEmpty) {
          zip4 = parts[1];
        }
      }
    }

    return ValidatedAddress(
      street: mergedStreet,
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      zip5: zip5,
      zip4: zip4,
    );
  }
}

/// Shippo-backed address validation service.
class ShippoAddressService {
  final String endpointBase; // e.g., https://<api-id>.execute-api.<region>.amazonaws.com/dev
  final http.Client httpClient;

  ShippoAddressService({required this.endpointBase, http.Client? httpClient})
      : httpClient = httpClient ?? http.Client();

  /// Returns a standardized address or `null` if backend says it’s invalid.
  Future<ValidatedAddress?> validate({
    required String street,
    required String city,
    required String state,
    required String zip,
    String country = 'US',
    String? name,
    String? street2,
  }) async {
    final uri = Uri.parse('${endpointBase.replaceAll(RegExp(r'/+$'), '')}/validate-address');

    final payload = {
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'street1': street.trim(),
      if (street2 != null && street2.trim().isNotEmpty) 'street2': street2.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'zip': zip.trim(),
      'country': country,
    };

    final resp = await httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (resp.statusCode != 200) {
      throw Exception('Validation failed: ${resp.statusCode} ${resp.body}');
    }
    final Map<String, dynamic> json = jsonDecode(resp.body);
    if (json['isValid'] != true) return null;
    final addr = json['address'] as Map<String, dynamic>;
    return ValidatedAddress(
      street: (addr['street'] ?? '').toString(),
      city: (addr['city'] ?? '').toString(),
      state: (addr['state'] ?? '').toString(),
      zip5: (addr['zip5'] ?? '').toString(),
      zip4: (addr['zip4'] as String?)?.isNotEmpty == true ? addr['zip4'] : null,
    );
  }
}

