import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'base_service.dart';

class PaymentService extends BaseService {
  @override
  String get serviceName => 'PaymentService';
  static const _paymentApiUrl = 'http://10.0.2.2:4242/create-payment-intent'; // Update this with your server URL

  Future<Map<String, dynamic>> createPaymentIntent(int amount) async {
    final response = await http.post(
      Uri.parse(_paymentApiUrl),
      body: json.encode({'amount': amount}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create payment intent');
    }

    return json.decode(response.body);
  }

  Future<void> initPaymentSheet(String clientSecret) async {
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Dissonant',
        style: ThemeMode.light,
      ),
    );
  }

  Future<void> presentPaymentSheet() async {
      await Stripe.instance.presentPaymentSheet();
  }
}