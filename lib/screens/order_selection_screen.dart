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
  bool _hasFreeOrder = false;

  @override
  void initState() {
    super.initState();
    _fetchMostRecentOrderStatus();
  }

  Future<void> _fetchMostRecentOrderStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Check if user has free orders available
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      bool hasFreeOrder = false;
      if (userDoc.exists) {
        Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
        hasFreeOrder = (userData?['freeOrder'] ?? false) && 
                       (userData?['freeOrdersAvailable'] ?? 0) > 0;
        
        // Debug logging
        print('DEBUG Order Selection: freeOrder=${userData?['freeOrder']}, freeOrdersAvailable=${userData?['freeOrdersAvailable']}, hasFreeOrder=$hasFreeOrder');
      }

      QuerySnapshot orderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get(const GetOptions(source: Source.server)); // Force fresh data from server

      if (orderSnapshot.docs.isNotEmpty) {
        DocumentSnapshot orderDoc = orderSnapshot.docs.first;
        String status = orderDoc['status'] ?? '';
        bool hasActiveOrder = !(status == 'kept' || status == 'returnedConfirmed');
        
        // Debug logging
        print('DEBUG Order Selection: Found order with status="$status", hasActiveOrder=$hasActiveOrder');
        
        if (!mounted) return;
        setState(() {
          _mostRecentOrderStatus = status;
          _hasOrdered = hasActiveOrder;
          _hasFreeOrder = hasFreeOrder;
          _isLoading = false;
        });
      } else {
        print('DEBUG Order Selection: No orders found for user');
        if (!mounted) return;
        setState(() {
          _hasOrdered = false;
          _hasFreeOrder = hasFreeOrder;
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
    } else if (status == 'pending' || status == 'sent' || status == 'new' || status == 'curator_assigned') {
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
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
              Text(
                'Choose Your Order Type',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: _hasFreeOrder ? 24 : 48),
              if (_hasFreeOrder) ...[
                _buildFreeOrderBanner(),
                SizedBox(height: 24),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      hasFreeOrder: false,
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
                      onTap: () async {
                        // Navigate and refresh when coming back
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CuratorOrderScreen(),
                          ),
                        );
                        // Refresh order status after returning from curator flow
                        _fetchMostRecentOrderStatus();
                      },
                      isEnabled: true,
                      hasFreeOrder: _hasFreeOrder,
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFreeOrderBanner() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF10B981), // Green-500
            Color(0xFF059669), // Green-600
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Free Order Available!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Select Community Curators to use your free order',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderOption({
    required Widget icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required bool isEnabled,
    bool hasFreeOrder = false,
  }) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isEnabled ? Colors.white10 : Colors.white12,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: hasFreeOrder 
                    ? Color(0xFF10B981) 
                    : (isEnabled ? Colors.orangeAccent : Colors.grey),
                width: hasFreeOrder ? 2.5 : 2,
              ),
              boxShadow: hasFreeOrder ? [
                BoxShadow(
                  color: Color(0xFF10B981).withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: Offset(0, 4),
                ),
              ] : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    icon,
                    SizedBox(height: 12),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isEnabled ? Colors.white : Colors.grey,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isEnabled ? Colors.white70 : Colors.grey,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasFreeOrder)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF10B981).withOpacity(0.4),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars,
                      color: Colors.white,
                      size: 12,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'FREE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _navigateToProductDetails({
    required String productType,
    String? curatorId,
  }) async {
    // Navigate and refresh when coming back
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(
          productType: productType,
          curatorId: curatorId,
        ),
      ),
    );
    // Refresh order status after returning
    _fetchMostRecentOrderStatus();
  }
} 
