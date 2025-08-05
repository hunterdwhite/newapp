import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'base_service.dart';

enum PaymentMethod { stripe, paypal }

class PaymentService extends BaseService {
  @override
  String get serviceName => 'PaymentService';
  static const _paymentApiUrl = 'http://10.0.2.2:4242/create-payment-intent'; // Update this with your server URL
  static const _paypalApiUrl = 'http://10.0.2.2:4242/create-paypal-payment'; // PayPal payment endpoint

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

  Future<Map<String, dynamic>> createPayPalPayment(double amount) async {
    final response = await http.post(
      Uri.parse(_paypalApiUrl),
      body: json.encode({'amount': amount.toStringAsFixed(2)}),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to create PayPal payment');
    }

    return json.decode(response.body);
  }

  Future<String?> processPayPalPayment({
    required BuildContext context,
    required double amount,
    required String description,
  }) async {
    try {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (BuildContext context) => PaypalCheckoutView(
            sandboxMode: true, // Set to false for production
            clientId: "AQkquBDf1zctJOWGKWUEtKXm6qVhueUEMvXO_8VaNvoGapdevCU7LHSYTjjkKG64Q6GBm8gLOF0X7Spo", // Demo client ID - replace with yours
            secretKey: "EBWJjgLzD5A3LwN5mE_7JCPBk5t7IJiKnOzH5jmzgSp-YJv32YBWJJJKGzPh16IqtETKHV9XJFJ7mD8J", // Demo secret - replace with yours
            transactions: [
              {
                "amount": {
                  "total": amount.toStringAsFixed(2),
                  "currency": "USD",
                  "details": {
                    "subtotal": amount.toStringAsFixed(2),
                    "tax": '0',
                    "shipping": '0',
                    "handling_fee": '0',
                    "shipping_discount": '0',
                    "insurance": '0'
                  }
                },
                "description": description,
                "item_list": {
                  "items": [
                    {
                      "name": "Album Purchase",
                      "quantity": 1,
                      "price": amount.toStringAsFixed(2),
                      "currency": "USD"
                    }
                  ],
                }
              }
            ],
            note: "Contact us for any questions on your order.",
            onSuccess: (Map params) async {
              print("PayPal payment successful: $params");
              return params;
            },
            onError: (error) {
              print("PayPal payment error: $error");
              throw Exception('PayPal payment failed: $error');
            },
            onCancel: () {
              print('PayPal payment cancelled');
              return null;
            },
          ),
        ),
      );
      
      if (result != null && result['paymentId'] != null) {
        return result['paymentId'];
      }
      return null;
    } catch (e) {
      print('PayPal payment error: $e');
      rethrow;
    }
  }
}