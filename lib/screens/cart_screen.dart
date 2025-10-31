import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../services/shippo_address_service.dart';
import '../services/shipping_service.dart';
import '../services/firestore_service.dart';
import 'checkout_screen.dart';
import 'home_screen.dart';

class CartScreen extends StatefulWidget {
  final String productType;
  final double selectedPrice;
  final String priceLabel;
  final String? curatorId;

  const CartScreen({
    Key? key,
    required this.productType,
    required this.selectedPrice,
    required this.priceLabel,
    this.curatorId,
  }) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ShippoAddressService _addressService;
  late final ShippingService _shippingService;
  
  // Controllers for shipping address
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _zipcodeController = TextEditingController();
  
  String _state = '';
  bool _isCalculatingShipping = false;
  double? _shippingCost;
  String? _shippingError;
  bool _isAddressValid = false;
  
  // Previous addresses and free credit functionality
  List<String> _previousAddresses = [];
  bool _hasFreeOrder = false;

  final List<String> _states = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE',
    'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS',
    'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS',
    'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY',
    'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV',
    'WI', 'WY'
  ];

  @override
  void initState() {
    super.initState();
    _addressService = ShippoAddressService(
      endpointBase: 'https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev',
    );
    _shippingService = ShippingService(
      endpointBase: 'https://86ej4qdp9i.execute-api.us-east-1.amazonaws.com/dev',
    );
    
    // Load user data and previous addresses
    _loadUserData();
    _loadPreviousAddresses();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirestoreService().getUserDoc(user.uid);
      if (userDoc != null && userDoc.exists) {
        final docData = userDoc.data() as Map<String, dynamic>?;
        if (docData != null) {
          if (!mounted) return;
          setState(() {
            // Free orders only apply to community curator orders, not Dissonant orders
            _hasFreeOrder = (docData['freeOrder'] ?? false) && widget.productType == 'community';
          });
        }
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
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipcodeController.dispose();
    super.dispose();
  }

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
                      _buildShippingForm(),
                      SizedBox(height: 24),
                      _buildTotalSection(),
                      SizedBox(height: 24),
                      _buildCheckoutButton(),
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
            child: const Text(
              '<',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Your Cart',
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
      ? 'Dissonant Curation'
      : 'Community Curation';
    
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

  Widget _buildShippingForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Form(
        key: _formKey,
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
            
            // Previous addresses section
            if (_previousAddresses.isNotEmpty) ...[
              Text(
                'Use a previous address:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              ...(_previousAddresses.map((address) => _buildPreviousAddressOption(address)).toList()),
              SizedBox(height: 16),
              Text(
                'Or enter a new address:',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _firstNameController,
                    label: 'First Name',
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _lastNameController,
                    label: 'Last Name',
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: _addressController,
              label: 'Street Address',
            ),
            SizedBox(height: 16),
            _buildTextField(
              controller: _cityController,
              label: 'City',
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStateDropdown(),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    controller: _zipcodeController,
                    label: 'ZIP Code',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCalculatingShipping ? null : _calculateShipping,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasFreeOrder 
                    ? Color(0xFF10B981).withOpacity(0.8)
                    : Colors.orangeAccent.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isCalculatingShipping
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(_hasFreeOrder ? 'Confirming Address...' : 'Calculating Shipping...'),
                      ],
                    )
                  : Text(_hasFreeOrder ? 'Confirm Shipping Address' : 'Calculate Shipping'),
              ),
            ),
            if (_shippingError != null) ...[
              SizedBox(height: 8),
              Text(
                _shippingError!,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousAddressOption(String address) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _fillAddressFromPrevious(address),
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: Colors.orangeAccent,
                size: 16,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withOpacity(0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _fillAddressFromPrevious(String fullAddress) {
    // Parse the address string and fill the form fields
    // This is a simple implementation - you might want to make it more robust
    final parts = fullAddress.split(', ');
    if (parts.length >= 4) {
      // Assuming format: "First Last, Street, City, State Zip"
      final nameParts = parts[0].split(' ');
      if (nameParts.length >= 2) {
        _firstNameController.text = nameParts[0];
        _lastNameController.text = nameParts.sublist(1).join(' ');
      }
      _addressController.text = parts[1];
      _cityController.text = parts[2];
      
      // Parse state and zip from last part
      final stateZip = parts[3].split(' ');
      if (stateZip.length >= 2) {
        setState(() {
          _state = stateZip[0];
        });
        _zipcodeController.text = stateZip[1];
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orangeAccent, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
      onChanged: (_) => _resetShippingCalculation(),
    );
  }

  Widget _buildStateDropdown() {
    return DropdownButtonFormField<String>(
      value: _state.isNotEmpty ? _state : null,
      style: TextStyle(color: Colors.white),
      dropdownColor: Colors.black87,
      decoration: InputDecoration(
        labelText: 'State',
        labelStyle: TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.orangeAccent, width: 2),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
      items: _states.map((String state) {
        return DropdownMenuItem<String>(
          value: state,
          child: Text(state, style: TextStyle(color: Colors.white)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _state = newValue ?? '';
        });
        _resetShippingCalculation();
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select your state';
        }
        return null;
      },
    );
  }

  Widget _buildTotalSection() {
    if (_hasFreeOrder) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  'Free Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'This community curator order is completely free! You have a free credit that covers the full cost.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            _buildTotalRow('Subtotal:', 'FREE', isFree: true),
            SizedBox(height: 8),
            _buildTotalRow('Shipping:', 'FREE', isFree: true),
            Divider(color: Colors.green.withOpacity(0.3), height: 24),
            _buildTotalRow('Total:', 'FREE', isTotal: true, isFree: true),
          ],
        ),
      );
    }
    
    final subtotal = widget.selectedPrice;
    final shipping = _shippingCost ?? 0.0;
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
          _buildTotalRow(
            'Shipping:', 
            _shippingCost != null 
              ? '\$${shipping.toStringAsFixed(2)}'
              : 'Calculate shipping',
            isShipping: true,
          ),
          Divider(color: Colors.white30, height: 24),
          _buildTotalRow(
            'Total:', 
            '\$${total.toStringAsFixed(2)}',
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, String amount, {bool isTotal = false, bool isShipping = false, bool isFree = false}) {
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
            color: isFree 
              ? Colors.green 
              : (isShipping && _shippingCost == null ? Colors.white.withOpacity(0.5) : Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutButton() {
    final canCheckout = _isAddressValid && (_shippingCost != null || _hasFreeOrder);
    
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canCheckout ? _proceedToCheckout : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: canCheckout 
            ? (_hasFreeOrder ? Colors.green : Colors.orangeAccent) 
            : Colors.grey,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: canCheckout ? 4 : 0,
        ),
        child: Text(
          _hasFreeOrder 
            ? (canCheckout ? 'Place Free Order' : 'Complete shipping information')
            : (canCheckout ? 'Proceed to Checkout' : 'Complete shipping information'),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _resetShippingCalculation() {
    if (_shippingCost != null) {
      setState(() {
        _shippingCost = null;
        _shippingError = null;
        _isAddressValid = false;
      });
    }
  }

  Future<void> _calculateShipping() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Close the keyboard
    FocusScope.of(context).unfocus();
    
    setState(() {
      _isCalculatingShipping = true;
      _shippingError = null;
    });

    try {
      // First validate the address
      final validatedAddress = await _addressService.validate(
        street: _addressController.text.trim(),
        city: _cityController.text.trim(),
        state: _state,
        zip: _zipcodeController.text.trim(),
        name: '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim(),
      );

      if (validatedAddress == null) {
        setState(() {
          _shippingError = 'Invalid address. Please check your information.';
          _isCalculatingShipping = false;
        });
        return;
      }

      // Calculate shipping cost using GoShippo
      final shippingCost = await _calculateShippingCost(validatedAddress);
      
      setState(() {
        _shippingCost = shippingCost;
        _isAddressValid = true;
        _isCalculatingShipping = false;
      });

    } catch (e) {
      setState(() {
        _shippingError = 'Failed to calculate shipping: ${e.toString()}';
        _isCalculatingShipping = false;
      });
    }
  }

  Future<double> _calculateShippingCost(ValidatedAddress address) async {
    try {
      print('🚚 DEBUG: Starting shipping calculation...');
      
      // Your specific shipping origin and package details
      final fromAddress = {
        'name': 'Dissonant Music',
        'street1': '789 9th Ave',
        'city': 'New York',
        'state': 'NY',
        'zip': '10019',
        'country': 'US',
      };

      // Your specific package dimensions: 4.9 oz, 7x9 inches
      final parcel = {
        'length': '9.0',        // 9 inches
        'width': '7.0',         // 7 inches  
        'height': '0.5',        // Assume 0.5 inch thickness for album
        'distance_unit': 'in',
        'weight': '0.31',       // 4.9 oz = 0.31 lbs (4.9/16)
        'mass_unit': 'lb',
      };

      // Customer's validated address
      final toAddress = {
        'name': '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'street1': address.street,
        'city': address.city,
        'state': address.state,
        'zip': address.zip5,
        'country': 'US',
      };

      print('🏠 DEBUG: From address: $fromAddress');
      print('📍 DEBUG: To address: $toAddress');
      print('📦 DEBUG: Parcel: $parcel');
      print('🌐 DEBUG: API endpoint: ${_shippingService.endpointBase}/calculate-shipping');

      // Get the cheapest shipping rate from GoShippo
      final shippingRate = await _shippingService.getCheapestRate(
        fromAddress: fromAddress,
        toAddress: toAddress,
        parcel: parcel,
      );

      print('💰 DEBUG: Shipping rate result: ${shippingRate?.amount ?? 'NULL'}');

      if (shippingRate != null) {
        print('✅ DEBUG: Using real GoShippo rate: \$${shippingRate.amount}');
        return shippingRate.amount;
      } else {
        print('❌ DEBUG: No shipping rate returned, using fallback: \$4.99');
        // Fallback to standard rate if API fails
        return 4.99;
      }
    } catch (e) {
      print('❌ DEBUG: Error calculating shipping with GoShippo: $e');
      print('❌ DEBUG: Error type: ${e.runtimeType}');
      print('❌ DEBUG: Using fallback rate: \$4.99');
      // Fallback to standard rate if there's an error
      return 4.99;
    }
  }

  void _proceedToCheckout() {
    if (!_isAddressValid || (!_hasFreeOrder && _shippingCost == null)) return;
    
    final shippingAddress = {
      'firstName': _firstNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'address': _addressController.text.trim(),
      'city': _cityController.text.trim(),
      'state': _state,
      'zipCode': _zipcodeController.text.trim(),
    };
    
    if (_hasFreeOrder) {
      // For free orders, skip checkout and create order directly
      _createFreeOrder(shippingAddress);
    } else {
      // For paid orders, proceed to checkout
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutScreen(
            productType: widget.productType,
            selectedPrice: widget.selectedPrice,
            priceLabel: widget.priceLabel,
            shippingCost: _shippingCost!,
            shippingAddress: shippingAddress,
            curatorId: widget.curatorId,
          ),
        ),
      );
    }
  }

  Future<void> _createFreeOrder(Map<String, String> shippingAddress) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Create the full address string
      final fullAddress = '${shippingAddress['firstName']} ${shippingAddress['lastName']}, ${shippingAddress['address']}, ${shippingAddress['city']}, ${shippingAddress['state']} ${shippingAddress['zipCode']}';

      // Create the order
      await FirestoreService().addOrder(
        user.uid, 
        fullAddress, 
        flowVersion: 2, 
        curatorId: widget.curatorId
      );

      // Use the free order credit
      await _useFreeOrder(user.uid);

      // Show success message and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Free order placed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back to home
      Navigator.of(context).popUntil((route) => route.isFirst);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error placing order: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _useFreeOrder(String userId) async {
    // Use the proper method that decrements freeOrdersAvailable
    await HomeScreen.useFreeOrder(userId);
  }
}
