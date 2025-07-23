import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/services/firestore_service.dart';

class SwipeSpoilerWidget extends StatefulWidget {
  final DocumentSnapshot order;
  final Function(String, String) updateImageAndInfo;
  final VoidCallback startDragging; // Callback to start dragging
  final VoidCallback stopDragging;  // Callback to stop dragging
  final Function(double) updateRotation; // Callback to update rotation

  SwipeSpoilerWidget({
    required this.order,
    required this.updateImageAndInfo,
    required this.startDragging,
    required this.stopDragging,
    required this.updateRotation, // Update rotation based on drag
  });

  @override
  _SwipeSpoilerWidgetState createState() => _SwipeSpoilerWidgetState();
}

class _SwipeSpoilerWidgetState extends State<SwipeSpoilerWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _imageUpdated = false;
  double _dragDistance = 0.0;
  double _opacity = 0.0;

  @override
  Widget build(BuildContext context) {
    final orderDetails = widget.order.data() as Map<String, dynamic>?;

    if (orderDetails == null ||
        !orderDetails.containsKey('details') ||
        !orderDetails['details'].containsKey('albumId')) {
      return Text('Error loading order details.', style: TextStyle(color: Colors.white));
    }

    final albumId = orderDetails['details']['albumId'];

    return GestureDetector(
      onPanStart: (_) {
        widget.startDragging(); // Start the large CD spinning in MyMusicScreen
      },
      onPanUpdate: (details) {
        // Accumulate the drag distance and update rotation angle and opacity
        _dragDistance += details.delta.dy;
        widget.updateRotation(details.delta.dy); // Update rotation in MyMusicScreen
        setState(() {
          _opacity = (_dragDistance / -100).clamp(0.0, 1.0);
        });
      },
      onPanEnd: (_) async {
        if (_dragDistance < -100) { // Adjust this threshold based on testing
          print('Swipe up released, triggering action!');
          await _fetchAlbumDetails(albumId);
        }
        // Reset the drag distance and opacity after the gesture ends
        setState(() {
          _dragDistance = 0.0;
          _opacity = 0.0;
        });
        widget.stopDragging(); // Stop the large CD spinning in MyMusicScreen
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 16.0),
              Icon(Icons.keyboard_arrow_up, size: 40, color: Colors.white),
              Text(
                'Swipe up to view album',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _fetchAlbumDetails(String albumId) async {
    try {
      final albumDoc = await _firestoreService.getAlbumById(albumId);
      final album = albumDoc.data() as Map<String, dynamic>;

      if (mounted && !_imageUpdated) {
        setState(() {
          _imageUpdated = true;
        });
        widget.updateImageAndInfo(
          album['coverUrl'] ?? 'assets/blank_cd.png',
          '${album['artist']} - ${album['albumName']}',
        );
        print('Album image and info updated in UI');
      }
    } catch (e) {
      if (mounted) {
        print('Error loading album details: $e');
      }
    }
  }
}