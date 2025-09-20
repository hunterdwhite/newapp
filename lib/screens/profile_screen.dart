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
import 'profile_customization_screen.dart';

// Import your custom grainy background widget:
import '../widgets/grainy_background_widget.dart';
import '../constants/responsive_utils.dart';

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

  // Profile customization
  String _bio = '';
  List<String> _favoriteGenres = [];
  String? _favoriteAlbumId;
  String _favoriteAlbumTitle = '';
  String _favoriteAlbumCover = '';

  // Curator info
  bool _isCurator = false;

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

      // Load curator info
      _isCurator = userData['isCurator'] ?? false;

      // Load profile customization
      final customization = userData['profileCustomization'] as Map<String, dynamic>?;
      if (customization != null) {
        _bio = customization['bio'] ?? '';
        _favoriteGenres = List<String>.from(customization['favoriteGenres'] ?? []);
        _favoriteAlbumId = customization['favoriteAlbumId'];
        _favoriteAlbumTitle = customization['favoriteAlbumTitle'] ?? '';
        _favoriteAlbumCover = customization['favoriteAlbumCover'] ?? '';
      }

      // 2) Orders: 'kept', 'returned', 'returnedConfirmed'
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: _myUserId)
          .where('status',
              whereIn: ['kept', 'returned', 'returnedConfirmed']).get();

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

  Future<void> _refreshProfileData() async {
    // Refresh all profile data
    await _fetchProfileData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GrainyBackgroundWidget(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refreshProfileData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: ResponsiveUtils.getResponsiveHorizontalPadding(context,
                      mobile: 16, tablet: 24, desktop: 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveUtils.getContainerMaxWidth(context),
                      ),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderRow(),
                        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
                        Center(child: _buildProfileAvatar()),
                        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                        // Curator badge section (if curator)
                        if (_isCurator) ...[
                          _buildCuratorBadgeSection(),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
                        ],
                        // Profile customization sections
                        if (_bio.isNotEmpty) ...[
                          _buildBioSection(),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
                        ],
                        if (_favoriteGenres.isNotEmpty) ...[
                          _buildFavoriteGenresSection(),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
                        ],
                        if (_favoriteAlbumId != null && _favoriteAlbumCover.isNotEmpty) ...[
                          _buildFavoriteAlbumSection(),
                          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16, tablet: 20, desktop: 24)),
                        ],
                        _buildStatsSection(),
                        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                        _buildMusicRow(context),
                        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20, tablet: 24, desktop: 28)),
                        _buildWishlistRow(context),
                        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24, tablet: 30, desktop: 36)),
                      ],
                    ),
                  ),
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
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  _username,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 22, tablet: 24, desktop: 26),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isCurator) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE46A14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'CURATOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // If it's their own profile, show edit and settings icons
        if (_isOwnProfile)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProfileCustomizationScreen()),
                  );
                },
              ),
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
          ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    return Stack(
      alignment: Alignment.center,
      children: [
              Container(
        width: ResponsiveUtils.isMobile(context) ? 100 : 120,
        height: ResponsiveUtils.isMobile(context) ? 100 : 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: ResponsiveUtils.isMobile(context) ? 2 : 3),
        ),
          child: ClipOval(
            child: (_profilePictureUrl == null || _profilePictureUrl!.isEmpty)
                                  ? Container(
                      color: Colors.grey[800],
                      child: Icon(Icons.person,
                          color: Colors.white54, 
                          size: ResponsiveUtils.isMobile(context) ? 50 : 60),
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
              child:               Container(
                width: ResponsiveUtils.isMobile(context) ? 26 : 30,
                height: ResponsiveUtils.isMobile(context) ? 26 : 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Icon(Icons.camera_alt, 
                    color: Colors.black, 
                    size: ResponsiveUtils.isMobile(context) ? 16 : 18),
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
        child: Text('No stats to show.',
            style: const TextStyle(color: Colors.white60)),
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

  Widget _buildBioSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Me',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _bio,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteGenresSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Favorite Genres',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _favoriteGenres.map((genre) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(0xFFE46A14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  genre,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteAlbumSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Favorite Album',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  _favoriteAlbumCover,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[700],
                      child: Icon(Icons.music_note, color: Colors.white54),
                    );
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  _favoriteAlbumTitle,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCuratorBadgeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE46A14), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.music_note,
            color: Color(0xFFE46A14),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'You\'re a Community Curator!',
                  style: TextStyle(
                    color: Color(0xFFE46A14),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'You curate music for the community',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
