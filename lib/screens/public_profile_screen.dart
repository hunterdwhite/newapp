import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../widgets/grainy_background_widget.dart';
import 'my_music_library_screen.dart';
import 'wishlist_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({required this.userId});

  @override
  _PublicProfileScreenState createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  // Basic user info
  String _username = '';
  String? _profilePictureUrl;

  // Stats
  int _albumsSentBack = 0;
  int _albumsKept = 0;

  // For “Their Music” and “Wishlist”
  List<String> _historyCoverUrls = [];
  List<String> _wishlistCoverUrls = [];

  bool _isLoading = true;

  // Tells us if we’re viewing the owner’s profile
  bool get _isOwner {
    final currentUser = FirebaseAuth.instance.currentUser;
    return (currentUser != null && currentUser.uid == widget.userId);
  }

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  /// Fetch user doc, orders, wishlist for this userId
  Future<void> _fetchProfileData() async {
    try {
      // 1) Get the user doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) throw Exception('User not found');

      final userData = userDoc.data()!;
      _username = userData['username'] ?? 'Unknown User';
      _profilePictureUrl = userData['profilePictureUrl'];

      // 2) Orders: 'kept', 'returned', 'returnedConfirmed'
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
      _albumsSentBack = returnedAlbumIds.length;
      _albumsKept = keptAlbumIds.length;

      // For “Their Music” preview
      final allAlbumIds = {...keptAlbumIds, ...returnedAlbumIds};
      _historyCoverUrls = await _fetchAlbumCovers(allAlbumIds);

      // 3) Hybrid wishlist approach
      final wishlistSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('wishlist')
          .orderBy('dateAdded', descending: true)
          .get();

      // We'll unify covers from both new minimal docs & older docs
      final covers = <String>[];

      for (final wDoc in wishlistSnapshot.docs) {
        final wData = wDoc.data();
        // If older docs used doc ID for albumId, fallback:
        String? docAlbumId = wData['albumId'] ?? wDoc.id;

        // If no albumId but there's an albumImageUrl, fallback
        final docAlbumImageUrl = wData['albumImageUrl'] as String?; 

        // 1) If docAlbumId is not empty, try to fetch that album doc
        if (docAlbumId != null && docAlbumId.isNotEmpty) {
          final albumSnap = await FirebaseFirestore.instance
              .collection('albums')
              .doc(docAlbumId)
              .get();
          if (albumSnap.exists) {
            final aData = albumSnap.data();
            final coverUrl = aData?['coverUrl'] as String?;
            if (coverUrl != null) {
              covers.add(coverUrl);
              continue; // Done, no need to match by image
            }
          }
          // else fallback to next approach if we also have docAlbumImageUrl
        }

        // 2) If docAlbumId was empty or invalid, but we do have docAlbumImageUrl
        if (docAlbumImageUrl != null && docAlbumImageUrl.isNotEmpty) {
          final querySnap = await FirebaseFirestore.instance
              .collection('albums')
              .where('coverUrl', isEqualTo: docAlbumImageUrl)
              .limit(1)
              .get();

          if (querySnap.docs.isNotEmpty) {
            final matchedAlbum = querySnap.docs.first.data();
            final coverUrl = matchedAlbum['coverUrl'] as String?;
            if (coverUrl != null) {
              covers.add(coverUrl);
              continue;
            }
          }
          // if not found, fallback to partial data
          covers.add(docAlbumImageUrl); 
        }
        // if we still have nothing, that doc won't show a cover
      }

      _wishlistCoverUrls = covers;

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error in _fetchProfileData: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Load each album’s coverUrl from albums/{albumId}
  Future<List<String>> _fetchAlbumCovers(Set<String> albumIds) async {
    List<String> covers = [];
    for (final albumId in albumIds) {
      final albumDoc = await FirebaseFirestore.instance
          .collection('albums')
          .doc(albumId)
          .get();
      if (albumDoc.exists) {
        final data = albumDoc.data();
        final coverUrl = data?['coverUrl'] as String?;
        if (coverUrl != null) {
          covers.add(coverUrl);
        }
      }
    }
    return covers;
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
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

  /// If it's owner, display a white settings icon
  Widget _buildHeaderRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Show the user’s Firestore "username"
        Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              '<',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),

        // If it’s their own profile, show settings
        if (_isOwner)
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              // e.g. Navigator.push(...);
              print('Settings tapped, but typically goes to OptionsScreen');
            },
          ),
      ],
    );
  }

  /// Circular avatar with a white border
  Widget _buildProfileAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        image: _profilePictureUrl != null
            ? DecorationImage(
                image: NetworkImage(_profilePictureUrl!),
                fit: BoxFit.cover,
              )
            : null,
        color: Colors.grey[800],
      ),
      child: (_profilePictureUrl == null)
          ? const Icon(Icons.person, color: Colors.white54, size: 60)
          : null,
    );
  }

  /// Show “No stats to show” if none. Otherwise show “Kept vs Returned”
  Widget _buildStatsSection() {
    final kept = _albumsKept;
    final returned = _albumsSentBack;
    final total = kept + returned;

    if (total == 0) {
      return Center(
        child: Text(
          'No stats to show.',
          style: TextStyle(color: Colors.white60),
        ),
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
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Up to 3 covers for “My Music” or “Their Music”
Widget _buildMusicRow(BuildContext context) {
  final recentMusic = _historyCoverUrls.take(3).toList();
  final title = _isOwner ? 'My Music' : 'Their Music';

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MyMusicLibraryScreen(userId: widget.userId),
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
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Image.asset(
                  'assets/orangearrow.png',
                  width: 10,
                  height: 10,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (i < recentMusic.length)
                        ? Image.network(
                            recentMusic[i],
                            fit: BoxFit.contain,
                          )
                        : Container(),
                  ),
                );
              }).expand((widget) => [widget, const SizedBox(width: 8)]).toList()
                ..removeLast(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}


Widget _buildWishlistRow(BuildContext context) {
  final recentWishlist = _wishlistCoverUrls.take(3).toList();

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WishlistScreen(userId: widget.userId),
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
            child: Row(
              children: [
                const Text(
                  'Wishlist',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Image.asset(
                  'assets/orangearrow.png',
                  width: 10,
                  height: 10,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: List.generate(3, (i) {
                return Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: (i < recentWishlist.length)
                        ? Image.network(
                            recentWishlist[i],
                            fit: BoxFit.contain,
                          )
                        : Container(),
                  ),
                );
              }).expand((widget) => [widget, const SizedBox(width: 8)]).toList()
                ..removeLast(),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

}
