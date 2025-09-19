import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'payment_screen.dart';
import 'return_album_screen.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/spoiler_widget.dart';
import '../widgets/retro_button_widget.dart'; // Import the RetroButtonWidget

class MyMusicScreen extends StatefulWidget {
  @override
  _MyMusicScreenState createState() => _MyMusicScreenState();
}

class _MyMusicScreenState extends State<MyMusicScreen> {
  bool _isLoading = true;
  bool _hasOrdered = false;
  bool _orderSent = false;
  bool _orderDelivered = false; // New variable to track if the order is delivered
  bool _returnConfirmed = false;
  bool _orderReturned = false;
  bool _orderKept = false; // New variable to track if the order is kept
  DocumentSnapshot? _order;
  String _currentImage = 'assets/blank_cd.png'; // Placeholder image
  String _albumInfo = ''; // Album information
  String _curatorMessage = ''; // Curator's message
  bool _isAlbumRevealed = false;
  bool _isDragging = false; // Track if the user is dragging
  double _rotationAngle = 0.0; // Track rotation based on drag distance
  double _cdOpacity = 0.0; // Track opacity based on drag distance

  @override
  void initState() {
    super.initState();
    _fetchOrderStatus();
  }

  Future<void> _fetchOrderStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Fetch the user's most recent order, ordered by the timestamp descending
      QuerySnapshot orderSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (orderSnapshot.docs.isNotEmpty) {
        final order = orderSnapshot.docs.first;
        final orderData =
            order.data() as Map<String, dynamic>?; // Cast as nullable
        if (orderData != null) {
          // Check if orderData is not null
          if (mounted) {
            String status =
                orderData['status'] ?? ''; // Handle missing 'status' field
            print('DEBUG: MyMusic - Order status: "$status"'); // Debug logging
            setState(() {
              _hasOrdered = true;
              _order = order;
              _orderSent = status == 'sent';
              _orderDelivered = status == 'delivered';
              _orderReturned = status == 'returned';
              _returnConfirmed = status == 'returnedConfirmed';
              _orderKept = status == 'kept';
              _isLoading = false;
            });
          }
        } else {
          // If orderData is null, set the state to indicate no orders
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasOrdered = false;
            });
          }
        }
      } else {
        // If no orders exist, just stop loading
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasOrdered = false;
          });
        }
      }
    }
  }

  void _updateImageAndInfo(String imageUrl, String albumInfo) async {
    if (mounted) {
      // Fetch curator message from the order
      String curatorMessage = '';
      if (_order != null) {
        final orderData = _order!.data() as Map<String, dynamic>?;
        // Try both field names for backward compatibility
        curatorMessage = orderData?['curatorNote'] ?? orderData?['curatorMessage'] ?? '';
        print('DEBUG: MyMusic - Curator message: "$curatorMessage"');
        print('DEBUG: MyMusic - Order data keys: ${orderData?.keys.toList()}');
      }
      
      setState(() {
        _currentImage = imageUrl;
        _albumInfo = albumInfo;
        _curatorMessage = curatorMessage;
        _isAlbumRevealed = true;
        _isDragging = false; // Stop dragging when album is revealed
        _rotationAngle = 0.0; // Reset rotation
        _cdOpacity = 1.0; // Ensure full opacity when the album is revealed
      });
    }
  }

  void _resetImageAndInfo() {
    setState(() {
      _currentImage = 'assets/blank_cd.png';
      _albumInfo = '';
      _curatorMessage = '';
      _isAlbumRevealed = false;
      _isDragging = false; // Ensure dragging is reset
      _rotationAngle = 0.0; // Reset rotation
      _cdOpacity = 0.0; // Reset opacity
    });
  }

  void _startDragging() {
    setState(() {
      _isDragging = true;
    });
  }

  void _stopDragging() {
    setState(() {
      _isDragging = false;
    });
  }

  void _updateRotation(double delta) {
    setState(() {
      _rotationAngle +=
          delta / -100.0; // Adjust this value to control spin speed
      _cdOpacity = (_rotationAngle / math.pi)
          .clamp(0.0, 1.0); // Update opacity based on rotation
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Display message based on order status
    if (_orderReturned) {
      // If the order status is 'returned', show the specific message
      return Scaffold(
        body: GrainyBackgroundWidget(
          child: Center(
            child: Text(
              "Once we receive your album you'll be able to order another!",
              style: TextStyle(fontSize: 24, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else if (_returnConfirmed || _orderKept || !_hasOrdered) {
      // If there's no order or status is 'returnedConfirmed' or 'kept', show a message
      return Scaffold(
        body: GrainyBackgroundWidget(
          child: Center(
            child: Text(
              'Order an album to see your music show up here.',
              style: TextStyle(fontSize: 24, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: GrainyBackgroundWidget(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: _hasOrdered
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_isAlbumRevealed)
                            // Show curator note for curator orders, default text for regular orders
                            _curatorMessage.isNotEmpty
                                ? GestureDetector(
                                    onTap: () => _showCuratorNoteDialog(),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.description,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          "Note from your curator",
                                          style: TextStyle(
                                            fontSize: 24,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  )
                                : Text(
                                    "Give it a listen and make your decision!",
                                    style: TextStyle(fontSize: 24, color: Colors.white),
                                    textAlign: TextAlign.center,
                                  ),
                          SizedBox(height: 45.0),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              if (!_isAlbumRevealed)
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxHeight: 300, maxWidth: 300),
                                  child: Image.asset(
                                    'assets/blank_cd.png',
                                  ),
                                ),
                              if (_isDragging || !_isAlbumRevealed)
                                Opacity(
                                  opacity: _cdOpacity,
                                  child: Transform.rotate(
                                    angle: _rotationAngle * math.pi * 2.0,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                          maxHeight: 300, maxWidth: 300),
                                      child: Image.asset(
                                        'assets/blank_cd_disc.png',
                                      ),
                                    ),
                                  ),
                                ),
                              if (_isAlbumRevealed)
                                GestureDetector(
                                  onTap: () {
                                    // Navigate to album details page when tapped
                                  },
                                  child: Column(
                                    children: [
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                            maxHeight: 300, maxWidth: 300),
                                        child: Image.network(
                                          _currentImage,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                            return Image.asset(
                                                'assets/blank_cd.png');
                                          },
                                        ),
                                      ),
                                      SizedBox(height: 10.0),
                                      // Display album information
                                      if (_albumInfo.isNotEmpty)
                                        Text(
                                          _albumInfo,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (_orderSent && !_orderDelivered && !_isAlbumRevealed) ...[
                            SizedBox(height: 16.0),
                            Text(
                              'Your album is on the way!',
                              style:
                                  TextStyle(fontSize: 24, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (!_orderSent && !_isAlbumRevealed) ...[
                            SizedBox(height: 16.0),
                            Text(
                              'A curator will choose an album for you soon.',
                              style:
                                  TextStyle(fontSize: 24, color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      )
                    : Center(
                        child: Text(
                          'Order an album to see your music show up here.',
                          style: TextStyle(fontSize: 24, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
              // Updated condition here - only show swipe when delivered
              if (_hasOrdered && !_isAlbumRevealed && _orderDelivered)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: SwipeSpoilerWidget(
                      order: _order!,
                      updateImageAndInfo: _updateImageAndInfo,
                      startDragging: _startDragging,
                      stopDragging: _stopDragging,
                      updateRotation: _updateRotation,
                    ),
                  ),
                ),
              if (_isAlbumRevealed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 90.0),
                  child: Column(
                    children: [
                      Text(
                        "Don't feel pressured to keep, returning means your next order is free!",
                        style: TextStyle(fontSize: 20, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 20.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: RetroButtonWidget(
                              text: 'Return Album',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReturnAlbumScreen(
                                      orderId: _order!.id,
                                    ),
                                  ),
                                ).then((value) {
                                  if (value == true) {
                                    _resetImageAndInfo();
                                    _fetchOrderStatus(); // Refresh order status
                                  }
                                });
                              },
                              style: RetroButtonStyle.dark,
                            ),
                          ),
                          SizedBox(width: 20.0),
                          Expanded(
                            child: RetroButtonWidget(
                              text: 'Keep Album',
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PaymentScreen(
                                      orderId: _order!.id,
                                    ),
                                  ),
                                );
                                if (result == true) {
                                  _resetImageAndInfo();
                                  _fetchOrderStatus(); // Refresh order status
                                }
                              },
                              style: RetroButtonStyle.light,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCuratorNoteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF4F4F4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
        titlePadding: EdgeInsets.zero,
        contentPadding: EdgeInsets.zero,
        title: Container(
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
          child: Row(
            children: [
              const Icon(
                Icons.description,
                color: Colors.black,
                size: 16,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Note from Your Curator',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'MS Sans Serif',
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 20,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F4),
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: const Center(
                    child: Text(
                      '×',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        content: Container(
          width: 300,
          constraints: const BoxConstraints(maxHeight: 300),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black54, width: 1),
                ),
                child: Text(
                  _curatorMessage.isNotEmpty ? _curatorMessage : 'No curator message available.',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'MS Sans Serif',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F4F4),
                        border: Border.all(color: Colors.black, width: 2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'OK',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'MS Sans Serif',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}
