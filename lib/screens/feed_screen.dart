import 'package:flutter/material.dart';
import 'package:dissonantapp2/widgets/grainy_background_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';
import '../widgets/retro_button_widget.dart';
import '../models/album_model.dart';
import '../models/feed_item_model.dart';
import 'album_detail_screen.dart';
import 'public_profile_screen.dart';
import 'dart:math'; // make sure this is at the top
import '../constants/responsive_utils.dart';

class FeedScreen extends StatefulWidget {
  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Paginated feed
  List<FeedItem> _feedItems = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMoreData = true;
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 10;
  // This map stores which spine asset was chosen for each spine index
  final Map<int, String> _spineAssetMap = {};

  // These are your available spine images
  final List<String> _spineOptions = [
    'assets/spineasset1.png',
    'assets/spineasset2.png',
  ];

  // Corresponding weights (e.g., 80% chance of spineasset1, 20% of spineasset2)
  final List<int> _spineWeights = [80, 30];
  final Random _random = Random(); // place this at the class level to reuse the same instance

  // Page-view controller
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // “Stacked spines”
  final double spineHeight = 45;
  final int maxSpines = 5;

  @override
  void initState() {
    super.initState();
    _fetchInitialFeedItems();
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    super.dispose();
  }

  /* ─────────────────────────── DATA LAYER ─────────────────────────── */

  void _onPageChanged() {
    final newIndex = _pageController.page?.round() ?? 0;
    if (newIndex != _currentIndex && newIndex < _feedItems.length) {
      setState(() => _currentIndex = newIndex);

      if (newIndex >= _feedItems.length - 2 && _hasMoreData) {
        _fetchMoreFeedItems();
      }
    }
  }

  Future<void> _fetchInitialFeedItems() async {
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

      if (_feedItems.isNotEmpty) {
        precacheImage(
          NetworkImage(_feedItems.first.album.albumImageUrl),
          context,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feed items: $e')),
        );
      }
    }
  }

  Future<void> _fetchMoreFeedItems() async {
    if (_isFetchingMore || !_hasMoreData) return;
    setState(() => _isFetchingMore = true);

    try {
      var query = FirebaseFirestore.instance
          .collection('orders')
          .where('status', whereIn: ['kept', 'returnedConfirmed'])
          .orderBy('updatedAt', descending: true)
          .limit(_pageSize);

      if (_lastDocument != null) query = query.startAfterDocument(_lastDocument!);

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more feed items: $e')),
        );
      }
    }
  }

  Future<List<FeedItem>> _processOrderDocs(List<DocumentSnapshot> docs) async {
    final items = <FeedItem>[];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      /* ── USER ─────────────────────────────────────────────── */
      final userId = data['userId'] ?? '';
      String username = 'Unknown';
      String profilePictureUrl = '';

      if (userId.isNotEmpty) {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final u = userDoc.data() ?? {};
          username          = u['username']          ?? username;
          profilePictureUrl = u['profilePictureUrl'] ?? '';
        }
      }

      /* ── CURATOR (if this is a curated order) ─────────────────────────────────────────────── */
      final curatorId = data['curatorId'];
      String curatorUsername = '';
      String curatorProfilePictureUrl = '';
      
      if (curatorId != null && (curatorId as String).isNotEmpty) {
        final curatorDoc =
            await FirebaseFirestore.instance.collection('users').doc(curatorId).get();
        if (curatorDoc.exists) {
          final c = curatorDoc.data() ?? {};
          curatorUsername = c['username'] ?? '';
          curatorProfilePictureUrl = c['profilePictureUrl'] ?? '';
        }
      }

      /* ── album ── */
      // Try both locations: direct albumId for curator orders, or details.albumId for regular orders
      final albumId = data['albumId'] ?? data['details']?['albumId'];
      if (albumId == null || (albumId as String).isEmpty) continue;

      final albumDoc =
          await FirebaseFirestore.instance.collection('albums').doc(albumId).get();
      if (!albumDoc.exists) continue;

      final album = Album.fromDocument(albumDoc);
      if (!isSupportedImageFormat(album.albumImageUrl)) continue;

      items.add(
        FeedItem(
          username: username,
          userId: userId,
          status: data['status'],
          album: album,
          profilePictureUrl: profilePictureUrl,
          curatorUsername: curatorUsername.isNotEmpty ? curatorUsername : null,
          curatorId: curatorId as String?,
          curatorProfilePictureUrl: curatorProfilePictureUrl.isNotEmpty ? curatorProfilePictureUrl : null,
        ),
      );
    }
    return items;
  }

  bool isSupportedImageFormat(String url) {
    final ext = Uri.tryParse(url)?.path.toLowerCase().split('.').last ?? '';
    return ext == 'jpg' || ext == 'jpeg' || ext == 'png';
  }

  Future<void> _addToWishlist(String albumId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    await _firestoreService.addToWishlist(
      userId: currentUser.uid,
      albumId: albumId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Album added to your wishlist')),
    );
  }

  /* ─────────────────────────── UI ─────────────────────────── */

  Widget _buildFeedItem(FeedItem item) {
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
                  // User info (same for both curated and regular orders)
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
              height: ResponsiveUtils.isMobile(context) ? 
                  MediaQuery.of(context).size.height * 0.32 : 
                  MediaQuery.of(context).size.height * 0.35,
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
                    children: [
                      Icon(Icons.error, 
                          size: ResponsiveUtils.isMobile(context) ? 80 : 100, 
                          color: Colors.red),
                      SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 6, tablet: 8, desktop: 8)),
                      Text('Failed to load image', 
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 16),
                          )),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 6, tablet: 8, desktop: 8)),

            /* ――― artist – album title ――― */
           Padding(
            padding: ResponsiveUtils.getResponsiveHorizontalPadding(context,
                mobile: 16, tablet: 20, desktop: 20),
            child: Column(
              children: [
                Text(
                  '${item.album.artist} – ${item.album.albumName}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.white70,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16, tablet: 18, desktop: 18),
                  ),
                ),
                // Always show curator attribution
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: item.isCurated && item.curatorUsername != null
                    ? GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PublicProfileScreen(userId: item.curatorId!),
                            ),
                          );
                        },
                        child: Text(
                          'curated by ${item.curatorUsername}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 16),
                            fontStyle: FontStyle.italic,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      )
                    : Text(
                        'curated by dissonant',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 14, tablet: 16, desktop: 16),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                ),
              ],
            ),
          ),

            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24, tablet: 30, desktop: 30)),

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
  // Use responsive screen calculations
  final screenWidth = MediaQuery.of(context).size.width;

  // Shrink spines on smaller screens with responsive calculations
  final isSmallScreen = ResponsiveUtils.isMobile(context);
  final spineHeight = isSmallScreen ? 32.0 : 45.0;
  final maxSpines = 4; // fewer spines for better fit
  final spineWidth = screenWidth * (isSmallScreen ? 0.8 : 0.85);

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


  /* ─────────────────────────── build ─────────────────────────── */

@override
Widget build(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  final topPadding = mediaQuery.padding.top;
  final bottomPadding = mediaQuery.padding.bottom;
  final totalSpinesHeight = maxSpines * 48.0;

  final feedHeight = mediaQuery.size.height - topPadding - bottomPadding - totalSpinesHeight;

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
                            itemBuilder: (c, i) => _buildFeedItem(_feedItems[i]),
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