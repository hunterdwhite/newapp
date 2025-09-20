import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/firestore_service.dart';
import '../services/shippo_address_service.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';
// import '../widgets/app_bar_widget.dart';
import 'package:keyboard_actions/keyboard_actions.dart';
import '../services/payment_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'home_screen.dart';
// import 'how_it_works_screen.dart';
import '../constants/responsive_utils.dart';

class OrderScreen extends StatefulWidget {
  final String? selectedCuratorId;
  
  const OrderScreen({Key? key, this.selectedCuratorId}) : super(key: key);
  
  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final PaymentService _paymentService = PaymentService();
  
  // Shippo Address Validation Service
  late final ShippoAddressService _addressService;
  bool _isAddressValidated = false;
  bool _isValidating = false;
  String? _addressValidationError;

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
  // String _errorMessage = '';
  String _mostRecentOrderStatus = '';
  bool _hasFreeOrder = false;

  // Payment option state:
  // Default payment amount is 11.99, but the user hasn't selected one until they tap.
  double _selectedPaymentAmount = 11.99;
  bool _hasSelectedPrice = false;
  
  // Payment method selection
  // String _selectedPaymentMethod = 'stripe'; // 'stripe' or 'paypal'

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

  @override
  void initState() {
    super.initState();
    
    // Initialize Shippo address validation service
    _addressService = ShippoAddressService(
      endpointBase: 'https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev',
    );
    
    _fetchMostRecentOrderStatus();
    _loadPreviousAddresses();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await _firestoreService.getUserDoc(user.uid);
      if (userDoc != null && userDoc.exists) {
        final docData = userDoc.data() as Map<String, dynamic>?;
        if (docData != null) {
          if (!mounted) return;
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
      body: GrainyBackgroundWidget(
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
      // Fallback for any unexpected status - should match the logic in _fetchMostRecentOrderStatus
      print('WARNING: Unexpected order status "$status" in message display');
      message = "Thanks for placing an order! You will be able to place another once this one is completed.";
    }
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            message,
            style: TextStyle(fontSize: 24, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: const Text(
            '<',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            widget.selectedCuratorId != null ? 'Order from Curator' : 'Order Your CD',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 24, tablet: 28, desktop: 32),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderForm(User? user) {
    final priceInfo = _hasFreeOrder
        ? "FREE"
        : (_hasSelectedPrice
            ? "\$${_selectedPaymentAmount.toStringAsFixed(2)}"
            : "Choose your price");

    return SingleChildScrollView(
      padding: ResponsiveUtils.getResponsiveHorizontalPadding(context,
          mobile: 16, tablet: 24, desktop: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ResponsiveUtils.getContainerMaxWidth(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
            _buildHeader(),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
            Container(
              margin: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 6, tablet: 8, desktop: 10)
              ),
              padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(Icons.album, 
                      color: Colors.orangeAccent,
                      size: ResponsiveUtils.isMobile(context) ? 20 : 24),
                  SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, mobile: 6, tablet: 8, desktop: 8)),
                  Expanded(
                    child: InkWell(
                      onTap: !_hasFreeOrder ? _showPaymentOptionsDialog : null,
                      child: Text(
                        '$priceInfo',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16, tablet: 18, desktop: 20), 
                          color: Colors.white
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_hasFreeOrder) ...[
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 6, tablet: 8, desktop: 10)),
              Container(
                margin: EdgeInsets.only(
                  bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 6, tablet: 8, desktop: 10)
                ),
                padding: EdgeInsets.all(ResponsiveUtils.getResponsiveSpacing(context, mobile: 10, tablet: 12, desktop: 14)),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, 
                        color: Colors.white,
                        size: ResponsiveUtils.isMobile(context) ? 20 : 24),
                    SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, mobile: 6, tablet: 8, desktop: 8)),
                    Expanded(
                      child: Text(
                        'You have a free album credit available!',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 18), 
                          color: Colors.white
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
            // if (!_hasFreeOrder) ...[
            //   _buildPaymentMethodSelection(),
            //   SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
            // ],
            if (_previousAddresses.isNotEmpty) ...[
              Text(
                'Use a previous address:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 18),
                ),
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 3, tablet: 4, desktop: 6)),
              DropdownButtonFormField<String>(
                value: _selectedAddress,
                items: _previousAddresses.map((address) {
                  return DropdownMenuItem<String>(
                    value: address,
                    child: Text(address, style: TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAddress = value;
                    if (value != null) {
                      _populateFieldsFromSelectedAddress(value);
                      // Auto-validate the selected address
                      Future.delayed(Duration(milliseconds: 100), () {
                        _validateAddress();
                      });
                    }
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.white10,
                ),
                dropdownColor: Colors.black87,
              ),
              SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
              Text(
                'Or enter a new address:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 18),
                ),
              ),
            ],
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
            _buildTextField(controller: _firstNameController, label: 'First Name'),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
            _buildTextField(controller: _lastNameController, label: 'Last Name'),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
            _buildTextField(
              controller: _addressController, 
              label: 'Address (including apartment number)',
              isAddressField: true,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
            _buildTextField(
              controller: _cityController, 
              label: 'City',
              isAddressField: true,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
            _buildStateDropdown(),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
            _buildTextField(
              controller: _zipcodeController,
              label: 'Zipcode',
              focusNode: _zipcodeFocusNode,
              keyboardType: TextInputType.number,
              isAddressField: true,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24, tablet: 32, desktop: 40)),
            _isProcessing
                ? Center(child: CircularProgressIndicator())
                : RetroButtonWidget(
                    text: _isValidating ? 'Validating Address...' : 'Place Order',
                    onPressed: user == null || _isValidating
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                            if (_formKey.currentState?.validate() ?? false) {
                              // Auto-validate address if not already validated
                              if (!_isAddressValidated) {
                                await _validateAddress();
                                // If validation failed, don't proceed
                                if (!_isAddressValidated) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_addressValidationError ?? 'Address validation failed. Please check your address.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }
                              }


                              await _handlePlaceOrder(user.uid);
                            }
                          },
                    style: RetroButtonStyle.light,
                  ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    FocusNode? focusNode,
    TextInputType? keyboardType,
    bool isAddressField = false,
  }) {
    Color? borderColor;
    Widget? suffixIcon;
    
    if (isAddressField) {
      if (_isValidating) {
        borderColor = Colors.orange;
        suffixIcon = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        );
      } else if (_isAddressValidated) {
        borderColor = Colors.green;
        suffixIcon = Icon(Icons.check_circle, color: Colors.green);
      } else if (_addressValidationError != null) {
        borderColor = Colors.red;
        suffixIcon = Icon(Icons.error, color: Colors.red);
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: isAddressField ? (_) => _onAddressFieldChanged() : null,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderSide: BorderSide(color: borderColor ?? Colors.grey),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: borderColor ?? Colors.grey),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: borderColor ?? Colors.blue, width: 2),
            ),
            filled: true,
            fillColor: Colors.white10,
            suffixIcon: suffixIcon,
            labelStyle: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 16),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12, tablet: 16, desktop: 16),
              vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12, tablet: 16, desktop: 16),
            ),
          ),
          style: TextStyle(
            color: Colors.white,
            fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 16),
          ),
          keyboardType: keyboardType,
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Please enter your $label'
              : null,
        ),
        if (isAddressField && _addressValidationError != null) ...[
          SizedBox(height: 4),
          Text(
            _addressValidationError!,
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  // Updated payment options dialog with refined styling.
 void _showPaymentOptionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title bar
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(0xFFFFA12C),
                    border: Border(
                      bottom: BorderSide(color: Colors.black, width: 1),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            'Select Payment Option',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 6,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Color(0xFFCBCACB),
                              border: Border.all(color: Colors.black, width: 1),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'X',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Color(0xFFE0E0E0),
                  padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _windows97OptionButton(
                        label: "\$8.99",
                        description: "I can't afford a full price album right now",
                        onTap: () {
                          setState(() {
                            _selectedPaymentAmount = 8.99;
                            _hasSelectedPrice = true;
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                      SizedBox(height: 12),
                      _windows97OptionButton(
                        label: "\$11.99",
                        description: "I'll buy at full price!",
                        onTap: () {
                          setState(() {
                            _selectedPaymentAmount = 11.99;
                            _hasSelectedPrice = true;
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                      SizedBox(height: 12),
                      _windows97OptionButton(
                        label: "\$14.99",
                        description: "I want to pay full price and help contribute so others don't have to pay full price!",
                        onTap: () {
                          setState(() {
                            _selectedPaymentAmount = 14.99;
                            _hasSelectedPrice = true;
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                      SizedBox(height: 18),
                      Text(
                        'All prices are for the same service',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _windows97OptionButton({
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              offset: Offset(2, 2),
              blurRadius: 1,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 16,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                description,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _handlePlaceOrder(String uid) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final fullAddress = _buildAddressString();

      if (_hasFreeOrder) {
        // Create shipping labels for free orders (same as paid orders)
        print('🔄 About to create shipping labels for free order...');
        await _createShippingLabels(uid, fullAddress);
        print('✅ Shipping labels creation completed for free order');
        
        await _firestoreService.addOrder(uid, fullAddress, flowVersion: 2, curatorId: widget.selectedCuratorId);
        await HomeScreen.useFreeOrder(uid); // Properly decrement free order count
        
        // No credit awarded for free orders - credits are only earned when paying with money

        // Refresh local state to reflect the used free order
        await _loadUserData();

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

      int amountInCents = (_selectedPaymentAmount * 100).round();
      
      // if (_selectedPaymentMethod == 'paypal') {
      //   await _handlePayPalPayment(amountInCents, uid, fullAddress);
      //   return;
      // }
      
      print('Creating PaymentIntent for $amountInCents cents...');
      final response = await http.post(
        Uri.parse('https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-payment-intent'),
        body: jsonEncode({'amount': amountInCents}),
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
        
        // Create shipping labels
        print('🔄 About to create shipping labels...');
        await _createShippingLabels(uid, fullAddress);
        print('✅ Shipping labels creation completed');
        
        await _firestoreService.addOrder(uid, fullAddress, flowVersion: 2, curatorId: widget.selectedCuratorId);
        
        // Award 1 credit for placing an order
        await HomeScreen.addFreeOrderCredits(uid, 1);

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

  String _buildAddressString() {
    return '${_firstNameController.text} ${_lastNameController.text}\n'
        '${_addressController.text}\n'
        '${_cityController.text}, $_state ${_zipcodeController.text}';
  }

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
    
    // Reset validation state when address is populated from dropdown
    _isAddressValidated = false;
    _addressValidationError = null;
    
    setState(() {});
  }

  /// Validates the current address using USPS API
  Future<void> _validateAddress() async {
    // Check if all required fields are filled
    final street = _addressController.text.trim();
    final city = _cityController.text.trim();
    final state = _state.trim();
    final zip = _zipcodeController.text.trim();
    
    if (street.isEmpty || city.isEmpty || state.isEmpty || zip.isEmpty) {
      return; // Don't validate incomplete addresses
    }
    
    if (!mounted) return;
    setState(() {
      _isValidating = true;
      _addressValidationError = null;
    });

    try {
       final validatedAddress = await _addressService.validate(
        street: street,
        city: city,
        state: state,
        zip: zip,
        name: (_firstNameController.text.trim() + ' ' + _lastNameController.text.trim()).trim(),
      );

      if (!mounted) return;
      setState(() {
        _isValidating = false;
        if (validatedAddress != null) {
          _isAddressValidated = true;
          _addressValidationError = null;
          
          // Update form fields with validated address
          _addressController.text = validatedAddress.street;
          _cityController.text = validatedAddress.city;
          _state = validatedAddress.state;
          _zipcodeController.text = validatedAddress.zip4 != null 
              ? '${validatedAddress.zip5}-${validatedAddress.zip4}'
              : validatedAddress.zip5;
        } else {
          _isAddressValidated = false;
           _addressValidationError = 'This address could not be validated. Please check your address and try again.';
        }
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _isAddressValidated = false;
        _addressValidationError = 'Unable to validate address at this time. Please try again later.';
      });
      print('Address validation error: $e');
    }
  }

  /// Called when any address field changes to reset validation
  void _onAddressFieldChanged() {
    if (_isAddressValidated) {
      setState(() {
        _isAddressValidated = false;
        _addressValidationError = null;
      });
    }
  }


  Widget _buildStateDropdown() {
    Color? borderColor;
    if (_isValidating) {
      borderColor = Colors.orange;
    } else if (_isAddressValidated) {
      borderColor = Colors.green;
    } else if (_addressValidationError != null) {
      borderColor = Colors.red;
    }
    
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'State',
        border: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor ?? Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor ?? Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: borderColor ?? Colors.blue, width: 2),
        ),
        filled: true,
        fillColor: Colors.white10,
      ),
      style: TextStyle(color: Colors.white),
      dropdownColor: Colors.black87,
      value: _state.isNotEmpty ? _state : null,
      items: _states.map((String state) {
        return DropdownMenuItem<String>(
          value: state,
          child: Text(
            state,
            style: TextStyle(color: Colors.white),
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _state = newValue ?? '';
        });
        _onAddressFieldChanged();
      },
      validator: (value) =>
          value == null || value.isEmpty ? 'Please select your state' : null,
    );
  }

  // Widget _buildPaymentMethodSelection() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Text(
  //         'Payment Method',
  //         style: TextStyle(
  //           color: Colors.white,
  //           fontWeight: FontWeight.bold,
  //           fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16, tablet: 18, desktop: 20),
  //         ),
  //       ),
  //       SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
  //       Row(
  //         children: [
  //           Expanded(
  //             child: GestureDetector(
  //               onTap: () => setState(() => _selectedPaymentMethod = 'stripe'),
  //               child: Container(
  //                 padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  //                 decoration: BoxDecoration(
  //                   color: _selectedPaymentMethod == 'stripe' ? Colors.blue : Colors.white10,
  //                   borderRadius: BorderRadius.circular(8),
  //                   border: Border.all(
  //                     color: _selectedPaymentMethod == 'stripe' ? Colors.blue : Colors.grey,
  //                     width: 2,
  //                   ),
  //                 ),
  //                 child: Row(
  //                   mainAxisAlignment: MainAxisAlignment.center,
  //                   children: [
  //                     Icon(
  //                       Icons.credit_card,
  //                       color: _selectedPaymentMethod == 'stripe' ? Colors.white : Colors.grey,
  //                     ),
  //                     SizedBox(width: 8),
  //                     Text(
  //                       'Card',
  //                       style: TextStyle(
  //                         color: _selectedPaymentMethod == 'stripe' ? Colors.white : Colors.grey,
  //                         fontWeight: FontWeight.w600,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           ),
  //           SizedBox(width: 12),
  //           Expanded(
  //             child: GestureDetector(
  //               onTap: () => setState(() => _selectedPaymentMethod = 'paypal'),
  //               child: Container(
  //                 padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  //                 decoration: BoxDecoration(
  //                   color: _selectedPaymentMethod == 'paypal' ? Color(0xFF0070BA) : Colors.white10,
  //                   borderRadius: BorderRadius.circular(8),
  //                   border: Border.all(
  //                     color: _selectedPaymentMethod == 'paypal' ? Color(0xFF0070BA) : Colors.grey,
  //                     width: 2,
  //                   ),
  //                 ),
  //                 child: Row(
  //                   mainAxisAlignment: MainAxisAlignment.center,
  //                   children: [
  //                     Icon(
  //                       Icons.payment,
  //                       color: _selectedPaymentMethod == 'paypal' ? Colors.white : Colors.grey,
  //                     ),
  //                     SizedBox(width: 8),
  //                     Text(
  //                       'PayPal',
  //                       style: TextStyle(
  //                         color: _selectedPaymentMethod == 'paypal' ? Colors.white : Colors.grey,
  //                         fontWeight: FontWeight.w600,
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ],
  //   );
  // }

  // Future<void> _handlePayPalPayment(int amountInCents, String uid, String fullAddress) async {
  //   try {
  //     print('Creating PayPal payment for $amountInCents cents...');
  //     final response = await http.post(
  //       Uri.parse('https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-paypal-payment'),
  //       body: jsonEncode({
  //         'amount': (_selectedPaymentAmount).toStringAsFixed(2),
  //         'currency': 'USD',
  //         'return_url': 'com.dissonant.app://paypal-success',
  //         'cancel_url': 'com.dissonant.app://paypal-cancel',
  //       }),
  //       headers: {'Content-Type': 'application/json'},
  //     );

  //     if (response.statusCode == 200) {
  //       final paymentData = jsonDecode(response.body);
  //       final approvalUrl = paymentData['approval_url'];
        
  //       if (approvalUrl != null) {
  //         // For now, show a simple message. In a full implementation, you'd:
  //         // 1. Open the PayPal approval URL in a web view
  //         // 2. Handle the callback to execute the payment
  //         // 3. Show success/failure accordingly
          
  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(
  //             content: Text('PayPal payment initiated! This would open PayPal in a full implementation.'),
  //             duration: Duration(seconds: 3),
  //           ),
  //         );
          
  //         // For demo purposes, simulate successful payment after delay
  //         await Future.delayed(Duration(seconds: 2));
          
  //         // Create shipping labels
  //         print('🔄 About to create shipping labels (PayPal)...');
  //         await _createShippingLabels(uid, fullAddress);
  //         print('✅ Shipping labels creation completed (PayPal)');
          
  //         await _firestoreService.addOrder(uid, fullAddress, flowVersion: 2, curatorId: widget.selectedCuratorId);
  //         await HomeScreen.addFreeOrderCredits(uid, 1);

  //         if (!mounted) return;
  //         setState(() {
  //           _isProcessing = false;
  //           _hasOrdered = true;
  //           _mostRecentOrderStatus = 'new';
  //         });

  //         ScaffoldMessenger.of(context).showSnackBar(
  //           SnackBar(content: Text('PayPal payment successful! Your order has been placed!')),
  //         );
  //       } else {
  //         throw Exception('No approval URL received from PayPal');
  //       }
  //     } else {
  //       throw Exception('Failed to create PayPal payment. Server error: ${response.body}');
  //     }
  //   } catch (e, stackTrace) {
  //     if (!mounted) return;
  //     setState(() {
  //       _isProcessing = false;
  //     });
  //     print('PayPal payment error: $e');
  //     try {
  //       FirebaseCrashlytics.instance.recordError(e, stackTrace);
  //     } catch (_) {}
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('PayPal payment failed: ${e.toString()}')),
  //     );
  //   }
  // }

  Future<void> _createShippingLabels(String uid, String fullAddress) async {
    try {
      print('=== SHIPPING LABELS DEBUG START ===');
      print('UID: $uid');
      print('Full Address: "$fullAddress"');
      
      // Get the current user's email
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        print('❌ User email not available for shipping labels');
        return;
      }
      print('✅ User email: ${user!.email}');

      // Parse the address string to extract components
      final addressLines = fullAddress.split('\n');
      print('Address lines count: ${addressLines.length}');
      print('Address lines: $addressLines');
      
      if (addressLines.length < 3) {
        print('❌ Invalid address format for shipping labels - need at least 3 lines');
        return;
      }

      final customerName = addressLines[0].trim();
      final streetAddress = addressLines[1].trim();
      final cityStateZip = addressLines[2].split(', ');
      
      print('Customer name: "$customerName"');
      print('Street address: "$streetAddress"');
      print('City/State/Zip parts: $cityStateZip');
      
      if (cityStateZip.length < 2) {
        print('❌ Invalid city/state/zip format - need at least 2 parts');
        return;
      }

      final city = cityStateZip[0].trim();
      final stateZip = cityStateZip[1].split(' ');
      
      print('City: "$city"');
      print('State/Zip parts: $stateZip');
      
      if (stateZip.length < 2) {
        print('❌ Invalid state/zip format - need at least 2 parts');
        return;
      }

      final state = stateZip[0].trim();
      final zip = stateZip.sublist(1).join(' ').trim();

      print('State: "$state"');
      print('Zip: "$zip"');

      // Create customer address object
      final customerAddress = {
        'name': customerName,
        'street1': streetAddress,
        'city': city,
        'state': state,
        'zip': zip,
        'country': 'US',
      };

      print('✅ Customer address object: $customerAddress');

      // Define parcel dimensions (CD case)
      final parcel = {
        'length': '5.5',
        'width': '5.0',
        'height': '0.5',
        'distance_unit': 'in',
        'weight': '0.2',
        'mass_unit': 'lb',
      };

      // Generate a unique order ID
      final orderId = 'ORDER-${DateTime.now().millisecondsSinceEpoch}';

      print('✅ Order ID: $orderId');
      print('✅ Parcel: $parcel');

      print('🚀 Calling Lambda endpoint...');
      final response = await http.post(
        Uri.parse('https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev/create-shipping-labels'),
        body: jsonEncode({
          'to_address': customerAddress,
          'parcel': parcel,
          'order_id': orderId,
          'customer_name': customerName,
          'customer_email': user.email,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      print('📡 Lambda response status: ${response.statusCode}');
      print('📡 Lambda response body: ${response.body}');

      if (response.statusCode == 200) {
        final labelData = jsonDecode(response.body);
        print('✅ Shipping labels created successfully:');
        print('Outbound: ${labelData['outbound_label']['label_url']}');
        print('Return: ${labelData['return_label']['label_url']}');
        
        // Labels are automatically emailed to warehouse staff and customer
        print('✅ Shipping labels created and emailed successfully');
        
      } else {
        print('❌ Failed to create shipping labels: ${response.body}');
      }
      
      print('=== SHIPPING LABELS DEBUG END ===');
    } catch (e, stackTrace) {
      print('❌ Error creating shipping labels: $e');
      print('❌ Stack trace: $stackTrace');
      // Don't fail the order if label creation fails
    }
  }


}

