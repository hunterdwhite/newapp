import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';
import '../services/firestore_service.dart';
import '../models/album.dart';
import '../models/feed_item.dart';
import 'feed_screen.dart';
import 'album_detail_screen.dart';
import '../main.dart'; // for MyHomePage.of(context)


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /* ─────────────────────────  NEWS / ANNOUNCEMENTS  ─────────────────────── */
  final PageController _newsController = PageController();
  Timer? _autoScrollTimer;
  List<Map<String, dynamic>> _newsItems = [];
  bool _newsLoading = true;
  int _currentPage = 0;
  bool _pageReady = false;



  /* ─────────────────────────  LATEST ALBUMS STRIP  ─────────────────────── */
  final FirestoreService _firestore = FirestoreService();
  final int _latestLimit = 10;
  List<FeedItem> _latestFeedItems = [];
  bool _latestLoading = true;

  /* ─────────────────────────  USERNAME  ─────────────────────── */
  String? _username;

  late VideoPlayerController _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    _newsController.addListener(() {
      final page = _newsController.page?.round() ?? 0;
      if (_currentPage != page) {
        setState(() {
          _currentPage = page;
        });
      }
    });
    super.initState();
    _loadAnnouncements();
    _fetchLatestAlbums();
    _startAutoScroll();
    _videoController = VideoPlayerController.asset('assets/littleguy.mp4')
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        setState(() {
          _videoInitialized = true;
          _videoController.play();
        });
      });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _newsController.dispose();
    super.dispose();
  }

  /* ==========  ANNOUNCEMENTS FLOW  ========== */
  Future<void> _loadAnnouncements() async {
  try {
    _newsItems = [];

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};

        // Welcome card if user has never ordered
        if (data['hasOrdered'] != true) {
          _newsItems.add({
            'title': 'Welcome to DISSONANT!',
            'subtitle': 'Everyone remembers their first order... \n Don\'t forget to make yours!',
            'imageUrl': '',
            'iconPath': 'assets/icon/firstordericon.png',
            'deeplink': '/order',
          });
        }

        // Free Order card
        if (data['freeOrder'] == true) {
          _newsItems.add({
            'title': 'You have a Free Order',
            'subtitle': 'Your next order is free! \n Redeem it now and discover new music!',
            'iconPath': 'assets/icon/nextorderfreeicon.png',
            'imageUrl': '',
            'deeplink': '/order/free',
          });
        }
      }
    }

    // Wishlist leaderboard card
    final leaderboardItems = await _fetchWishlistLeaderboardTop3();
    if (leaderboardItems.isNotEmpty) {
      _newsItems.add({
        'title': 'Most Wishlisted Albums',
        'subtitle': leaderboardItems.join(' • '),
        'imageUrl': '',
        'deeplink': '/wishlist/leaderboard',
      });
    }

    // Propaganda cards
    _newsItems.addAll([
      {
        'title': 'Get all your orders free!',
        'subtitle': 'You can place one order for the cheapest price, then treat our service like a library card! \n After each return your next order is free! \n And there\'s no limit!!',
        'imageUrl': '', // Upload this image
        'iconPath': 'assets/icon/libraryicon.png',
        'backgroundColor': Colors.deepOrange.shade700,
      },
      {
        'title': 'Find that hidden gem',
        'subtitle': 'Your favorite music is already out there, in a jewel case, buried in a crate at some dusty record store. \n Isn\'t that more exciting than a Spotify Playlist?',
        'imageUrl': '',
        'iconPath': 'assets/icon/hiddengemicon.png',
        'backgroundColor': Colors.blueGrey.shade700,
      },
      {
        'title': 'Own your music',
        'subtitle': 'In a throwaway culture it’s radical to share music in a way those corporations can\'t touch.',
        'imageUrl': '',
        'iconPath': 'assets/icon/radicalsharemusicicon.png',
        'backgroundColor': Colors.redAccent.shade700,
      },
      {
        'title': 'Make a donation',
        'subtitle': 'Have some CDs collecting dust? \n Email us at dissonant.helpdesk@gmail.com to make a donation! \n You may qualify for a free order!',
        'imageUrl': '',
        'iconPath': 'assets/icon/donate.png',
        'backgroundColor': Colors.redAccent.shade700,
      },
      {
        'title': 'Let’s Connect!',
        'subtitle': 'Follow us and stay in the loop.',
        'imageUrl': '',
        'type': 'social',
      },
    ]);

    setState(() {
      _newsLoading = false;
    });
    _checkIfPageReady();
  } catch (e) {
    debugPrint('Error loading announcements: $e');
    setState(() {
      _newsLoading = false;
    });
    _checkIfPageReady();
  }
}


  Future<List<String>> _fetchWishlistLeaderboardTop3() async {
  final albumCounts = <String, int>{};

  try {
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
    for (final userDoc in usersSnapshot.docs) {
      final wishlistSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userDoc.id)
          .collection('wishlist')
          .get();

      for (final wishlistItem in wishlistSnapshot.docs) {
        final albumId = wishlistItem['albumId'] ?? wishlistItem.id;
        if (albumId != null && albumId.isNotEmpty) {
          albumCounts[albumId] = (albumCounts[albumId] ?? 0) + 1;
        }
      }
    }

    // Sort by count
    final sortedAlbums = albumCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Fetch top 3 album names
    final topAlbumNames = <String>[];
    for (final entry in sortedAlbums.take(3)) {
      final albumDoc = await FirebaseFirestore.instance.collection('albums').doc(entry.key).get();
      if (albumDoc.exists) {
        final name = albumDoc.data()?['albumName'] ?? 'Unknown Album';
        topAlbumNames.add(name);
      }
    }

    return topAlbumNames;
  } catch (e) {
    debugPrint('Error fetching wishlist leaderboard: $e');
    return [];
  }
}



  Future<void> _addPersonalSlides() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = userDoc.data() ?? {};

      if (data['freeOrder'] == true) {
        _newsItems.insert(0, {
          'title': 'Free Order Available!',
          'subtitle': 'You have a free order. Place it now!',
          'imageUrl': '',
          'deeplink': '/order/free',
        });
      }
    } catch (e) {
      debugPrint('Error reading personal flags: $e');
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!_newsController.hasClients || _newsItems.length < 2) return;
      final next = (_newsController.page ?? 0).round() + 1;
      final target = next >= _newsItems.length ? 0 : next;
      _newsController.animateToPage(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  /* ==========  FETCH LATEST ALBUMS FLOW  ========== */
  Future<void> _fetchLatestAlbums() async {
    setState(() => _latestLoading = true);

    try {
      final qs = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', whereIn: ['kept', 'returnedConfirmed'])
          .orderBy('updatedAt', descending: true)
          .limit(_latestLimit)
          .get();

      final items = <FeedItem>[];
      for (final doc in qs.docs) {
        final data = doc.data();
        final albumId = data['details']?['albumId'] as String?;
        if (albumId == null || albumId.isEmpty) continue;

        final albumDoc =
            await FirebaseFirestore.instance.collection('albums').doc(albumId).get();
        if (!albumDoc.exists) continue;

        final album = Album.fromDocument(albumDoc);

        final userId = data['userId'] as String? ?? '';
        var username = 'Unknown';
        if (userId.isNotEmpty) {
          final p = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('public')
              .doc('profile')
              .get();
          username = (p.data() ?? {})['username'] ?? 'Unknown';
        }

        items.add(FeedItem(
          username: username,
          userId: userId,
          status: data['status'],
          album: album,
        ));
      }

      setState(() {
        _latestFeedItems = items;
        _latestLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading latest albums: $e');
      setState(() => _latestLoading = false);
    }
    _checkIfPageReady();
  }

Widget _buildLittleGuyWidget() {
  if (!_videoInitialized) {
    return const SizedBox(height: 100);
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Center(
      child: Container(
        width: 300,
        decoration: const BoxDecoration(
          color: Color(0xFFE0E0E0),
          border: Border(
            top: BorderSide(color: Color(0xFF5E5E5E), width: 2),     // dark top
            left: BorderSide(color: Color(0xFF5E5E5E), width: 2),    // dark left
            bottom: BorderSide(color: Colors.white, width: 2),       // light bottom
            right: BorderSide(color: Colors.white, width: 2),        // light right
          ),
        ),
        child: ClipRect(
          child: Align(
            alignment: Alignment.center,
            heightFactor: 0.7,
            child: SizedBox(
              height: 180,
              width: 300,
              child: AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}





  /* ==========  WIDGET BUILDERS  ========== */
Widget _buildNewsCarousel() {
  if (_newsLoading) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.30,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  final double cardHeight = MediaQuery.of(context).size.height * 0.30;

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: cardHeight,
        child: PageView.builder(
          controller: _newsController,
          itemCount: _newsItems.length,
          itemBuilder: (_, idx) {
            final item = _newsItems[idx];
            final hasImage = (item['imageUrl'] as String).isNotEmpty;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // TODO: deeplink
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              height: 36,
                              color: const Color(0xFFFFA12C),
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                item['title'] ?? '',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                  fontWeight: FontWeight.normal,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              child: Container(height: 3, color: Color(0xFFFFC278)),
                            ),
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              child: Container(width: 3, color: Color(0xFFFFC278)),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFCBCACB),
                                  border: Border(
                                    top: BorderSide(color: Colors.white, width: 2),
                                    left: BorderSide(color: Colors.white, width: 2),
                                    bottom: BorderSide(color: Color(0xFF5E5E5E), width: 2),
                                    right: BorderSide(color: Color(0xFF5E5E5E), width: 2),
                                  ),
                                ),
                                child: const Text(
                                  'X',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Container(height: 1, color: Colors.black),
                        Expanded(
                          child: Container(
                            color: const Color(0xFFE0E0E0),
                            width: double.infinity,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (item['iconPath'] != null && item['iconPath'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 24, right: 8),
                                    child: Image.asset(
                                      item['iconPath'],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    child: item['type'] == 'social'
                                        ? Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Text(
                                                'Connect with us on these platforms!',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: Colors.black,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  _buildSocialIcon('assets/icon/discord.png', 'https://discord.gg/Syr3HwunX3'),
                                                  const SizedBox(width: 16),
                                                  _buildSocialIcon('assets/icon/tiktok.png', 'https://tiktok.com/@dissonant.tt'),
                                                  const SizedBox(width: 16),
                                                  _buildSocialIcon('assets/icon/instagram.png', 'https://instagram.com/dissonant.ig'),
                                                ],
                                              ),
                                            ],
                                          )
                                        : Text(
                                            item['subtitle'] ?? '',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              color: Colors.black87,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_newsItems.length, (index) {
          final bool isActive = _currentPage == index;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFFB0C4DE) : Colors.grey,
              borderRadius: BorderRadius.zero,
            ),
          );
        }),
      ),
    ],
  );
}


Widget _buildSocialIcon(String assetPath, String url) {
  return GestureDetector(
    onTap: () async {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    },
    child: Image.asset(
      assetPath,
      width: 40,
      height: 40,
      fit: BoxFit.contain,
    ),
  );
}


Widget _buildLatestAlbumsStrip() {
  if (_latestLoading) {
    return const SizedBox(
      height: 150,
      child: Center(child: CircularProgressIndicator()),
    );
  }
  if (_latestFeedItems.isEmpty) {
    return const SizedBox(
      height: 150,
      child: Center(child: Text('No albums yet')),
    );
  }

  final latestAlbums = _latestFeedItems.take(3).toList();

  return GestureDetector(
    onTap: () {
      MyHomePage.of(context)?.pushInHomeTab(
        MaterialPageRoute(builder: (_) => FeedScreen()),
      );
    },
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient bar with title and arrow
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
                  'Latest Albums',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: latestAlbums.map((feedItem) {
              final album = feedItem.album;
              return Container(
                width: 98,
                height: 98,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  border: Border.all(color: Colors.black, width: 0.5),
                ),
                child: Image.network(
                  album.albumImageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.error),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

void _checkIfPageReady() {
  if (!_newsLoading && !_latestLoading) {
    setState(() {
      _pageReady = true;
    });
  }
}




  /* ─────────────────────────  MAIN BUILD  ───────────────────────── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundWidget(
        child: SafeArea(
          child: _pageReady
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const SizedBox(height: 36),
                      Center(
                        child: SizedBox(
                          width: 600,
                          child: Column(
                            children: [
                              _buildNewsCarousel(),
                              const SizedBox(height: 12),
                              _buildLatestAlbumsStrip(),
                              SizedBox(height: 12),
                              _buildLittleGuyWidget(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(), // show spinner until ready
                ),
        ),
      ),
    );
  }
}
