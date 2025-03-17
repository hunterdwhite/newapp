import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Adjust these imports to your actual file paths.
import 'my_music_library_screen.dart';
import 'wishlist_screen.dart';
import 'options_screen.dart'; // <-- Make sure to import the OptionsScreen

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

  // For "My Music" (kept or returned) and "Wishlist"
  List<String> _historyCoverUrls = [];
  List<String> _wishlistCoverUrls = [];

  bool _isLoading = true;
  bool _isOwnProfile = false;

  static const Color _orangeAccent = Color(0xFFFFA500);

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  /// Fetch user data, orders, wishlist, etc.
  Future<void> _fetchProfileData() async {
    try {
      final currentUser = _auth.currentUser;
      _isOwnProfile = (currentUser != null && currentUser.uid == widget.userId);

      // 1) Get user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (!userDoc.exists) throw Exception('User not found');

      final userData = userDoc.data()!;
      _username = userData['username'] ?? 'Unknown User';
      _profilePictureUrl = userData['profilePictureUrl'];

      // 2) Load orders for 'kept' / 'returned' / 'returnedConfirmed'
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: widget.userId)
          .where('status', whereIn: ['kept', 'returned', 'returnedConfirmed'])
          .get();

      final keptAlbumIds = <String>[];
      final returnedAlbumIds = <String>[];
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final status = data['status'];
        final albumId = data['albumId'] ?? data['details']?['albumId'];
        if (albumId == null) continue;

        if (status == 'kept') {
          keptAlbumIds.add(albumId);
        } else {
          returnedAlbumIds.add(albumId);
        }
      }
      _albumsKept = keptAlbumIds.length;
      _albumsSentBack = returnedAlbumIds.length;

      final allAlbumIds = [...keptAlbumIds, ...returnedAlbumIds].toSet();
      final historyCovers = <String>[];

      for (final albumId in allAlbumIds) {
        final albumDoc = await FirebaseFirestore.instance
            .collection('albums')
            .doc(albumId)
            .get();
        if (albumDoc.exists) {
          final aData = albumDoc.data();
          final coverUrl = aData?['coverUrl'];
          if (coverUrl != null) {
            historyCovers.add(coverUrl as String);
          }
        }
      }
      _historyCoverUrls = historyCovers;

      // 3) Wishlist
      final wishlistSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('wishlist')
          .orderBy('dateAdded', descending: true)
          .get();
      final wishlistAlbumIds = <String>[];
      for (final wDoc in wishlistSnapshot.docs) {
        final wData = wDoc.data();
        final albumId = wData['albumId'] ?? wDoc.id;
        wishlistAlbumIds.add(albumId);
      }
      final uniqueWishIds = wishlistAlbumIds.toSet();
      final wishlistCovers = <String>[];

      for (final albumId in uniqueWishIds) {
        final albumDoc = await FirebaseFirestore.instance
            .collection('albums')
            .doc(albumId)
            .get();
        if (albumDoc.exists) {
          final aData = albumDoc.data();
          final coverUrl = aData?['coverUrl'];
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

  /// Let user pick a new profile photo if it's their own profile
  Future<void> _onAddProfilePhoto() async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(source: ImageSource.gallery);
      if (pickedImage == null) return;

      final file = File(pickedImage.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profilePictures/${widget.userId}.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({
        'profilePictureUrl': downloadUrl,
      });

      setState(() => _profilePictureUrl = downloadUrl);
    } catch (e) {
      print('Error updating profile photo: $e');
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderRow(),
                    SizedBox(height: 16),
                    Center(child: _buildProfileAvatar()),
                    SizedBox(height: 24),
                    _buildStatsSection(),
                    SizedBox(height: 24),
                    _buildMusicRow(context),
                    SizedBox(height: 24),
                    _buildWishlistRow(context),
                    SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _username,
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_isOwnProfile)
          // Instead of the old "Edit Profile" text, we use a settings icon
          IconButton(
            icon: Icon(Icons.settings, color: _orangeAccent),
            onPressed: () {
              // Navigate to OptionsScreen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => OptionsScreen()),
              );
            },
          ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _orangeAccent, width: 3),
          ),
          child: ClipOval(
            child: (_profilePictureUrl == null || _profilePictureUrl!.isEmpty)
                ? Container(
                    color: Colors.grey[800],
                    child: Icon(Icons.person, color: Colors.white54, size: 60),
                  )
                : Image.network(_profilePictureUrl!, fit: BoxFit.cover),
          ),
        ),
        if (_isOwnProfile)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _onAddProfilePhoto,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _orangeAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.black,
                  size: 18,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsSection() {
    final kept = _albumsKept;
    final returned = _albumsSentBack;
    final total = kept + returned;
    if (total == 0) {
      return Center(
        child: Text('No stats to show.', style: TextStyle(color: Colors.white60)),
      );
    }
    // Example bar or stats
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Stats',
          style: TextStyle(
            color: _orangeAccent,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        // Example placeholder
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Kept: $kept, Returned: $returned',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  /// Show up to 3 covers in My Music, spaced with horizontal gaps, entire row clickable
  Widget _buildMusicRow(BuildContext context) {
    final recentMusic = _historyCoverUrls.take(3).toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MyMusicLibraryScreen()),
        ).then((_) {
          // Optionally refresh after returning
          // _fetchProfileData();
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Music',
            style: TextStyle(
              color: _orangeAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          if (recentMusic.isEmpty)
            Text(
              'No albums found in your history.',
              style: TextStyle(color: Colors.white60),
            )
          else
            Row(
              children: [
                // 1st cover
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (recentMusic.length > 0)
                        ? Image.network(
                            recentMusic[0],
                            fit: BoxFit.contain,
                          )
                        : Container(),
                  ),
                ),
                SizedBox(width: 8),
                // 2nd cover
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (recentMusic.length > 1)
                        ? Image.network(
                            recentMusic[1],
                            fit: BoxFit.contain,
                          )
                        : Container(),
                  ),
                ),
                SizedBox(width: 8),
                // 3rd cover
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (recentMusic.length > 2)
                        ? Image.network(
                            recentMusic[2],
                            fit: BoxFit.contain,
                          )
                        : Container(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Show up to 3 covers in Wishlist, spaced with horizontal gaps, entire row clickable
  Widget _buildWishlistRow(BuildContext context) {
    final recentWishlist = _wishlistCoverUrls.take(3).toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WishlistScreen()),
        ).then((_) {
          // Optionally refresh
          // _fetchProfileData();
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wishlist',
            style: TextStyle(
              color: _orangeAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          if (recentWishlist.isEmpty)
            Text(
              'No albums in your wishlist.',
              style: TextStyle(color: Colors.white60),
            )
          else
            Row(
              children: [
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (recentWishlist.length > 0)
                        ? Image.network(
                            recentWishlist[0],
                            fit: BoxFit.contain,
                          )
                        : Container(),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (recentWishlist.length > 1)
                        ? Image.network(
                            recentWishlist[1],
                            fit: BoxFit.contain,
                          )
                        : Container(),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (recentWishlist.length > 2)
                        ? Image.network(
                            recentWishlist[2],
                            fit: BoxFit.contain,
                          )
                        : Container(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
