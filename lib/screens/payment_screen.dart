import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../widgets/app_bar_widget.dart';
import '../widgets/grainy_background_widget.dart';
import '/services/firestore_service.dart';
import '/services/payment_service.dart';
import '../widgets/retro_button_widget.dart';

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
  final ScrollController _scrollController = ScrollController();
  final FocusNode _reviewFocusNode = FocusNode();

  bool _isProcessing = false;
  bool _isLoading = true;
  String? _errorMessage;
  String _albumCoverUrl = '';
  String _albumInfo = '';
  String? _albumId;
  String? _curatorId;
  String _review = '';
  String _curatorReview = '';
  double _curatorRating = 0.0;
  // New: track the order's flowVersion (default to 1)
  int _flowVersion = 1;

  @override
  void initState() {
    super.initState();
    _fetchAlbumDetails();
    _reviewFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _reviewFocusNode.removeListener(_onFocusChange);
    _reviewFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_reviewFocusNode.hasFocus) {
      // Scroll to the review text field when it gains focus
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _fetchAlbumDetails() async {
    try {
      final orderDoc = await _firestoreService.getOrderById(widget.orderId);
      if (orderDoc?.exists == true) {
        final orderData = orderDoc!.data() as Map<String, dynamic>;
        // Read flowVersion; if not present, default to 1 (old flow)
        _flowVersion = orderData['flowVersion'] ?? 1;
        // Get albumId and curatorId - try both new and old data structures
        final albumId = orderData['albumId'] ?? orderData['details']?['albumId'];
        _albumId = albumId;
        _curatorId = orderData['curatorId'];
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

  Future<void> _submitCuratorReview(String comment, double rating) async {
    if (_curatorId == null) return;
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestoreService.addCuratorReview(
      curatorId: _curatorId!,
      userId: user.uid,
      orderId: widget.orderId,
      comment: comment,
      rating: rating,
    );
  }

  // Helper method to dismiss keyboard
  void _dismissKeyboard() {
    _reviewFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  // Handle return key press - add new line instead of dismissing keyboard
  void _handleReturnKey(String value) {
    // Allow multi-line input by not dismissing keyboard
    // The return key will naturally add a new line
  }

  /// For orders with flowVersion >= 2, simply mark as kept without charging.
  Future<void> _keepAlbum() async {
    // Dismiss keyboard before processing
    _dismissKeyboard();
    setState(() {
      _isProcessing = true;
    });
    try {
      await _firestoreService.updateOrderStatus(widget.orderId, 'kept');
      if (_review.trim().isNotEmpty && _albumId != null) {
        await _submitReview(_review.trim());
      }
      if (_curatorRating > 0 && _curatorId != null) {
        await _submitCuratorReview(_curatorReview.trim(), _curatorRating);
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
    // Dismiss keyboard before processing
    _dismissKeyboard();
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
        if (_curatorRating > 0 && _curatorId != null) {
          await _submitCuratorReview(_curatorReview.trim(), _curatorRating);
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
    // For old flow (flowVersion == 1), the UI shows price and payment step.
    // For new flow (flowVersion >= 2), we remove price and payment, and only show the "Keep Album" option.
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: CustomAppBarWidget(title: 'Keep Your Album'),
      body: SafeArea(
        child: GrainyBackgroundWidget(
        child: _isProcessing || _isLoading
            ? Center(child: CircularProgressIndicator())
            : GestureDetector(
                // Add tap-to-dismiss keyboard functionality
                onTap: _dismissKeyboard,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: ClampingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 20.0,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 300.0,
                      left: 16.0,
                      right: 16.0,
                    ),
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
                        // Dissonant styled review section
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F4),
                            border: Border.all(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title bar
                              Container(
                                width: double.infinity,
                                height: 30,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFA12C),
                                  border: Border(
                                    bottom: BorderSide(color: Colors.black, width: 2),
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                                child: const Text(
                                  'Album Review',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Content area
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Colors.black54, width: 1),
                                  ),
                                  child: TextField(
                                    focusNode: _reviewFocusNode,
                                    decoration: const InputDecoration(
                                      hintText: 'Write your review here...',
                                      hintStyle: TextStyle(color: Colors.grey),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.all(8),
                                    ),
                                    style: const TextStyle(
                                      color: Colors.black, 
                                      fontSize: 14,
                                      fontFamily: 'MS Sans Serif',
                                    ),
                                    maxLines: 4,
                                    minLines: 3,
                                    textInputAction: TextInputAction.newline,
                                    onSubmitted: _handleReturnKey,
                                    onChanged: (value) {
                                      _review = value;
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.0),
                        // Dissonant styled curator rating section
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F4F4),
                            border: Border.all(color: Colors.black, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title bar
                              Container(
                                width: double.infinity,
                                height: 30,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFA12C),
                                  border: Border(
                                    bottom: BorderSide(color: Colors.black, width: 2),
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                                child: const Text(
                                  'Rate Your Curator',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              // Content area
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(3, (index) {
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _curatorRating = index + 1.0;
                                            });
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            child: Icon(
                                              index < _curatorRating ? Icons.star : Icons.star_border,
                                              color: const Color(0xFFFFA12C),
                                              size: 28,
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: Colors.black54, width: 1),
                                      ),
                                      child: TextField(
                                        decoration: const InputDecoration(
                                          hintText: 'Leave feedback for your curator...',
                                          hintStyle: TextStyle(color: Colors.grey),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.all(8),
                                        ),
                                        style: const TextStyle(
                                          color: Colors.black, 
                                          fontSize: 14,
                                          fontFamily: 'MS Sans Serif',
                                        ),
                                        maxLines: 3,
                                        minLines: 2,
                                        textInputAction: TextInputAction.newline,
                                        onChanged: (value) {
                                          _curatorReview = value;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20.0),
                        // Conditional UI:
                        _flowVersion >= 2
                            ? RetroButtonWidget(
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
                                  RetroButtonWidget(
                                    text: 'Purchase',
                                    onPressed: _processPayment,
                                    style: RetroButtonStyle.light,
                                    fixedHeight: true,
                                  ),
                                ],
                              ),
                      ],]
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}
