import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import 'curator_order_screen.dart';
import 'product_details_screen.dart';

class OrderSelectionScreen extends StatefulWidget {
  @override
  _OrderSelectionScreenState createState() => _OrderSelectionScreenState();
}

class _OrderSelectionScreenState extends State<OrderSelectionScreen> {
  bool _isLoading = true;
  bool _hasOrdered = false;
  String _mostRecentOrderStatus = '';

  @override
  void initState() {
    super.initState();
    _fetchMostRecentOrderStatus();
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
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: GrainyBackgroundWidget(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _hasOrdered
                ? _buildPlaceOrderMessage(_mostRecentOrderStatus)
                : _buildSelectionScreen(),
      ),
    );
  }

  Widget _buildPlaceOrderMessage(String status) {
    String message;
    if (status == 'returned') {
      message = "Once we've confirmed your return you'll be able to order another album!";
    } else if (status == 'pending' || status == 'sent' || status == 'new') {
      message = "Thanks for placing an order! You will be able to place another once this one is completed.";
    } else {
      // Fallback for any unexpected status - should match the logic in _fetchMostRecentOrderStatus
      print('WARNING: Unexpected order status "$status" in order selection message display');
      message = "Thanks for placing an order! You will be able to place another once this one is completed.";
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

  Widget _buildSelectionScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Choose Your Order Type',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: _buildOrderOption(
                    icon: Image.asset(
                      'assets/dissonantordericon.png',
                      width: 64,
                      height: 64,
                    ),
                    title: 'Dissonant',
                    subtitle: 'Curated by us',
                    onTap: () => _navigateToProductDetails(
                      productType: 'dissonant',
                      curatorId: null,
                    ),
                    isEnabled: true,
                  ),
                ),
                SizedBox(width: 24.0),
                Expanded(
                  child: _buildOrderOption(
                    icon: Image.asset(
                      'assets/curateicon.png',
                      width: 64,
                      height: 64,
                    ),
                    title: 'Community\nCurators',
                    subtitle: 'Choose your curator',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CuratorOrderScreen(),
                      ),
                    ),
                    isEnabled: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderOption({
    required Widget icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool isEnabled,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white10 : Colors.white12,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: isEnabled ? Colors.orangeAccent : Colors.grey,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isEnabled ? Colors.white : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: isEnabled ? Colors.white70 : Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToProductDetails({
    required String productType,
    String? curatorId,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(
          productType: productType,
          curatorId: curatorId,
        ),
      ),
    );
  }
} 