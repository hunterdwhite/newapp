import 'package:flutter/material.dart';
import 'package:dissonantapp2/widgets/grainy_background_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../services/firestore_service.dart';
import '../widgets/retro_button_widget.dart';
import '../models/album_model.dart';
import '../models/feed_item_model.dart';
import 'album_detail_screen.dart';
import 'public_profile_screen.dart';
import 'dart:math'; // make sure this is at the top

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> 
    with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;

  final FirestoreService _firestoreService = FirestoreService();

  // Paginated feed
  List<FeedItem> _feedItems = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMoreData = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 15; // Increased for better performance
  
  // Performance optimizations
  static final Map<int, String> _spineAssetMap = {};
  static const List<String> _spineOptions = [
    'assets/spineasset1.png',
    'assets/spineasset2.png',
  ];
  static const List<int> _spineWeights = [80, 30];
  static final Random _random = Random();

  // Page-view controller
  late final PageController _pageController;
  int _currentIndex = 0;

  // "Stacked spines" constants
  static const double spineHeight = 45;
  static const int maxSpines = 5;

  // Performance tracking
  final Set<int> _visibleItems = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fetchInitialFeedItems();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  /* ─────────────────────────── DATA LAYER (Optimized) ─────────────────────────── */

  void _onPageChanged() {
    if (!_pageController.hasClients) return;
    
    final newIndex = _pageController.page?.round() ?? 0;
    if (newIndex != _currentIndex && newIndex < _feedItems.length) {
      setState(() => _currentIndex = newIndex);

      // Prefetch more data when approaching end
      if (newIndex >= _feedItems.length - 3 && _hasMoreData && !_isFetchingMore) {
        _fetchMoreFeedItems();
      }

      // Preload next image for smoother scrolling
      if (newIndex + 1 < _feedItems.length) {
        precacheImage(
          NetworkImage(_feedItems[newIndex + 1].album.albumImageUrl),
          context,
        );
      }
    }
  }

  Future<void> _fetchInitialFeedItems() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final query = FirebaseFirestore.instance
          .collection('orders')
          .where('status', whereIn: ['kept', 'returnedConfirmed'])
          .orderBy('updatedAt', descending: true)
          .limit(_pageSize);

      final snap = await query.get();
      if (snap.docs.isNotEmpty) _lastDocument = snap.docs.last;

      final newItems = await _processOrderDocs(snap.docs);

      if (!mounted) return;
      setState(() {
        _feedItems = newItems;
        _isLoading = false;
        _hasMoreData = snap.docs.length == _pageSize;
      });

      // Preload first few images
      _preloadInitialImages();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error loading feed items: $e');
      }
    }
  }

  void _preloadInitialImages() {
    for (int i = 0; i < _feedItems.length && i < 3; i++) {
      precacheImage(
        NetworkImage(_feedItems[i].album.albumImageUrl),
        context,
      );
    }
  }

  Future<void> _fetchMoreFeedItems() async {
    if (_isFetchingMore || !_hasMoreData || !mounted) return;
    setState(() => _isFetchingMore = true);

    try {
      var query = FirebaseFirestore.instance
          .collection('orders')
          .where('status', whereIn: ['kept', 'returnedConfirmed'])
          .orderBy('updatedAt', descending: true)
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snap = await query.get();
      if (snap.docs.isNotEmpty) _lastDocument = snap.docs.last;

      final more = await _processOrderDocs(snap.docs);

      if (!mounted) return;
      setState(() {
        _feedItems.addAll(more);
        _isFetchingMore = false;
        _hasMoreData = snap.docs.length == _pageSize;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingMore = false);
        _showErrorSnackBar('Error loading more feed items: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Optimized batch processing
  Future<List<FeedItem>> _processOrderDocs(List<DocumentSnapshot> docs) async {
    final List<FeedItem> items = [];
    final Set<String> processedAlbums = {}; // Avoid duplicates
    
    // Batch fetch albums and users
    final Map<String, Album> albumCache = {};
    final Map<String, Map<String, String>> userCache = {};

    for (final doc in docs) {
      if (!mounted) break;
      
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final albumId = data['details']?['albumId'] as String?;
      final userId = data['userId'] as String? ?? '';

      if (albumId == null || albumId.isEmpty || processedAlbums.contains(albumId)) {
        continue;
      }

      processedAlbums.add(albumId);

      try {
        // Get album (with caching)
        Album? album = albumCache[albumId];
        if (album == null) {
          final albumDoc = await FirebaseFirestore.instance
              .collection('albums')
              .doc(albumId)
              .get();
          if (albumDoc.exists) {
            album = Album.fromDocument(albumDoc);
            albumCache[albumId] = album;
          }
        }

        if (album == null) continue;

        // Get user info (with caching)
        Map<String, String>? userInfo = userCache[userId];
        if (userInfo == null && userId.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data() ?? {};
            userInfo = {
              'username': userData['username'] ?? 'Unknown',
              'avatar': userData['profilePictureUrl'] ?? '',
            };
            userCache[userId] = userInfo;
          }
        }

        final username = userInfo?['username'] ?? 'Unknown';
        final avatar = userInfo?['avatar'] ?? '';

        items.add(FeedItem(
          username: username,
          userId: userId,
          status: data['status'] ?? '',
          album: album,
          profilePictureUrl: avatar,
        ));
      } catch (e) {
        debugPrint('Error processing album $albumId: $e');
        continue;
      }
    }

    return items;
  }

  /* ─────────────────────────── SPINE LOGIC (Optimized) ─────────────────────────── */
  
  String _getSpineAsset(int index) {
    if (_spineAssetMap.containsKey(index)) {
      return _spineAssetMap[index]!;
    }

    // Weighted random selection with better performance
    final randomValue = _random.nextInt(100);
    int cumulativeWeight = 0;
    
    for (int i = 0; i < _spineWeights.length; i++) {
      cumulativeWeight += _spineWeights[i];
      if (randomValue < cumulativeWeight) {
        _spineAssetMap[index] = _spineOptions[i];
        return _spineOptions[i];
      }
    }
    
    // Fallback
    _spineAssetMap[index] = _spineOptions[0];
    return _spineOptions[0];
  }

  /* ─────────────────────────── UI LAYER (Optimized) ─────────────────────────── */

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    return Scaffold(
      body: GrainyBackgroundWidget(
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              )
            : _feedItems.isEmpty
                ? _buildEmptyState()
                : _buildFeedView(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No albums in the feed yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Be the first to share an album!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: _feedItems.length + (_isFetchingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _feedItems.length) {
          // Loading indicator for more items
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
          );
        }

        return VisibilityDetector(
          key: Key('feed_item_$index'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction > 0.5) {
              _visibleItems.add(index);
              // Preload adjacent images
              _preloadAdjacentImages(index);
            } else {
              _visibleItems.remove(index);
            }
          },
          child: _buildFeedItem(_feedItems[index], index),
        );
      },
    );
  }

  void _preloadAdjacentImages(int currentIndex) {
    // Preload previous and next images
    for (int offset in [-1, 1]) {
      final targetIndex = currentIndex + offset;
      if (targetIndex >= 0 && targetIndex < _feedItems.length) {
        precacheImage(
          NetworkImage(_feedItems[targetIndex].album.albumImageUrl),
          context,
        );
      }
    }
  }

  /* ─────────────────────────── UI ─────────────────────────── */

  Widget _buildFeedItem(FeedItem item, int index) {
    final actionText = item.status == 'kept' ? 'kept' : 'returned';
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /* ――― top bar ――― */
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 12),
              child: Row(
                children: [
                  // ONE avatar, wrapped to make it tappable
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(userId: item.userId),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.grey.shade700,
                      backgroundImage: item.profilePictureUrl.isNotEmpty
                          ? NetworkImage(item.profilePictureUrl)
                          : null,
                      child: item.profilePictureUrl.isEmpty
                          ? const Icon(Icons.person, size: 20, color: Colors.white)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // username (still tappable as before)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PublicProfileScreen(userId: item.userId),
                        ),
                      );
                    },
                    child: Text(
                      item.username,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),
                  Text(
                    actionText,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const Spacer(),
                ],
              ),
            ),

            const SizedBox(height: 16),

            /* ――― cover art ――― */
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.35,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AlbumDetailScreen(album: item.album),
                  ),
                ),
                child: Image.network(
                  item.album.albumImageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (c, w, p) =>
                      p == null ? w : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (c, e, st) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.error, size: 100, color: Colors.red),
                      SizedBox(height: 8),
                      Text('Failed to load image', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            /* ――― artist – album title ――― */
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '${item.album.artist} – ${item.album.albumName}',   // <- artist field
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                //fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),

            const SizedBox(height: 30),

            /* ――― wishlist button ――― */
            RetroButtonWidget(
              text: 'Add to Wishlist',
              style: RetroButtonStyle.light,
              fixedHeight: true,
              onPressed: () => _addToWishlist(item.album.albumId),
            ),
          ],
        ),
      ),
    );
  }


  /* spines */
Widget _buildSpines(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;
  final screenWidth = MediaQuery.of(context).size.width;

  // Shrink spines on smaller screens
  final isSmallScreen = screenHeight < 750;
  final spineHeight = isSmallScreen ? 38.0 : 45.0;
  final maxSpines = 4; // fewer spines for better fit
  final spineWidth = screenWidth * 0.85;

  return Positioned(
    bottom: isSmallScreen ? 4 : 16, // margin below stack
    left: 0,
    right: 0,
    child: SizedBox(
      height: maxSpines * spineHeight,
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          final page = _pageController.hasClients && _pageController.page != null
              ? _pageController.page!
              : _currentIndex.toDouble();

          return Stack(
            clipBehavior: Clip.none,
            children: List.generate(maxSpines, (i) {
              final spineIndex = _currentIndex + i + 1;
              if (spineIndex >= _feedItems.length) return const SizedBox.shrink();

              final offset = page - _currentIndex;
              final bottomOffset = (maxSpines - i - 1) * (spineHeight * 0.45) - offset * (spineHeight * 0.45);

              // Randomized spine asset per index
              if (!_spineAssetMap.containsKey(spineIndex)) {
                final rand = _random.nextInt(100);
                _spineAssetMap[spineIndex] =
                    rand < _spineWeights[0] ? _spineOptions[0] : _spineOptions[1];
              }
              final assetPath = _spineAssetMap[spineIndex]!;

              return Positioned(
                bottom: bottomOffset,
                left: 0,
                right: 0,
                child: Center(
                  child: SizedBox(
                    width: spineWidth,
                    child: AspectRatio(
                      aspectRatio: 7,
                      child: Image.asset(
                        assetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    ),
  );
}








Widget _buildSpine(FeedItem item) {
  return AspectRatio(
    aspectRatio: 7, // or adjust this based on your image’s natural dimensions
    child: Image.asset(
      'assets/spineasset.png',
      fit: BoxFit.contain, // ensures the image isn't cropped or stretched
    ),
  );
}



Widget _buildSpineImageOnly(FeedItem item) {
  return Image.asset(
    'assets/spineasset.png',
    fit: BoxFit.contain,
  );
}

Widget _buildHeaderBar(FeedItem item) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: item.userId)),
          ),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade700,
            backgroundImage: item.profilePictureUrl.isNotEmpty
                ? NetworkImage(item.profilePictureUrl)
                : null,
            child: item.profilePictureUrl.isEmpty
                ? const Icon(Icons.person, size: 20, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PublicProfileScreen(userId: item.userId)),
          ),
          child: Text(
            item.username,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          item.status == 'kept' ? 'kept' : 'returned',
          style: const TextStyle(fontSize: 16, color: Colors.white70),
        ),
        const Spacer(),
      ],
    ),
  );
}

Widget _buildAnimatedFeedItem(FeedItem item, int index) {
  return AnimatedBuilder(
    animation: _pageController,
    builder: (context, child) {
      var opacity = 1.0;

      if (_pageController.hasClients && _pageController.page != null) {
        final diff = (index - _pageController.page!).abs();
        opacity = (1 - diff).clamp(0.0, 1.0);
      }

      return Opacity(
        opacity: opacity,
        child: _buildFeedItem(item, index),
      );
    },
  );
}

  /* ─────────────────────────── build ─────────────────────────── */

@override
Widget build(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final screenHeight = mediaQuery.size.height;
  final topPadding = mediaQuery.padding.top;
  final bottomPadding = mediaQuery.padding.bottom;
  final totalSpinesHeight = maxSpines * 48.0;

  final feedHeight = screenHeight - topPadding - bottomPadding - totalSpinesHeight;

  return Scaffold(
    body: GrainyBackgroundWidget(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Stack(
                children: [
                  _buildSpines(context),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        const Text(
                          'My Feed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(
                          height: feedHeight,
                          child: PageView.builder(
                            controller: _pageController,
                            scrollDirection: Axis.vertical,
                            itemCount: _feedItems.length,
                            itemBuilder: (c, i) => _buildFeedItem(_feedItems[i], i),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isFetchingMore)
                    Positioned(
                      bottom: totalSpinesHeight + 20,
                      left: 0,
                      right: 0,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
    ),
  );
}



}
