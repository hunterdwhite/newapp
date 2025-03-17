import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/firestore_service.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import '../services/payment_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

// Add this import for XML parsing
import 'package:xml/xml.dart' as xml;

class OrderScreen extends StatefulWidget {
  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final PaymentService _paymentService = PaymentService();

  // Controllers
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipcodeController = TextEditingController();

  // State variables
  String _state = '';
  String? _selectedAddress;
  bool _hasOrdered = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  String _errorMessage = '';
  String _mostRecentOrderStatus = '';
  bool _hasFreeOrder = false;

  List<String> _previousAddresses = [];

  final List<String> _states = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE',
    'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS',
    'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS',
    'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY',
    'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV',
    'WI', 'WY'
  ];

  final FocusNode _zipcodeFocusNode = FocusNode();

  // Replace this with your actual USPS Web Tools USERID:
  final String _uspsUserId = '1933R3DISSO13';

  @override
  void initState() {
    super.initState();
    _fetchMostRecentOrderStatus();
    _loadPreviousAddresses();
    _loadUserData();
  }

  // Loads the freeOrder flag from the user document.
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await _firestoreService.getUserDoc(user.uid);
      if (userDoc != null && userDoc.exists) {
        final docData = userDoc.data() as Map<String, dynamic>?;
        if (docData != null) {
          setState(() {
            _hasFreeOrder = docData['freeOrder'] ?? false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipcodeFocusNode.dispose();
    _zipcodeController.dispose();
    super.dispose();
  }

  // Retrieves the most recent order status.
  Future<void> _fetchMostRecentOrderStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot orderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (orderSnapshot.docs.isNotEmpty) {
        DocumentSnapshot orderDoc = orderSnapshot.docs.first;
        String status = orderDoc['status'] ?? '';
        if (!mounted) return;
        setState(() {
          _mostRecentOrderStatus = status;
          _hasOrdered = !(status == 'kept' || status == 'returnedConfirmed');
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _hasOrdered = false;
          _isLoading = false;
        });
      }
    }
  }

  // Loads previous addresses from recent orders.
  Future<void> _loadPreviousAddresses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      Set<String> addressSet =
          ordersSnapshot.docs.map((doc) => doc['address'] as String).toSet();
      List<String> addresses = addressSet.take(3).toList();

      if (mounted) {
        setState(() {
          _previousAddresses = addresses;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BackgroundWidget(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _hasOrdered
                ? _buildPlaceOrderMessage(_mostRecentOrderStatus)
                : KeyboardActions(
                    config: _buildKeyboardActionsConfig(),
                    child: SafeArea(
                      child: Form(
                        key: _formKey,
                        child: _buildOrderForm(user),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildPlaceOrderMessage(String status) {
    String message;
    if (status == 'returned') {
      message =
          "Once we've confirmed your return you'll be able to order another album!";
    } else if (status == 'pending' || status == 'sent' || status == 'new') {
      message =
          "Thanks for placing an order! You will be able to place another once this one is completed.";
    } else {
      message = "You can now place a new order.";
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          message,
          style: TextStyle(fontSize: 24, color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildOrderForm(User? user) {
    final priceInfo = _hasFreeOrder ? "FREE" : "\$11.99";

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Screen title
          Text(
            'Order Your CD',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.0),

          // Price display row with disc icon and info button
          Container(
            margin: EdgeInsets.symmetric(vertical: 8.0),
            padding: EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                Icon(Icons.album, color: Colors.orangeAccent),
                SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    '$priceInfo',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.info_outline, color: Colors.white),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('New Process'),
                          content: Text(
                            "We've changed our process to make it easier for everyone as we grow.\n"
                            "Now you pay to make your initial order.\n"
                            "Keep/Return will remain the same except you don't pay anything to keep,\n"
                            "and returning makes your next order free!"
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // Free credit info
          if (_hasFreeOrder) ...[
            SizedBox(height: 8.0),
            Container(
              margin: EdgeInsets.only(bottom: 8.0),
              padding: EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'You have a free album credit available!',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Previous address dropdown
          SizedBox(height: 16.0),
          if (_previousAddresses.isNotEmpty) ...[
            Text(
              'Use a previous address:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4.0),
            DropdownButtonFormField<String>(
              value: _selectedAddress,
              items: _previousAddresses.map((address) {
                return DropdownMenuItem<String>(
                  value: address,
                  // Using white text on black background for each item
                  child: Text(address, style: TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedAddress = value;
                  if (value != null) _populateFieldsFromSelectedAddress(value);
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white10,
              ),
              dropdownColor: Colors.black87,
            ),
            SizedBox(height: 16.0),
            Text(
              'Or enter a new address:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          SizedBox(height: 16.0),

          // Text fields for order details
          _buildTextField(controller: _firstNameController, label: 'First Name'),
          SizedBox(height: 16.0),
          _buildTextField(controller: _lastNameController, label: 'Last Name'),
          SizedBox(height: 16.0),
          _buildTextField(controller: _addressController, label: 'Address (including apartment number)'),
          SizedBox(height: 16.0),
          _buildTextField(controller: _cityController, label: 'City'),
          SizedBox(height: 16.0),

          // State selector (white text on black background)
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white10,
            ),
            style: TextStyle(color: Colors.white), // Selected item text color
            dropdownColor: Colors.black87,         // Dropdown menu background color
            value: _state.isNotEmpty ? _state : null,
            items: _states.map((String state) {
              return DropdownMenuItem<String>(
                value: state,
                child: Text(
                  state,
                  style: TextStyle(color: Colors.white), // Item text color
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _state = newValue ?? '';
              });
            },
            validator: (value) =>
                value == null || value.isEmpty ? 'Please select your state' : null,
          ),
          SizedBox(height: 16.0),

          _buildTextField(
            controller: _zipcodeController,
            label: 'Zipcode',
            focusNode: _zipcodeFocusNode,
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 24.0),
          // Place Order button that triggers payment and order creation
          _isProcessing
              ? Center(child: CircularProgressIndicator())
              : RetroButton(
                  text: 'Place Order',
                  onPressed: user == null
                      ? null
                      : () async {
                          FocusScope.of(context).unfocus();
                          if (_formKey.currentState?.validate() ?? false) {
                            // If you want to *force* address verification here,
                            // you could call _verifyAddress() first and check for errors,
                            // then proceed only if successful.
                            await _handlePlaceOrder(user.uid);
                          }
                        },
                  color: Color(0xFFFFA500),
                ),
        ],
      ),
    );
  }

  // Helper for building text fields with consistent style.
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    FocusNode? focusNode,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white10,
      ),
      style: TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      validator: (value) => value == null || value.trim().isEmpty
          ? 'Please enter your $label'
          : null,
    );
  }

  // Fixed payment and order creation handler using the correct Firestore methods.
  Future<void> _handlePlaceOrder(String uid) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final fullAddress = _buildAddressString();

      // If order is free, use the free order credit directly
      if (_hasFreeOrder) {
        await _firestoreService.addOrder(
          uid,
          fullAddress,
          flowVersion: 2,
        );

        await _firestoreService.updateUserDoc(uid, {'freeOrder': false});

        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _hasOrdered = true;
          _mostRecentOrderStatus = 'new';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order placed successfully using your free credit!')),
        );
        return;
      }

      // Otherwise process payment before adding the order
      print('Creating PaymentIntent...');
      final response = await http.post(
        Uri.parse('https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-payment-intent'),
        body: jsonEncode({'amount': 1199}),
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
        await _firestoreService.addOrder(
          uid,
          fullAddress,
          flowVersion: 2,
        );

        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _hasOrdered = true;
          _mostRecentOrderStatus = 'new';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment successful. Your order has been placed!')),
        );
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

  // Builds a multiline address string from input fields.
  String _buildAddressString() {
    return '${_firstNameController.text} ${_lastNameController.text}\n'
        '${_addressController.text}\n'
        '${_cityController.text}, $_state ${_zipcodeController.text}';
  }

  // Keyboard actions config for the zipcode field.
  KeyboardActionsConfig _buildKeyboardActionsConfig() {
    return KeyboardActionsConfig(
      keyboardActionsPlatform: KeyboardActionsPlatform.ALL,
      actions: [
        KeyboardActionsItem(
          focusNode: _zipcodeFocusNode,
          toolbarButtons: [
            (node) {
              return GestureDetector(
                onTap: () => node.unfocus(),
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Done',
                    style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ],
        ),
      ],
    );
  }

  // Populates fields from a selected previous address.
  void _populateFieldsFromSelectedAddress(String address) {
    List<String> parts = address.split('\n');
    if (parts.length == 3) {
      List<String> nameParts = parts[0].split(' ');
      if (nameParts.isNotEmpty) {
        _firstNameController.text = nameParts.first;
        _lastNameController.text = nameParts.skip(1).join(' ');
      }
      _addressController.text = parts[1].trim();
      List<String> cityStateZip = parts[2].split(', ');
      if (cityStateZip.length == 2) {
        _cityController.text = cityStateZip[0].trim();
        List<String> stateZip = cityStateZip[1].split(' ');
        if (stateZip.length >= 2) {
          _state = stateZip[0].trim();
          _zipcodeController.text = stateZip.sublist(1).join(' ').trim();
        }
      }
    }
    setState(() {});
  }
}
