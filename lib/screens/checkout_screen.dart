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
          _buildTotalRow('Total:', '\$${total.toStringAsFixed(2)}', isTotal: true),
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
    setState(() {
      _isProcessing = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
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
      // Create payment intent
      final response = await http.post(
        Uri.parse('https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-payment-intent'),
        body: jsonEncode({'amount': amountInCents}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final paymentIntentData = jsonDecode(response.body);
        
        // Initialize and present payment sheet
        await _paymentService.initPaymentSheet(paymentIntentData['clientSecret']);
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
    
    // Wait a moment to let Cloud Function start, then attempt client-side (non-blocking backup)
    Future.delayed(const Duration(milliseconds: 500), () {
      _createShippingLabels(userId, fullAddress, orderId: orderId).catchError((error) {
        print('⚠️ Client-side label creation failed (Cloud Function will handle): $error');
      });
    });
    
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

  Future<void> _createShippingLabels(String userId, String fullAddress, {String? orderId}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return;

      // Parse address for shipping labels
      final addressLines = fullAddress.split('\n');
      if (addressLines.length < 3) return;

      final customerName = addressLines[0].trim();
      final streetAddress = addressLines[1].trim();
      final cityStateZip = addressLines[2].split(', ');
      
      if (cityStateZip.length < 2) return;

      final city = cityStateZip[0].trim();
      final stateZip = cityStateZip[1].split(' ');
      
      if (stateZip.length < 2) return;

      final state = stateZip[0].trim();
      final zip = stateZip.sublist(1).join(' ').trim();

      final customerAddress = {
        'name': customerName,
        'street1': streetAddress,
        'city': city,
        'state': state,
        'zip': zip,
        'country': 'US',
      };

      final parcel = {
        'length': '8',
        'width': '6',
        'height': '0.5',
        'distance_unit': 'in',
        'weight': '4.9',
        'mass_unit': 'oz',
      };

      // Use provided orderId (Firestore order ID) or generate timestamp-based one
      final labelOrderId = orderId != null ? 'ORDER-$orderId' : 'ORDER-${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.post(
        Uri.parse('https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-shipping-labels'),
        body: jsonEncode({
          'to_address': customerAddress,
          'parcel': parcel,
          'order_id': labelOrderId,
          'customer_name': customerName,
          'customer_email': user!.email,
        }),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Shipping label creation timed out after 10 seconds');
        },
      );

      if (response.statusCode == 200) {
        final labelData = jsonDecode(response.body);
        print('✅ Shipping labels created successfully');
        
        // Update order document to mark labels as created (prevents Cloud Function from trying)
        if (orderId != null) {
          try {
            await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
              'shippingLabels': {
                'created': true,
                'status': 'success',
                'orderId': labelOrderId,
                'outboundLabel': labelData['outbound_label'],
                'returnLabel': labelData['return_label'],
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
                'createdBy': 'client',
              },
            });
            print('✅ Order document updated with shipping label data');
          } catch (updateError) {
            print('⚠️ Failed to update order document (Cloud Function will handle): $updateError');
          }
        }
      } else {
        print('Failed to create shipping labels: ${response.body}');
      }
    } catch (e) {
      print('Error creating shipping labels: $e');
      // Don't fail the order if label creation fails
    }
  }
}
