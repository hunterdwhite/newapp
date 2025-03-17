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

  // For "My Music" and "Wishlist"
  List<String> _historyCoverUrls = [];
  List<String> _wishlistCoverUrls = [];

  bool _isLoading = true;
  bool _isOwnProfile = false;

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

      final userId = currentUser.uid;
      _isOwnProfile = true;

      // 1) Get user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!userDoc.exists) throw Exception('User not found');

      final userData = userDoc.data()!;
      _username = userData['username'] ?? 'Unknown User';
      _profilePictureUrl = userData['profilePictureUrl'];

      // 2) Orders: 'kept', 'returned', 'returnedConfirmed'
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: userId)
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
          .doc(userId)
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
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : BackgroundWidget( // <--- The grainy background
              child: SafeArea(
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
          style: TextStyle(
            color: Colors.white, // was orange, now white
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        // If it's their own profile, show a white settings icon
        if (_isOwnProfile)
          IconButton(
            icon: Icon(Icons.settings, color: Colors.white),
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
            border: Border.all(color: Colors.white, width: 3), // was orange
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
                  color: Colors.white,   // was orange
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Icon(Icons.camera_alt, color: Colors.black, size: 18),
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
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start, // Ensures left alignment inside
      children: [
        Text(
          'My Stats',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Kept: $kept, Returned: $returned',
            textAlign: TextAlign.left,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}




  /// Up to 3 "My Music" covers
  Widget _buildMusicRow(BuildContext context) {
    final recentMusic = _historyCoverUrls.take(3).toList();

    return GestureDetector(
      onTap: () {
        // Full library
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MyMusicLibraryScreen()),
        ).then((_) {
          // If you want to refresh:
          // _fetchProfileData();
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Music',
            style: TextStyle(
              color: Colors.white, // was orange
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
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (recentMusic.isNotEmpty)
                        ? Image.network(
                            recentMusic[0],
                            fit: BoxFit.contain,
                          )
                        : Container(),
                  ),
                ),
                SizedBox(width: 8),
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

  /// Up to 3 "Wishlist" covers
  Widget _buildWishlistRow(BuildContext context) {
    final recentWishlist = _wishlistCoverUrls.take(3).toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WishlistScreen()),
        ).then((_) {
          // If you want to refresh:
          // _fetchProfileData();
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wishlist',
            style: TextStyle(
              color: Colors.white, // was orange
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
                    child: (recentWishlist.isNotEmpty)
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
