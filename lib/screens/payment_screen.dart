import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../widgets/app_bar_widget.dart';
import '../widgets/grainy_background_widget.dart';
import '/services/firestore_service.dart';
import '/services/payment_service.dart';
import '../widgets/retro_button_widget.dart';
import '../widgets/windows95_window.dart';

class PaymentScreen extends StatefulWidget {
  final String orderId;

  PaymentScreen({required this.orderId});

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final PaymentService _paymentService = PaymentService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isProcessing = false;
  bool _isLoading = true;
  String? _errorMessage;
  String _albumCoverUrl = '';
  String _albumInfo = '';
  String? _albumId;
  String _review = '';
  // New: track the order's flowVersion (default to 1)
  int _flowVersion = 1;

  @override
  void initState() {
    super.initState();
    _fetchAlbumDetails();
  }

  Future<void> _fetchAlbumDetails() async {
    try {
      final orderDoc = await _firestoreService.getOrderById(widget.orderId);
      if (orderDoc?.exists == true) {
        final orderData = orderDoc!.data() as Map<String, dynamic>;
        // Read flowVersion; if not present, default to 1 (old flow)
        _flowVersion = orderData['flowVersion'] ?? 1;
        // Get albumId from order details (assumes your order doc has a 'details' map)
        final albumId = orderData['details']['albumId'];
        _albumId = albumId;
        final albumDoc = await _firestoreService.getAlbumById(albumId);
        if (albumDoc.exists) {
          final album = albumDoc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _albumCoverUrl = album['coverUrl'] ?? '';
              _albumInfo = '${album['artist']} - ${album['albumName']}';
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = 'Album not found';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Order not found';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load album details: $e';
        });
      }
    }
  }

  Future<void> _submitReview(String comment) async {
    if (_albumId == null) return;
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestoreService.addReview(
      albumId: _albumId!,
      userId: user.uid,
      orderId: widget.orderId,
      comment: comment,
    );
  }

  /// For orders with flowVersion == 2, simply mark as kept without charging.
  Future<void> _keepAlbum() async {
    setState(() {
      _isProcessing = true;
    });
    try {
      await _firestoreService.updateOrderStatus(widget.orderId, 'kept');
      if (_review.trim().isNotEmpty && _albumId != null) {
        await _submitReview(_review.trim());
      }
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Album kept successfully. Enjoy your album!')),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e, stackTrace) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      try {
        FirebaseCrashlytics.instance.recordError(e, stackTrace);
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to keep album: $e')),
      );
    }
  }

  /// For orders using the old flow, process payment.
  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      print('Creating PaymentIntent...');
      final response = await http.post(
        Uri.parse('https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-payment-intent'),
        body: jsonEncode({'amount': 899}), // price in cents for old flow
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final paymentIntentData = jsonDecode(response.body);
        if (!paymentIntentData.containsKey('clientSecret')) {
          throw Exception('Invalid PaymentIntent response: ${response.body}');
        }
        print('Initializing payment sheet...');
        await _paymentService.initPaymentSheet(paymentIntentData['clientSecret']);
        print('Presenting payment sheet...');
        await _paymentService.presentPaymentSheet();

        print('Payment completed successfully.');
        await _firestoreService.updateOrderStatus(widget.orderId, 'kept');
        if (_review.trim().isNotEmpty && _albumId != null) {
          await _submitReview(_review.trim());
        }
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment successful. Enjoy your new album!')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        throw Exception('Failed to create PaymentIntent. Server error: ${response.body}');
      }
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
      });
      print('Stripe error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${e.error.localizedMessage}')),
      );
    } catch (e, stackTrace) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
      print('Payment error: $e');
      try {
        FirebaseCrashlytics.instance.recordError(e, stackTrace);
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // For old flow (flowVersion != 2), the UI shows price and payment step.
    // For new flow (flowVersion == 2), we remove price and payment, and only show the "Keep Album" option.
    return Scaffold(
      appBar: CustomAppBar(title: 'Keep Your Album'),
      body: BackgroundWidget(
        child: _isProcessing || _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(top: 80.0, bottom: 30.0, left: 16.0, right: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        // Display album cover and info
                        if (_albumCoverUrl.isNotEmpty)
                          Image.network(
                            _albumCoverUrl,
                            height: 250,
                            width: 250,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.white),
                                ),
                              );
                            },
                          ),
                        if (_albumInfo.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Text(
                              _albumInfo,
                              style: TextStyle(fontSize: 24, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(height: 20.0),
                          Text(
                          'We\'re glad you enjoyed the album!',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 10.0),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Write your review here...',
                                filled: true,
                                fillColor: Colors.black,
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black, width: 2),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.black, width: 2),
                                ),
                              ),
                              style: TextStyle(color: Colors.black),
                              maxLines: 3,
                              onChanged: (value) {
                                _review = value;
                              },
                            ),
                          ),
                        SizedBox(height: 20.0),
                        // Conditional UI:
                        _flowVersion == 2
                            ? RetroButton(
                                text: 'Keep Album',
                                onPressed: _keepAlbum,
                                style: RetroButtonStyle.light,
                                fixedHeight: true,
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '\$8.99',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 24,
                                    ),
                                  ),
                                  SizedBox(width: 20.0),
                                  RetroButton(
                                    text: 'Purchase',
                                    onPressed: _processPayment,
                                    style: RetroButtonStyle.light,
                                    fixedHeight: true,
                                  ),
                                ],
                              ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
