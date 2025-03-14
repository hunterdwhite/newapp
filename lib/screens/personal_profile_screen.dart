import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

// Import the custom CarouselWidget you provided
import '../widgets/carousel_widget.dart';

class PersonalProfileScreen extends StatefulWidget {
  final String userId;

  const PersonalProfileScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _PersonalProfileScreenState createState() => _PersonalProfileScreenState();
}

class _PersonalProfileScreenState extends State<PersonalProfileScreen> {
  final _auth = FirebaseAuth.instance;

  // Basic user info
  String _username = '';
  String? _profilePictureUrl;

  // Stats
  int _albumsSentBack = 0;
  int _albumsKept = 0;

  // For "Music History" carousel
  List<String> _albumCoverUrls = [];

  // For "Wishlist" carousel
  List<String> _wishlistCoverUrls = [];

  bool _isLoading = true;
  bool _isOwnProfile = false;

  // Orange accent color
  static const Color _orangeAccent = Color(0xFFFFA500);

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    try {
      final currentUser = _auth.currentUser;
      final currentUserId = currentUser?.uid;
      _isOwnProfile = (currentUserId == widget.userId);

      // 1) Load user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (!userDoc.exists) {
        throw Exception('User not found');
      }

      final userData = userDoc.data()!;
      _username = userData['username'] ?? 'Unknown User';
      _profilePictureUrl = userData['profilePictureUrl'];

      // 2) Load orders for 'kept' or 'returned'
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: widget.userId)
          .where('status', whereIn: ['kept', 'returned', 'returnedConfirmed'])
          .get();

      final keptAlbumIds = <String>[];
      final returnedAlbumIds = <String>[];
      for (var orderDoc in ordersSnapshot.docs) {
        final orderData = orderDoc.data();
        final status = orderData['status'];
        final albumId = orderData['albumId'] ?? orderData['details']?['albumId'];
        if (albumId == null) continue;

        if (status == 'kept') {
          keptAlbumIds.add(albumId);
        } else {
          returnedAlbumIds.add(albumId);
        }
      }

      _albumsKept = keptAlbumIds.length;
      _albumsSentBack = returnedAlbumIds.length;

      // For Music History, gather unique albumIds
      final allAlbumIds = [...keptAlbumIds, ...returnedAlbumIds];
      final uniqueAlbumIds = allAlbumIds.toSet().toList();

      // 3) Fetch coverUrls for Music History
      final historyCovers = <String>[];
      for (var aId in uniqueAlbumIds) {
        final albumDoc = await FirebaseFirestore.instance
            .collection('albums')
            .doc(aId)
            .get();
        if (albumDoc.exists) {
          final albumData = albumDoc.data();
          final coverUrl = albumData?['coverUrl'];
          if (coverUrl != null) {
            historyCovers.add(coverUrl as String);
          }
        }
      }
      _albumCoverUrls = historyCovers;

      // 4) Fetch Wishlist albumIds from user's wishlist subcollection
      final wishlistSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('wishlist')
          .get();
      final wishlistAlbumIds = <String>[];
      for (var wishDoc in wishlistSnapshot.docs) {
        final wishData = wishDoc.data();
        final albumId = wishData['albumId'] ?? wishDoc.id;
        wishlistAlbumIds.add(albumId);
      }

      // 5) Get coverUrls for wishlist
      final wishlistCovers = <String>[];
      final uniqueWishIds = wishlistAlbumIds.toSet().toList();
      for (var wId in uniqueWishIds) {
        final albumDoc = await FirebaseFirestore.instance
            .collection('albums')
            .doc(wId)
            .get();
        if (albumDoc.exists) {
          final albumData = albumDoc.data();
          final coverUrl = albumData?['coverUrl'];
          if (coverUrl != null) {
            wishlistCovers.add(coverUrl as String);
          }
        }
      }
      _wishlistCoverUrls = wishlistCovers;

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error in _fetchProfileData: $e');
      setState(() => _isLoading = false);
    }
  }

  // If it's your own profile, let you pick a new profile pic
Future<void> _onAddProfilePhoto() async {
  try {
    // Create an instance of ImagePicker
    final picker = ImagePicker();

    // Pick an image
    final XFile? pickedImage =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedImage == null) {
      // User canceled image picking
      return;
    }

    // Convert to a File
    final File imageFile = File(pickedImage.path);

    // Create a reference to Firebase Storage
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profilePictures')
        .child('${widget.userId}.jpg');

    // Upload file
    await storageRef.putFile(imageFile);

    // Get download URL
    final downloadUrl = await storageRef.getDownloadURL();

    // Update user's profilePictureUrl in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .update({
      'profilePictureUrl': downloadUrl,
    });

    // Update local state
    setState(() {
      _profilePictureUrl = downloadUrl;
    });

    print('Profile picture updated successfully.');
  } catch (e) {
    print('Error updating profile picture: $e');
    // Optionally, handle the error by showing a user-friendly message
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _orangeAccent))
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Header
                      _buildProfileHeader(),
                      SizedBox(height: 24),

                      // Stats
                      _buildStatsSection(),
                      SizedBox(height: 24),

                      // Music History (using CarouselWidget)
                      _buildMusicHistorySection(),
                      SizedBox(height: 24),

                      // Wishlist (using CarouselWidget)
                      _buildWishlistSection(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _orangeAccent, width: 2),
              ),
              child: ClipOval(
                child: (_profilePictureUrl == null || _profilePictureUrl!.isEmpty)
                    ? Container(
                        color: Colors.grey[800],
                        child: Icon(
                          Icons.person,
                          color: Colors.white54,
                          size: 50,
                        ),
                      )
                    : Image.network(
                        _profilePictureUrl!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            if (_isOwnProfile)
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: _onAddProfilePhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _orangeAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 16,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(width: 16),
        Expanded(
          child: Text(
            _username,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _orangeAccent,
              fontFamily: 'MS Sans Serif',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    final total = _albumsSentBack + _albumsKept;
    final double ratio = (total == 0) ? 0.5 : (_albumsKept / total);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border.all(color: _orangeAccent, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Row with "Sent Back" and "Kept" counts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statsText('Albums Sent Back', _albumsSentBack),
              _statsText('Albums Kept', _albumsKept),
            ],
          ),
          SizedBox(height: 12),
          // Simple slider-like bar
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _orangeAccent, width: 1.5),
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment((ratio * 2) - 1, 0),
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _orangeAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsText(String label, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'MS Sans Serif',
          ),
        ),
        SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            color: _orangeAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'MS Sans Serif',
          ),
        ),
      ],
    );
  }

  Widget _buildMusicHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Music History',
          style: TextStyle(
            color: _orangeAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'MS Sans Serif',
          ),
        ),
        SizedBox(height: 12),
        // If no covers, show a message. Otherwise, show the CarouselWidget.
        if (_albumCoverUrls.isEmpty)
          Center(
            child: Text(
              'No albums found in your history.',
              style: TextStyle(color: Colors.white60),
            ),
          )
        else
          // Use your CarouselWidget
          CarouselWidget(imgList: _albumCoverUrls),
      ],
    );
  }

  Widget _buildWishlistSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Wishlist',
          style: TextStyle(
            color: _orangeAccent,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'MS Sans Serif',
          ),
        ),
        SizedBox(height: 12),
        if (_wishlistCoverUrls.isEmpty)
          Center(
            child: Text(
              'No albums in your wishlist.',
              style: TextStyle(color: Colors.white60),
            ),
          )
        else
          CarouselWidget(imgList: _wishlistCoverUrls),
      ],
    );
  }
}
