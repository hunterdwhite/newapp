import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/models/order_model.dart';
import '/services/firestore_service.dart';
import '../widgets/grainy_background_widget.dart'; // Import the BackgroundWidget
import '../widgets/retro_button_widget.dart'; // Import the RetroButtonWidget
import 'package:keyboard_actions/keyboard_actions.dart'; // Corrected import

class OrderScreen extends StatefulWidget {
  @override
  _OrderScreenState createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  String _firstName = '';
  String _lastName = '';
  String _address = '';
  String _city = '';
  String _state = '';
  String _zipcode = '';
  String? _selectedAddress;

  bool _hasOrdered = false;
  bool _isLoading = true;
  String _mostRecentOrderStatus = '';

  final List<String> _states = [
    'AL',
    'AK',
    'AZ',
    'AR',
    'CA',
    'CO',
    'CT',
    'DE',
    'FL',
    'GA',
    'HI',
    'ID',
    'IL',
    'IN',
    'IA',
    'KS',
    'KY',
    'LA',
    'ME',
    'MD',
    'MA',
    'MI',
    'MN',
    'MS',
    'MO',
    'MT',
    'NE',
    'NV',
    'NH',
    'NJ',
    'NM',
    'NY',
    'NC',
    'ND',
    'OH',
    'OK',
    'OR',
    'PA',
    'RI',
    'SC',
    'SD',
    'TN',
    'TX',
    'UT',
    'VT',
    'VA',
    'WA',
    'WV',
    'WI',
    'WY'
  ];

  // Define FocusNodes for the fields
  final FocusNode _zipcodeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchMostRecentOrderStatus();
  }

  @override
  void dispose() {
    // Dispose of the FocusNodes
    _zipcodeFocusNode.dispose();
    super.dispose();
  }

  /// Fetches the most recent order based on the timestamp field
  Future<void> _fetchMostRecentOrderStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot orderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true) // Sorting by timestamp
          .limit(1) // Get the most recent order
          .get();

      if (orderSnapshot.docs.isNotEmpty) {
        DocumentSnapshot orderDoc = orderSnapshot.docs.first;
        String status = orderDoc['status'] ?? '';

        if (!mounted) return;
        setState(() {
          _mostRecentOrderStatus = status;
          // If the status is 'kept' or 'returnedConfirmed', the user can place a new order
          if (status == 'kept' || status == 'returnedConfirmed') {
            _hasOrdered = false; // User can place a new order
          } else {
            _hasOrdered = true; // User cannot place a new order
          }
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _hasOrdered = false; // No orders exist, user can place a new order
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderModel = Provider.of<OrderModel>(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Let KeyboardActions handle the insets
      body: BackgroundWidget(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(),
              )
            : _hasOrdered
                ? _buildPlaceOrderMessage(_mostRecentOrderStatus)
                : KeyboardActions(
                    config: _buildKeyboardActionsConfig(),
                    child: SafeArea(
                      child: Form(
                        key: _formKey,
                        child: _buildOrderForm(orderModel, user),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildPlaceOrderMessage(String status) {
    String message;
    if (status == 'pending' ||
        status == 'sent' ||
        status == 'new' ||
        status == 'returned') {
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

  Widget _buildOrderForm(OrderModel orderModel, User? user) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Where should we send your music?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.0),
          if (orderModel.previousAddresses.isNotEmpty) ...[
            Text(
              'Use a previous address:',
              style: TextStyle(color: Colors.white),
            ),
            DropdownButtonFormField<String>(
              value: _selectedAddress,
              items: orderModel.previousAddresses
                  .map((address) => DropdownMenuItem(
                        value: address,
                        child: Text(address),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedAddress = value;
                  if (value != null) {
                    _populateFieldsFromSelectedAddress(value);
                  }
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16.0),
            Text(
              'Or enter a new address:',
              style: TextStyle(color: Colors.white),
            ),
          ],
          SizedBox(height: 16.0),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'First Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your first name';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _firstName = value;
              });
            },
          ),
          SizedBox(height: 16.0),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Last Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your last name';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _lastName = value;
              });
            },
          ),
          SizedBox(height: 16.0),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'Address (including apartment number)',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your address';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _address = value;
              });
            },
          ),
          SizedBox(height: 16.0),
          TextFormField(
            decoration: InputDecoration(
              labelText: 'City',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your city';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _city = value;
              });
            },
          ),
          SizedBox(height: 16.0),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'State',
              border: OutlineInputBorder(),
            ),
            value: _state.isNotEmpty ? _state : null,
            items: _states.map((String state) {
              return DropdownMenuItem<String>(
                value: state,
                child: Text(state),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _state = newValue ?? '';
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your state';
              }
              return null;
            },
          ),
          SizedBox(height: 16.0),
          TextFormField(
            focusNode: _zipcodeFocusNode, // Assign the FocusNode
            decoration: InputDecoration(
              labelText: 'Zipcode',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your zipcode';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _zipcode = value;
              });
            },
          ),
          SizedBox(height: 16.0),
          RetroButton(
            text: 'Order Your CD',
            onPressed: () {
              FocusScope.of(context).unfocus(); // Dismiss the keyboard
              if (_formKey.currentState?.validate() ?? false) {
                final address =
                    '$_firstName $_lastName\n$_address\n$_city, $_state $_zipcode';
                _firestoreService.addOrder(user?.uid ?? '', address).then((_) {
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(user?.uid)
                      .update({
                    'hasOrdered': true,
                  });
                  if (!mounted) return;
                  setState(() {
                    _hasOrdered = true;
                    _mostRecentOrderStatus =
                        'pending'; // Assuming new order is pending
                  });
                });
              }
            },
            color: Color(0xFFFFA500), // Orange color for the retro button
          ),
        ],
      ),
    );
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
                    style: TextStyle(
                        color: Colors.blue, fontWeight: FontWeight.bold),
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
      if (nameParts.length >= 2) {
        _firstName = nameParts[0];
        _lastName = nameParts[1];
      }
      _address = parts[1];
      List<String> cityStateZip = parts[2].split(', ');
      if (cityStateZip.length == 2) {
        _city = cityStateZip[0];
        List<String> stateZip = cityStateZip[1].split(' ');
        if (stateZip.length == 2) {
          _state = stateZip[0];
          _zipcode = stateZip[1];
        }
      }
    }
    setState(() {});
  }
}
