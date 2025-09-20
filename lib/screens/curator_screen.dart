import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';
import '../services/firestore_service.dart';
import '../services/push_notification_service.dart';
import 'dissonant_library_screen.dart';
import 'public_profile_screen.dart';

class CuratorScreen extends StatefulWidget {
  const CuratorScreen({Key? key}) : super(key: key);

  @override
  _CuratorScreenState createState() => _CuratorScreenState();
}

class _CuratorScreenState extends State<CuratorScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final PushNotificationService _notificationService = PushNotificationService();
  
  bool _isLoading = true;
  bool _isCurator = false;
  bool _isSigningUp = false;
  bool _isOptingOut = false;
  bool _hasOrders = false;
  bool _isCheckingOrders = true;
  Set<String> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _checkCuratorStatus();
    _checkUserOrders();
    _initializeNotifications();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initialize();
    await _notificationService.requestPermissions();
  }

  Future<void> _checkCuratorStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await _firestoreService.getUserDoc(user.uid);
      if (userDoc != null && userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final isCurator = userData['isCurator'] ?? false;
        
        if (mounted) {
          setState(() {
            _isCurator = isCurator;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkUserOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final orderQuery = await FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (mounted) {
          setState(() {
            _hasOrders = orderQuery.docs.isNotEmpty;
            _isCheckingOrders = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _hasOrders = false;
            _isCheckingOrders = false;
          });
        }
      }
    } else {
      setState(() {
        _hasOrders = false;
        _isCheckingOrders = false;
      });
    }
  }

  Future<void> _showCuratorWarning() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151515),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: const BorderSide(color: Colors.white, width: 1),
          ),
          title: const Text(
            'Curator Responsibility',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Users may spend their hard earned money for your curation. Inactivity may result in ban from being a curator. Feel free to opt out whenever you\'d like.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'I Understand',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _becomeCurator();
    }
  }

  Future<void> _becomeCurator() async {
    setState(() {
      _isSigningUp = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // First, request and verify push notification permissions
        final hasPermission = await _notificationService.requestPermissions();
        
        if (!hasPermission) {
          setState(() {
            _isSigningUp = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Push notifications are required to become a curator. Please enable notifications in your device settings and try again.'),
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }

        // Get and store FCM token
        final token = await _notificationService.getToken();
        if (token == null) {
          setState(() {
            _isSigningUp = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to set up notifications. Please check your connection and try again.'),
            ),
          );
          return;
        }

        // Mark user as curator
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isCurator': true,
          'curatorJoinedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Subscribe to curator notifications
        await _notificationService.subscribeToTopic('curator_${user.uid}');

        if (mounted) {
          setState(() {
            _isCurator = true;
            _isSigningUp = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to the curator community! You\'ll receive notifications for new orders.')),
        );
      }
    } catch (e) {
      setState(() {
        _isSigningUp = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error becoming curator: $e')),
      );
    }
  }

  Future<int> _getPendingOrdersCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('curatorId', isEqualTo: user.uid)
          .where('status', whereIn: ['curator_assigned', 'in_progress'])
          .get();
      
      return querySnapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting pending orders count: $e');
      return 0;
    }
  }

  Future<void> _showOptOutDialog() async {
    final pendingOrdersCount = await _getPendingOrdersCount();
    
    if (!mounted) return;

    String dialogContent;
    if (pendingOrdersCount > 0) {
      dialogContent = 'Are you sure you want to surrender the $pendingOrdersCount order${pendingOrdersCount == 1 ? '' : 's'} waiting for your curation? ${pendingOrdersCount == 1 ? 'This order' : 'These orders'} will become standard Dissonant orders.';
    } else {
      dialogContent = 'Are you sure you want to opt out of being a curator? You can always become a curator again later.';
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151515),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
            side: const BorderSide(color: Colors.white, width: 1),
          ),
          title: const Text(
            'Opt Out of Curator',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            dialogContent,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Yes, Opt Out',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _optOutOfCurator();
    }
  }

  Future<void> _optOutOfCurator() async {
    setState(() {
      _isOptingOut = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Convert pending curator orders to standard orders
        await _convertCuratorOrdersToStandard(user.uid);

        // Remove curator status
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'isCurator': false,
          'curatorOptedOutAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          setState(() {
            _isCurator = false;
            _isOptingOut = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have successfully opted out of being a curator.')),
        );
      }
    } catch (e) {
      setState(() {
        _isOptingOut = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opting out: $e')),
      );
    }
  }

  Future<void> _convertCuratorOrdersToStandard(String curatorId) async {
    try {
      // Get all pending orders for this curator
      final querySnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('curatorId', isEqualTo: curatorId)
          .where('status', whereIn: ['curator_assigned', 'in_progress'])
          .get();

      // Convert each order to standard order
      final batch = FirebaseFirestore.instance.batch();
      
      for (final doc in querySnapshot.docs) {
        batch.update(doc.reference, {
          'curatorId': FieldValue.delete(),
          'status': 'new',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error converting curator orders to standard: $e');
      rethrow;
    }
  }

  Future<void> _refreshCuratorData() async {
    // Refresh curator status and any other data
    await _checkCuratorStatus();
    // The StreamBuilder will automatically refresh the orders list
  }

  Future<void> _refreshSignupData() async {
    // Refresh user order status for signup eligibility
    await _checkUserOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GrainyBackgroundWidget(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isCurator
                  ? _buildCuratorSuccess()
                  : RefreshIndicator(
                      onRefresh: _refreshSignupData,
                      child: _buildSignupScreen(),
                    ),
        ),
      ),
    );
  }

  Widget _buildSignupScreen() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
          const SizedBox(height: 20),
                Image.asset(
                  'assets/curateicon.png',
            width: 100,
            height: 100,
          ),
          const SizedBox(height: 24),
          const Text(
            'Become a Community Curator',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF151515),
              border: Border.all(color: Colors.white, width: 1),
            ),
            child: const Text(
              'Pick albums from our library for users\n\nProvide great recommendations and earn positive reviews!\n\nEach curation gives you a credit towards a free order.\n\nNote: Push notifications are required to receive new order alerts.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          RetroButtonWidget(
            text: _isCheckingOrders 
                ? 'Checking Eligibility...' 
                : _isSigningUp 
                    ? 'Signing Up...' 
                    : !_hasOrders 
                        ? 'Must Have Order First'
                        : 'Become Curator',
            onPressed: (_isCheckingOrders || _isSigningUp || !_hasOrders) ? null : _showCuratorWarning,
            style: !_hasOrders && !_isCheckingOrders ? RetroButtonStyle.dark : RetroButtonStyle.light,
            fixedHeight: true,
          ),
          const SizedBox(height: 20),
          if (!_hasOrders && !_isCheckingOrders)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'You need to place at least one order before becoming a curator.',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (!_hasOrders && !_isCheckingOrders)
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCuratorSuccess() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Image.asset(
                'assets/curateicon.png',
                width: 40,
                height: 40,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Curator Dashboard',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              SizedBox(
                width: 70,
                height: 28,
                child: ElevatedButton(
                  onPressed: _isOptingOut ? null : _showOptOutDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                      side: const BorderSide(color: Colors.white, width: 1),
                    ),
                  ),
                  child: Text(
                    _isOptingOut ? 'Opting...' : 'Opt Out',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Orders List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshCuratorData,
            child: _buildOrdersList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrdersList() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Text(
          'Please log in to view orders',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('curatorId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your connection and try again',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                RetroButtonWidget(
                  text: 'Retry',
                  onPressed: () {
                    setState(() {
                      // This will rebuild the StreamBuilder
                    });
                  },
                  style: RetroButtonStyle.light,
                  fixedHeight: true,
                ),
              ],
            ),
          );
        }

        final allOrders = snapshot.data?.docs ?? [];
        
        // Show ALL orders the curator has worked on, not just active ones
        final orders = allOrders.toList();
        
        // Sort by status priority (active orders first), then by timestamp
        orders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aStatus = aData['status'] as String?;
          final bStatus = bData['status'] as String?;
          
          // Define status priority (lower number = higher priority)
          final statusPriority = {
            'curator_assigned': 1,
            'in_progress': 2,
            'ready_to_ship': 3,
            'sent': 4,
            'returned': 5,
            'kept': 6,
            'delivered': 7,
            'returnedConfirmed': 8,
          };
          
          final aPriority = statusPriority[aStatus] ?? 999;
          final bPriority = statusPriority[bStatus] ?? 999;
          
          if (aPriority != bPriority) {
            return aPriority.compareTo(bPriority);
          }
          
          // If same priority, sort by timestamp (newest first for completed orders, oldest first for active)
          final aTimestamp = aData['timestamp'] as Timestamp?;
          final bTimestamp = bData['timestamp'] as Timestamp?;
          
          if (aTimestamp == null && bTimestamp == null) return 0;
          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;
          
          // For active orders (curator_assigned, in_progress), show oldest first
          // For completed orders, show newest first
          if (aPriority <= 2) {
            return aTimestamp.compareTo(bTimestamp);
          } else {
            return bTimestamp.compareTo(aTimestamp);
          }
        });

        if (orders.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/curateicon.png',
                      width: 80,
                      height: 80,
                      opacity: const AlwaysStoppedAnimation(0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Orders Yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You\'ll receive notifications when users request your curation services.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final orderDoc = orders[index];
            final orderData = orderDoc.data() as Map<String, dynamic>;
            final orderId = orderDoc.id;
            
            return _buildOrderCard(orderId, orderData);
          },
        );
      },
    );
  }

  Widget _buildOrderCard(String orderId, Map<String, dynamic> orderData) {
    final userId = orderData['userId'] as String?;
    final status = orderData['status'] as String?;
    final timestamp = orderData['timestamp'] as Timestamp?;
    final albumId = orderData['albumId'] as String?;
    
    // Determine card styling based on status
    final isActive = status == 'curator_assigned' || status == 'in_progress';
    final isCompleted = status == 'kept' || status == 'returned' || status == 'returnedConfirmed';
    final isNew = status == 'curator_assigned';
    
    // Get status display info
    final statusInfo = _getStatusDisplayInfo(status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(
          color: isActive ? Colors.orangeAccent : (isCompleted ? Colors.green.withOpacity(0.7) : Colors.white),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user info and status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? Colors.orangeAccent.withOpacity(0.1) : 
                     isCompleted ? Colors.green.withOpacity(0.1) : null,
            ),
            child: Row(
              children: [
                if (isNew)
                  const Icon(
                    Icons.priority_high,
                    color: Colors.orangeAccent,
                    size: 20,
                  ),
                if (isNew) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                        future: _getUsernameFromId(userId),
                        builder: (context, snapshot) {
                          final username = snapshot.data ?? 'Loading...';
                          return Text(
                            'Order from $username',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      if (timestamp != null)
                        Text(
                          'Received: ${_formatTimestamp(timestamp)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      // Show album info for completed orders
                      if (isCompleted && albumId != null)
                        FutureBuilder<String?>(
                          future: _getAlbumTitle(albumId),
                          builder: (context, snapshot) {
                            final albumTitle = snapshot.data;
                            if (albumTitle != null) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Album: $albumTitle',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white60,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusInfo['color'],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusInfo['text'],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    if (isNew) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _toggleTasteProfile(orderId),
                        child: Icon(
                          _expandedCards.contains(orderId) 
                              ? Icons.keyboard_arrow_up 
                              : Icons.keyboard_arrow_down,
                          color: Colors.orangeAccent,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Expandable taste profile section (only for new orders)
          if (isNew && _expandedCards.contains(orderId))
            _buildTasteProfileSection(userId),
          // Curator review section (for completed orders)
          if (isCompleted)
            _buildCuratorReviewSection(orderId, userId),
          // Action buttons
          _buildActionButtons(orderId, orderData, status),
        ],
      ),
    );
  }

  Map<String, dynamic> _getStatusDisplayInfo(String? status) {
    switch (status) {
      case 'curator_assigned':
        return {'color': Colors.orangeAccent, 'text': 'NEW'};
      case 'in_progress':
        return {'color': Colors.green, 'text': 'IN PROGRESS'};
      case 'ready_to_ship':
        return {'color': Colors.purple, 'text': 'READY TO SHIP'};
      case 'sent':
        return {'color': Colors.yellow, 'text': 'SENT'};
      case 'returned':
        return {'color': Colors.blue, 'text': 'RETURNED'};
      case 'kept':
        return {'color': Colors.green, 'text': 'KEPT'};
      case 'delivered':
        return {'color': Colors.green.shade700, 'text': 'DELIVERED'};
      case 'returnedConfirmed':
        return {'color': Colors.blue.shade700, 'text': 'RETURN CONFIRMED'};
      default:
        return {'color': Colors.grey, 'text': 'UNKNOWN'};
    }
  }

  Widget _buildActionButtons(String orderId, Map<String, dynamic> orderData, String? status) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: RetroButtonWidget(
              text: 'View Profile',
              onPressed: () => _viewCustomerProfile(orderData['userId'] as String?),
              style: RetroButtonStyle.light,
              fixedHeight: true,
            ),
          ),
          const SizedBox(width: 12),
          if (status == 'curator_assigned' || status == 'in_progress')
            Expanded(
              child: RetroButtonWidget(
                text: status == 'curator_assigned' ? 'Start Curation' : 'Continue',
                onPressed: () => _startCuration(orderId, orderData),
                style: RetroButtonStyle.light,
                fixedHeight: true,
              ),
            )
          else
            Expanded(
              child: RetroButtonWidget(
                text: 'View Details',
                onPressed: () => _viewOrderDetails(orderId, orderData),
                style: RetroButtonStyle.dark,
                fixedHeight: true,
              ),
            ),
        ],
      ),
    );
  }

  Future<String?> _getAlbumTitle(String albumId) async {
    try {
      final albumDoc = await FirebaseFirestore.instance
          .collection('albums')
          .doc(albumId)
          .get();
      
      if (albumDoc.exists) {
        final albumData = albumDoc.data() as Map<String, dynamic>;
        return albumData['title'] as String?;
      }
      return null;
    } catch (e) {
      print('Error fetching album title: $e');
      return null;
    }
  }

  Widget _buildCuratorReviewSection(String orderId, String? userId) {
    if (userId == null) return const SizedBox.shrink();
    
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();
    
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('curatorReviews')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.green,
                strokeWidth: 2,
              ),
            ),
          );
        }
        
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              border: Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.3)),
              ),
            ),
            child: const Text(
              'No review received yet',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
        
        final reviewDoc = snapshot.data!.docs.first;
        final reviewData = reviewDoc.data() as Map<String, dynamic>;
        final rating = reviewData['rating'] as double?;
        final comment = reviewData['comment'] as String?;
        final reviewTimestamp = reviewData['timestamp'] as Timestamp?;
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            border: Border(
              top: BorderSide(color: Colors.green.withOpacity(0.3)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.star,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Customer Review',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (reviewTimestamp != null)
                    Text(
                      _formatTimestamp(reviewTimestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (rating != null)
                Row(
                  children: [
                    ...List.generate(3, (index) {
                      return Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 16,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      '${rating.toStringAsFixed(1)}/3.0',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (comment != null && comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  comment,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _viewOrderDetails(String orderId, Map<String, dynamic> orderData) {
    // Show a dialog or navigate to a detailed view
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151515),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: const BorderSide(color: Colors.white, width: 1),
        ),
        title: const Text(
          'Order Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ID: $orderId',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${orderData['status']}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            if (orderData['curatorNote'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Your Note: ${orderData['curatorNote']}',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<String> _getUsernameFromId(String? userId) async {
    if (userId == null) return 'Unknown User';
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return userData['username'] ?? 'Unknown User';
      }
      return 'Unknown User';
    } catch (e) {
      print('Error fetching username: $e');
      return 'Unknown User';
    }
  }

  void _toggleTasteProfile(String orderId) {
    setState(() {
      if (_expandedCards.contains(orderId)) {
        _expandedCards.remove(orderId);
      } else {
        _expandedCards.add(orderId);
      }
    });
  }

  Widget _buildTasteProfileSection(String? userId) {
    if (userId == null) return const SizedBox.shrink();
    
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getTasteProfile(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.orangeAccent,
                strokeWidth: 2,
              ),
            ),
          );
        }
        
        final tasteProfile = snapshot.data;
        
        if (tasteProfile == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No taste profile available',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
        
        // Check if taste profile has any content
        final hasGenres = tasteProfile['genres'] != null && 
                         (tasteProfile['genres'] as List).isNotEmpty;
        final hasDecades = tasteProfile['decades'] != null && 
                          (tasteProfile['decades'] as List).isNotEmpty;
        final hasBio = tasteProfile['musicalBio'] != null && 
                      tasteProfile['musicalBio'].toString().isNotEmpty;
        final hasAlbumsListened = tasteProfile['albumsListened'] != null && 
                                 tasteProfile['albumsListened'].toString().isNotEmpty;
        
        if (!hasGenres && !hasDecades && !hasBio && !hasAlbumsListened) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Taste profile is empty',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          );
        }
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black26,
            border: Border(
              top: BorderSide(color: Colors.orangeAccent.withOpacity(0.3)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Taste Profile',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (hasGenres) ...[
                _buildTasteProfileItem(
                  'Favorite Genres',
                  (tasteProfile['genres'] as List).join(', '),
                ),
                const SizedBox(height: 8),
              ],
              if (hasDecades) ...[
                _buildTasteProfileItem(
                  'Favorite Decades',
                  (tasteProfile['decades'] as List).join(', '),
                ),
                const SizedBox(height: 8),
              ],
              if (hasAlbumsListened) ...[
                _buildTasteProfileItem(
                  'Albums Listened',
                  tasteProfile['albumsListened'].toString(),
                ),
                const SizedBox(height: 8),
              ],
              if (hasBio) ...[
                _buildTasteProfileItem(
                  'Musical Bio',
                  tasteProfile['musicalBio'].toString(),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTasteProfileItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _getTasteProfile(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        // Check if tasteProfile exists
        if (userData.containsKey('tasteProfile')) {
          final tasteProfile = userData['tasteProfile'] as Map<String, dynamic>?;
          return tasteProfile;
        }
        
        // Check if profileCustomization exists (alternative location)
        if (userData.containsKey('profileCustomization')) {
          final profileCustomization = userData['profileCustomization'] as Map<String, dynamic>?;
          return profileCustomization;
        }
        
        return null;
      }
      return null;
    } catch (e) {
      print('Error fetching taste profile: $e');
      return null;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _viewCustomerProfile(String? userId) {
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer information not available')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfileScreen(userId: userId),
      ),
    );
  }

  void _startCuration(String orderId, Map<String, dynamic> orderData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DissonantLibraryScreen(
          orderId: orderId,
          orderData: orderData,
        ),
      ),
    );
  }
} 