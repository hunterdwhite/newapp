import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../widgets/grainy_background_widget.dart';
import '../services/firestore_service.dart';
import '../services/payment_service.dart';
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckoutScreen extends StatefulWidget {
  final String productType;
  final double selectedPrice;
  final String priceLabel;
  final double shippingCost;
  final Map<String, String> shippingAddress;
  final String? curatorId;

  const CheckoutScreen({
    Key? key,
    required this.productType,
    required this.selectedPrice,
    required this.priceLabel,
    required this.shippingCost,
    required this.shippingAddress,
    this.curatorId,
  }) : super(key: key);

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final PaymentService _paymentService = PaymentService();

  String _selectedPaymentMethod = 'stripe';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GrainyBackgroundWidget(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOrderSummary(),
                      SizedBox(height: 24),
                      _buildShippingInfo(),
                      SizedBox(height: 24),
                      _buildPaymentMethods(),
                      SizedBox(height: 24),
                      _buildTotalSection(),
                      SizedBox(height: 24),
                      _buildPlaceOrderButton(),
                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Checkout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final productTitle = widget.productType == 'dissonant'
        ? 'Dissonant Curated Experience'
        : 'Community Curated Experience';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    widget.productType == 'dissonant'
                        ? 'assets/dissonantordericon.png'
                        : 'assets/curateicon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${widget.priceLabel} Option',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '\$${widget.selectedPrice.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShippingInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shipping Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '${widget.shippingAddress['firstName']} ${widget.shippingAddress['lastName']}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            widget.shippingAddress['address']!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '${widget.shippingAddress['city']}, ${widget.shippingAddress['state']} ${widget.shippingAddress['zipCode']}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),

          // Credit/Debit Card (Stripe)
          _buildPaymentOption(
            id: 'stripe',
            title: 'Credit or Debit Card',
            subtitle: 'Visa, Mastercard, American Express',
            icon: Icons.credit_card,
            isSelected: _selectedPaymentMethod == 'stripe',
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = id;
        });
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orangeAccent.withOpacity(0.1)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.orangeAccent
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.orangeAccent : Colors.white54,
                  width: 2,
                ),
                color: isSelected ? Colors.orangeAccent : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
            SizedBox(width: 16),
            Icon(
              icon,
              color: Colors.white70,
              size: 24,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSection() {
    final subtotal = widget.selectedPrice;
    final shipping = widget.shippingCost;
    final total = subtotal + shipping;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Total',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          _buildTotalRow('Subtotal:', '\$${subtotal.toStringAsFixed(2)}'),
          SizedBox(height: 8),
          _buildTotalRow('Shipping:', '\$${shipping.toStringAsFixed(2)}'),
          Divider(color: Colors.white30, height: 24),
          _buildTotalRow('Total:', '\$${total.toStringAsFixed(2)}',
              isTotal: true),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: Colors.white70,
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton() {
    final total = widget.selectedPrice + widget.shippingCost;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _placeOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isProcessing ? Colors.grey : Colors.orangeAccent,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: _isProcessing ? 0 : 4,
        ),
        child: _isProcessing
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Processing...'),
                ],
              )
            : Text(
                'Place Order - \$${total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _placeOrder() async {
    // Prevent duplicate submissions
    if (_isProcessing) {
      print('⚠️ Order already being processed, ignoring duplicate submission');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check for recent duplicate orders (within last 30 seconds)
      final recentOrders = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (recentOrders.docs.isNotEmpty) {
        final lastOrderTime =
            recentOrders.docs.first.data()['timestamp'] as Timestamp?;
        if (lastOrderTime != null) {
          final timeSinceLastOrder =
              DateTime.now().difference(lastOrderTime.toDate());
          if (timeSinceLastOrder.inSeconds < 30) {
            print(
                '⚠️ Duplicate order detected (last order was ${timeSinceLastOrder.inSeconds} seconds ago)');
            setState(() {
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'You recently placed an order. Please wait a moment before placing another.'),
                backgroundColor: Colors.orange,
              ),
            );
            return;
          }
        }
      }

      final total = widget.selectedPrice + widget.shippingCost;
      final amountInCents = (total * 100).round();

      switch (_selectedPaymentMethod) {
        case 'stripe':
          await _processStripePayment(amountInCents, user.uid);
          break;
        default:
          throw Exception('Invalid payment method');
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processStripePayment(int amountInCents, String userId) async {
    try {
      // Generate idempotency key to prevent duplicate charges
      final idempotencyKey =
          'order_${userId}_${DateTime.now().millisecondsSinceEpoch}';

      // Create payment intent
      final response = await http.post(
        Uri.parse(
            'https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-payment-intent'),
        body: jsonEncode({
          'amount': amountInCents,
          'idempotencyKey': idempotencyKey,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final paymentIntentData = jsonDecode(response.body);

        // Initialize and present payment sheet
        await _paymentService
            .initPaymentSheet(paymentIntentData['clientSecret']);
        await _paymentService.presentPaymentSheet();

        // Payment successful, create order
        await _createOrder(userId);
      } else {
        throw Exception('Failed to create payment intent');
      }
    } on StripeException catch (e) {
      throw Exception(e.error.localizedMessage);
    }
  }

  Future<void> _createOrder(String userId) async {
    // Build full address string
    final fullAddress = _buildAddressString();

    // Create order first - Cloud Function will handle shipping labels automatically
    final orderId = await _firestoreService.addOrder(
      userId,
      fullAddress,
      flowVersion: 3, // New checkout flow version
      curatorId: widget.curatorId,
    );

    // REMOVED client-side label creation backup to prevent duplicate charges
    // Cloud Function handles this reliably
    print('✅ Order created: $orderId - Cloud Function will create shipping labels');

    // Award credits for paid orders
    await HomeScreen.addFreeOrderCredits(userId, 1);

    setState(() {
      _isProcessing = false;
    });

    // Show success message and navigate
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order placed successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    // Navigate back to home
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _buildAddressString() {
    return '${widget.shippingAddress['firstName']} ${widget.shippingAddress['lastName']}\n'
        '${widget.shippingAddress['address']}\n'
        '${widget.shippingAddress['city']}, ${widget.shippingAddress['state']} ${widget.shippingAddress['zipCode']}';
  }

}
