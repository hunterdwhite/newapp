import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

// If you have separate screens for these, import them:
import 'my_music_library_screen.dart';
import 'wishlist_screen.dart';
import 'options_screen.dart';

// Import your custom grainy background widget:
import '../widgets/grainy_background_widget.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

/// A personal-profile flow for the currently logged-in user,
/// featuring stats, My Music, and Wishlist.
class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Basic user info
  String _username = '';
  String? _profilePictureUrl;

  // Stats
  int _albumsSentBack = 0;
  int _albumsKept = 0;

  // Covers for "My Music" and "Wishlist"
  List<String> _historyCoverUrls = [];
  List<String> _wishlistCoverUrls = [];

  bool _isLoading = true;
  bool _isOwnProfile = false;

  // We'll store the current user's ID so we can pass it to the library/wishlist screens
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  /// Fetch user doc, orders, wishlist for the currently logged-in user
  Future<void> _fetchProfileData() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      _myUserId = currentUser.uid;
      _isOwnProfile = true;

      // 1) Get user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_myUserId)
          .get();
      if (!userDoc.exists) throw Exception('User not found');

      final userData = userDoc.data()!;
      _username = userData['username'] ?? 'Unknown User';
      _profilePictureUrl = userData['profilePictureUrl'];

      // 2) Orders: 'kept', 'returned', 'returnedConfirmed'
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: _myUserId)
          .where('status', whereIn: ['kept', 'returned', 'returnedConfirmed'])
          .get();

      final keptAlbumIds = <String>[];
      final returnedAlbumIds = <String>[];
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String?;
        final albumId = data['albumId'] ?? data['details']?['albumId'];
        if (albumId == null || status == null) continue;

        if (status == 'kept') {
          keptAlbumIds.add(albumId);
        } else {
          returnedAlbumIds.add(albumId);
        }
      }
      _albumsKept = keptAlbumIds.length;
      _albumsSentBack = returnedAlbumIds.length;

      // Gather up to 3 covers for "My Music"
      final allAlbumIds = {...keptAlbumIds, ...returnedAlbumIds};
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
          .doc(_myUserId)
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

  Future<void> _onAddProfilePhoto() async {
    try {
      print('Entered _onAddProfilePhoto');
      if (!_isOwnProfile) {
        print('Not own profile, returning');
        return;
      }
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(source: ImageSource.gallery);
      if (pickedImage == null) {
        print('No image picked');
        return;
      }

      final file = File(pickedImage.path);
      print('Uploading file as: profilePictures/${_auth.currentUser!.uid}.jpg');

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profilePictures/${_auth.currentUser!.uid}.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      final bustCacheUrl =
          '$downloadUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({'profilePictureUrl': bustCacheUrl});

      setState(() => _profilePictureUrl = bustCacheUrl);
    } catch (e) {
      print('Error updating profile photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : BackgroundWidget(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderRow(),
                      const SizedBox(height: 16),
                      Center(child: _buildProfileAvatar()),
                      const SizedBox(height: 24),
                      _buildStatsSection(),
                      const SizedBox(height: 24),
                      _buildMusicRow(context),
                      const SizedBox(height: 24),
                      _buildWishlistRow(context),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Show the user's Firestore "username"
        Text(
          _username,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        // If it's their own profile, show a white settings icon
        if (_isOwnProfile)
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
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
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: ClipOval(
            child: (_profilePictureUrl == null || _profilePictureUrl!.isEmpty)
                ? Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.person, color: Colors.white54, size: 60),
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
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.black, size: 18),
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
        child: Text('No stats to show.', style: const TextStyle(color: Colors.white60)),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Stats',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Kept: $kept, Returned: $returned',
              textAlign: TextAlign.left,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// “My Music” row => pass _myUserId to MyMusicLibraryScreen
Widget _buildMusicRow(BuildContext context) {
  final recentMusic = _historyCoverUrls.take(3).toList();

  return GestureDetector(
    onTap: () {
      if (_myUserId == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MyMusicLibraryScreen(userId: _myUserId!),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 32,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/gradientbar.png'),
                fit: BoxFit.cover,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'My Music',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: List.generate(3, (index) {
                if (index < recentMusic.length) {
                  return Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black54),
                        ),
                        child: Image.network(
                          recentMusic[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                } else {
                  return const Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: SizedBox.shrink(),
                    ),
                  );
                }
              }),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}



  /// “Wishlist” row => pass _myUserId to WishlistScreen
Widget _buildWishlistRow(BuildContext context) {
  final recentWishlist = _wishlistCoverUrls.take(3).toList();

  return GestureDetector(
    onTap: () {
      if (_myUserId == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WishlistScreen(userId: _myUserId!),
        ),
      );
    },
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 32,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/gradientbar.png'),
                fit: BoxFit.cover,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Wishlist',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: List.generate(3, (index) {
                if (index < recentWishlist.length) {
                  return Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black54),
                        ),
                        child: Image.network(
                          recentWishlist[index],
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                } else {
                  return const Expanded(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: SizedBox.shrink(),
                    ),
                  );
                }
              }),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}


}
