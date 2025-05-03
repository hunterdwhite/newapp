import 'package:flutter/material.dart';
import 'package:dissonantapp2/widgets/grainy_background_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/firestore_service.dart';
import '../widgets/retro_button_widget.dart';
import '../models/album.dart';
import '../models/feed_item.dart';
import 'album_detail_screen.dart';
import 'public_profile_screen.dart'; // <--- Import your personal profile page

class FeedScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<FeedScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  // Our paginated feed items
  List<FeedItem> _feedItems = [];

  // Loading states
  bool _isLoading = true;         // initial load
  bool _isFetchingMore = false;   // when loading the next chunk
  bool _hasMoreData = true;       // whether more data might be available

  // Firestore pagination helpers
  DocumentSnapshot? _lastDocument;
  final int _pageSize = 10;       // how many docs to fetch in each chunk

  // PageView controller and state
  PageController _pageController = PageController();
  int _currentIndex = 0;

  // Spine settings for the “stacked” UI
  final double spineHeight = 45.0;
  final int maxSpines = 3;

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

  void _onPageChanged() {
    if (!mounted) return;
    int newIndex = _pageController.page!.round();

    if (newIndex != _currentIndex && newIndex < _feedItems.length) {
      setState(() {
        _currentIndex = newIndex;
      });

      // If user is near the bottom (last or second-to-last item), try fetching more
      if (newIndex >= _feedItems.length - 2 && _hasMoreData) {
        _fetchMoreFeedItems();
      }
    }
  }

  /// Fetch the first chunk of documents
  Future<void> _fetchInitialFeedItems() async {
    setState(() {
      _isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('orders')
          .where('status', whereIn: ['kept', 'returnedConfirmed'])
          .orderBy('updatedAt', descending: true)
          .limit(_pageSize);

      QuerySnapshot ordersSnapshot = await query.get();
      if (ordersSnapshot.docs.isNotEmpty) {
        _lastDocument = ordersSnapshot.docs.last;
      }

      // Convert documents into feed items
      List<FeedItem> newFeedItems = await _processOrderDocs(ordersSnapshot.docs);

      if (mounted) {
        setState(() {
          _feedItems = newFeedItems;
          _isLoading = false;
          // If we got fewer than _pageSize docs, we won't have more to load
          _hasMoreData = (ordersSnapshot.docs.length == _pageSize);
        });

        // Optionally prefetch the first image
        if (_feedItems.isNotEmpty) {
          precacheImage(
            NetworkImage(_feedItems[0].album.albumImageUrl),
            context,
          ).catchError((error) {
            print('Error precaching first image: $error');
          });
        }
      }
    } catch (e) {
      print('Error fetching feed items: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading feed items: $e')),
        );
      }
    }
  }

  /// Fetch the next chunk of documents
  Future<void> _fetchMoreFeedItems() async {
    // If we're already fetching or there's nothing left, do nothing
    if (_isFetchingMore || !_hasMoreData) return;

    setState(() {
      _isFetchingMore = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('orders')
          .where('status', whereIn: ['kept', 'returnedConfirmed'])
          .orderBy('updatedAt', descending: true)
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      QuerySnapshot ordersSnapshot = await query.get();
      if (ordersSnapshot.docs.isNotEmpty) {
        _lastDocument = ordersSnapshot.docs.last;
      }

      List<FeedItem> moreFeedItems = await _processOrderDocs(ordersSnapshot.docs);

      if (mounted) {
        setState(() {
          _feedItems.addAll(moreFeedItems);
          _isFetchingMore = false;
          _hasMoreData = (ordersSnapshot.docs.length == _pageSize);
        });
      }
    } catch (e) {
      print('Error fetching more feed items: $e');
      if (mounted) {
        setState(() {
          _isFetchingMore = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more feed items: $e')),
        );
      }
    }
  }

  /// Process each order doc into a FeedItem by fetching user and album docs
  Future<List<FeedItem>> _processOrderDocs(List<DocumentSnapshot> docs) async {
    List<FeedItem> feedItems = [];

    for (var doc in docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

      // Fetch user info
      String userId = data['userId'] ?? '';
      String username = 'Unknown User';

      if (userId.isNotEmpty) {
        DocumentSnapshot publicProfileDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('public')
            .doc('profile')
            .get();

        if (publicProfileDoc.exists) {
          Map<String, dynamic>? publicData =
              publicProfileDoc.data() as Map<String, dynamic>?;
          if (publicData != null) {
            username = publicData['username'] ?? 'Unknown User';
          }
        }
      }

      // Fetch album info
      String? albumId = data['details']?['albumId'];
      if (albumId == null || albumId.isEmpty) {
        // skip if no album ID
        continue;
      }

      DocumentSnapshot albumDoc = await FirebaseFirestore.instance
          .collection('albums')
          .doc(albumId)
          .get();

      if (!albumDoc.exists) {
        print('Album with ID $albumId does not exist.');
        continue;
      }

      Album album = Album.fromDocument(albumDoc);

      // Log the album image URL
      print('Loading image URL: ${album.albumImageUrl}');

      // Validate URL format
      if (!isSupportedImageFormat(album.albumImageUrl)) {
        print('Unsupported image format for album ${album.albumName}: '
            '${album.albumImageUrl}');
        continue; // skip if not a supported image
      }

      // IMPORTANT: Provide userId to the FeedItem
      FeedItem feedItem = FeedItem(
        username: username,
        userId: userId, // <--- store the userId
        status: data['status'],
        album: album,
      );
      feedItems.add(feedItem);
    }

    return feedItems;
  }

  /// Check if a given image URL is a common format (jpg/png)
  bool isSupportedImageFormat(String imageUrl) {
    try {
      Uri uri = Uri.parse(imageUrl);
      String path = uri.path.toLowerCase();
      String extension = path.split('.').last;
      return (extension == 'jpg' || extension == 'jpeg' || extension == 'png');
    } catch (e) {
      print('Error parsing image URL: $imageUrl, error: $e');
      return false;
    }
  }

  /// Add album to wishlist
  Future<void> _addToWishlist(
    String albumId,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _firestoreService.addToWishlist(
        userId: currentUser.uid,
        albumId: albumId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Album added to your wishlist')),
        );
      }
    }
  }

  /// Build each visible feed item
  Widget _buildFeedItem(FeedItem item) {
    String actionText = item.status == 'kept' ? 'kept' : 'returned';

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: 40.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Username & action & album name
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Made the username clickable => personal profile
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PublicProfileScreen(
                                userId: item.userId, // <-- The user ID from your feed
                              ),
                            ),
                          );
                        },
                          child: Text(
                            item.username,
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                        SizedBox(height: 4.0),
                        Text(
                          actionText,
                          style: TextStyle(
                            fontSize: 16.0,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.0),
                  Expanded(
                    flex: 1,
                    child: Text(
                      item.album.albumName,
                      style: TextStyle(
                        fontSize: 16.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16.0),

            // Album image with navigation
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.35,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AlbumDetailsScreen(
                        album: item.album,
                      ),
                    ),
                  );
                },
                child: (item.album.albumImageUrl.isNotEmpty &&
                        isSupportedImageFormat(item.album.albumImageUrl))
                    ? Image.network(
                        item.album.albumImageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Center(child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image '
                              'from ${item.album.albumImageUrl}: $error');
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error, size: 100, color: Colors.red),
                              SizedBox(height: 8),
                              Text(
                                'Failed to load image.',
                                style: TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        },
                      )
                    : Icon(
                        Icons.album,
                        size: 120,
                      ),
              ),
            ),

            SizedBox(height: 30.0),

            // Add to Wishlist button
            RetroButton(
              text: 'Add to Wishlist',
              onPressed: () {
                _addToWishlist(
                  item.album.albumId,
                );
              },
              color: Colors.white,
              fixedHeight: true,
            ),
          ],
        ),
      ),
    );
  }

  /// Animate the active/nearby feed items in the vertical PageView
  Widget _buildAnimatedFeedItem(FeedItem item, int index) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double opacity = 1.0;
        if (_pageController.position.haveDimensions) {
          double page =
              _pageController.page ?? _pageController.initialPage.toDouble();
          double difference = (index - page).abs();
          // Simple fade-out effect as the item moves away from center
          opacity = (1 - difference).clamp(0.0, 1.0);
        }
        return Opacity(
          opacity: opacity,
          child: _buildFeedItem(item),
        );
      },
    );
  }

  /// Build the “stack” of spines at the bottom
  Widget _buildSpines(double totalSpinesHeight) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SizedBox(
        height: totalSpinesHeight,
        child: AnimatedBuilder(
          animation: _pageController,
          builder: (context, child) {
            List<Widget> spineWidgets = [];

            double page =
                _pageController.hasClients && _pageController.page != null
                    ? _pageController.page!
                    : _currentIndex.toDouble();

            for (int i = 0; i < maxSpines; i++) {
              int spineIndex = _currentIndex + i + 1;
              if (spineIndex < _feedItems.length) {
                double offsetFromCurrent = page - _currentIndex;
                double bottomOffset = (maxSpines - i - 1) * spineHeight +
                    offsetFromCurrent * spineHeight;
                double scale = (1.0 - i * 0.05 - offsetFromCurrent * 0.02)
                    .clamp(0.0, 1.0);
                double opacity = (1.0 - i * 0.3 - offsetFromCurrent * 0.1)
                    .clamp(0.0, 1.0);

                Widget spine = Positioned(
                  bottom: bottomOffset,
                  left: 0,
                  right: 0,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.bottomCenter,
                    child: Opacity(
                      opacity: opacity,
                      child: _buildSpine(_feedItems[spineIndex]),
                    ),
                  ),
                );

                spineWidgets.add(spine);
              }
            }

            return Stack(
              clipBehavior: Clip.none,
              children: spineWidgets,
            );
          },
        ),
      ),
    );
  }

  /// Build an individual spine “bar” representing an upcoming album
  Widget _buildSpine(FeedItem item) {
    String albumName = item.album.albumName;
    if (albumName.length > 26) {
      albumName = albumName.substring(0, 23) + '...';
    }

    return Container(
      height: spineHeight,
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/spineasset.png',
            ),
          ),
          Positioned(
            left: 60,
            top: 0,
            bottom: 0,
            right: 10,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Text(
                albumName,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double totalSpinesHeight = MediaQuery.of(context).size.height * 0.15;

    return Scaffold(
      body: BackgroundWidget(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Stack(
                  children: [
                    // Bottom stacked spines
                    _buildSpines(totalSpinesHeight),

                    // The PageView itself
                    Padding(
                      padding: EdgeInsets.only(bottom: totalSpinesHeight),
                      child: PageView.builder(
                        controller: _pageController,
                        scrollDirection: Axis.vertical,
                        itemCount: _feedItems.length,
                        itemBuilder: (context, index) {
                          final item = _feedItems[index];
                          return _buildAnimatedFeedItem(item, index);
                        },
                      ),
                    ),

                    // “My Feed” title
                    Positioned(
                      top: 5.0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'My Feed',
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    // If desired, you could add a loading indicator at the bottom
                    if (_isFetchingMore)
                      Positioned(
                        bottom: totalSpinesHeight + 20,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
