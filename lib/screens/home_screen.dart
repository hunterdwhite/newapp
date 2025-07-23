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
import '../models/album_model.dart';
import '../models/feed_item_model.dart';
import 'feed_screen.dart';
import 'album_detail_screen.dart';
import 'earn_credits_screen.dart';
import '../main.dart'; // for MyHomePage.of(context)

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();

  // Helper method for when a free order is used (can be called from order screen)
  static Future<void> useFreeOrder(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final int currentFreeOrders = data['freeOrdersAvailable'] ?? 0;
        
        if (currentFreeOrders > 0) {
          final int newFreeOrders = currentFreeOrders - 1;
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'freeOrdersAvailable': newFreeOrders,
            'freeOrder': newFreeOrders > 0, // Only true if still have free orders left
          });
        }
      }
    } catch (e) {
      debugPrint('Error using free order: $e');
    }
  }

  // Helper method to add credits (can be called when user completes actions)
  static Future<void> addFreeOrderCredits(String userId, int creditsToAdd) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final int currentCredits = data['freeOrderCredits'] ?? 0;
        final int currentFreeOrders = data['freeOrdersAvailable'] ?? 0;
        
        final int newTotalCredits = currentCredits + creditsToAdd;
        
        if (newTotalCredits >= 5) {
          // Convert credits to free orders
          final int newFreeOrdersEarned = newTotalCredits ~/ 5;
          final int remainingCredits = newTotalCredits % 5;
          final int totalFreeOrders = currentFreeOrders + newFreeOrdersEarned;
          
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'freeOrderCredits': remainingCredits,
            'freeOrdersAvailable': totalFreeOrders,
            'freeOrder': totalFreeOrders > 0,
          });
        } else {
          // Just add the credits
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .update({
            'freeOrderCredits': newTotalCredits,
          });
        }
      }
    } catch (e) {
      debugPrint('Error adding free order credits: $e');
    }
  }
}

class _HomeScreenState extends State<HomeScreen> 
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  
  @override
  bool get wantKeepAlive => true;

  /* ─────────────────────────  NEWS / ANNOUNCEMENTS  ─────────────────────── */
  late final PageController _newsController;
  Timer? _autoScrollTimer;
  List<Map<String, dynamic>> _newsItems = [];
  bool _newsLoading = true;
  int _currentPage = 0;
  bool _pageReady = false;

  /* ─────────────────────────  LATEST ALBUMS STRIP  ─────────────────────── */
  late final FirestoreService _firestore;
  static const int _latestLimit = 10;
  List<FeedItem> _latestFeedItems = [];
  bool _latestLoading = true;

  /* ─────────────────────────  USERNAME  ─────────────────────── */
  String? _username;

  /* ─────────────────────────  FREE ORDER BAR  ─────────────────────── */
  int _freeOrderCredits = 0;
  int _freeOrdersAvailable = 0;
  bool _creditsLoading = true;

  late VideoPlayerController _videoController;
  bool _videoInitialized = false;

  // Performance optimization: Cache user data
  static final Map<String, dynamic> _userDataCache = {};
  static int _lastUserDataFetch = 0;
  static const int _userDataCacheDuration = 30000; // 30 seconds

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _newsController = PageController();
    _firestore = FirestoreService();
    
    _newsController.addListener(_onPageChanged);
    
    // Load data with proper error handling
    _initializeData();
    _initializeVideo();
  }

  void _onPageChanged() {
    if (_newsController.hasClients) {
      final page = _newsController.page?.round() ?? 0;
      if (_currentPage != page && mounted) {
        setState(() {
          _currentPage = page;
        });
      }
    }
  }

  Future<void> _initializeData() async {
    // Use Future.wait for parallel execution
    await Future.wait([
      _loadAnnouncements(),
      _fetchLatestAlbums(),
      _fetchFreeOrderCredits(),
    ]).then((_) {
      if (mounted) {
        _startAutoScroll();
      }
    }).catchError((error) {
      debugPrint('Error initializing data: $error');
    });
  }

  void _initializeVideo() {
    _videoController = VideoPlayerController.asset(
      'assets/littleguy.mp4',
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _videoInitialized = true;
          });
          _videoController.play();
        }
      }).catchError((error) {
        debugPrint('Video initialization error: $error');
      });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _newsController.removeListener(_onPageChanged);
    _newsController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  /* ==========  ANNOUNCEMENTS FLOW (Optimized) ========== */
  Future<void> _loadAnnouncements() async {
    if (!mounted) return;
    
    try {
      _newsItems = [];

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Check cache first
        final now = DateTime.now().millisecondsSinceEpoch;
        if (_userDataCache.containsKey(user.uid) && 
            (now - _lastUserDataFetch) < _userDataCacheDuration) {
          _processUserData(_userDataCache[user.uid]);
        } else {
          // Fetch fresh data
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.cache));

          if (userDoc.exists) {
            final data = userDoc.data() ?? {};
            _userDataCache[user.uid] = data;
            _lastUserDataFetch = now;
            _processUserData(data);
          }
        }
      }

      _addPropagandaCards();
      
      if (mounted) {
        setState(() {
          _newsLoading = false;
        });
        _checkIfPageReady();
      }
    } catch (e) {
      debugPrint('Error loading announcements: $e');
      if (mounted) {
        setState(() {
          _newsLoading = false;
        });
        _checkIfPageReady();
      }
    }
  }

  void _processUserData(Map<String, dynamic> data) {
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

  void _addPropagandaCards() {
    // Static propaganda cards - these could be cached as const
    _newsItems.addAll(const [
      {
        'title': 'Welcome to DISSONANT',
        'subtitle': 'Order an album handpicked by our curators. Don\'t like it? Send it back with the included return label and your next order is free!',
        'imageUrl': '',
        'iconPath': 'assets/icon/basicintroicon.png',
      },
      {
        'title': 'Get all your orders free!',
        'subtitle': 'You can place one order for the cheapest price, then treat our service like a library card! \n After each return your next order is free! \n And there\'s no limit!!',
        'imageUrl': '',
        'iconPath': 'assets/icon/libraryicon.png',
      },
      {
        'title': 'Find that hidden gem',
        'subtitle': 'Your favorite music is already out there, in a jewel case, buried in a crate at some dusty record store. \n Isn\'t that more exciting than a Spotify Playlist?',
        'imageUrl': '',
        'iconPath': 'assets/icon/hiddengemicon.png',
      },
      {
        'title': 'Own your music',
        'subtitle': 'In a throwaway culture it\'s radical to share music in a way those corporations can\'t touch.',
        'imageUrl': '',
        'iconPath': 'assets/icon/radicalsharemusicicon.png',
      },
      {
        'title': 'Make a donation',
        'subtitle': 'Have some CDs collecting dust? \n Email us at dissonant.helpdesk@gmail.com to make a donation! \n You may qualify for a free order!',
        'imageUrl': '',
        'iconPath': 'assets/icon/donate.png',
      },
      {
        'title': 'Let\'s Connect!',
        'subtitle': 'Follow us and stay in the loop.',
        'imageUrl': '',
        'type': 'social',
      },
    ]);
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel(); // Cancel existing timer
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted || !_newsController.hasClients || _newsItems.length < 2) {
        timer.cancel();
        return;
      }
      final next = (_newsController.page ?? 0).round() + 1;
      final target = next >= _newsItems.length ? 0 : next;
      _newsController.animateToPage(
        target,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  // Optimized album fetching with better error handling
  Future<void> _fetchLatestAlbums() async {
    if (!mounted) return;
    setState(() => _latestLoading = true);

    try {
      // Use single query with proper indexing
      final qs = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', whereIn: ['kept', 'returnedConfirmed'])
          .orderBy('updatedAt', descending: true)
          .limit(_latestLimit)
          .get();

      final List<FeedItem> items = [];
      final Set<String> processedAlbums = {}; // Avoid duplicates

      for (final doc in qs.docs) {
        if (!mounted) break; // Check if widget is still mounted
        
        final data = doc.data();
        final albumId = data['details']?['albumId'] as String?;
        
        if (albumId == null || albumId.isEmpty || processedAlbums.contains(albumId)) {
          continue;
        }
        
        processedAlbums.add(albumId);

        // album
        final albumDoc =
            await FirebaseFirestore.instance.collection('albums').doc(albumId).get();
        if (!albumDoc.exists) continue;
        final album = Album.fromDocument(albumDoc);

        // user
        final userId = data['userId'] as String? ?? '';
        String username = 'Unknown';
        String avatar   = '';

        if (userId.isNotEmpty) {
          final userDoc =
              await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final u = userDoc.data() ?? {};
            username = u['username'] ?? username;
            avatar   = u['profilePictureUrl'] ?? '';
          }
        }

        items.add(
          FeedItem(
            username: username,
            userId: userId,
            status: data['status'],
            album: album,
            profilePictureUrl: avatar,          // never null
          ),
        );
      }

      if (mounted) {
        setState(() {
          _latestFeedItems = items;
          _latestLoading   = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading latest albums: $e');
      if (mounted) {
        setState(() => _latestLoading = false);
      }
    }

    _checkIfPageReady();
  }

  Future<void> _fetchFreeOrderCredits() async {
  if (!mounted) return;
  setState(() => _creditsLoading = true);

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        int credits = data['freeOrderCredits'] ?? 0;
        
        // Check if we need to convert credits to free orders
        if (credits >= 5) {
          final int newFreeOrders = credits ~/ 5; // How many complete sets of 5
          final int remainingCredits = credits % 5; // Leftover credits
          
          // Update Firestore with the new values
          await _convertCreditsToFreeOrders(user.uid, newFreeOrders, remainingCredits, data);
          
          // Update local state
          if (!mounted) return;
          setState(() {
            _freeOrderCredits = remainingCredits;
            _freeOrdersAvailable = (data['freeOrdersAvailable'] ?? 0) + newFreeOrders;
            _creditsLoading = false;
          });
        } else {
          if (!mounted) return;
          setState(() {
            _freeOrderCredits = credits;
            _freeOrdersAvailable = data['freeOrdersAvailable'] ?? 0;
            _creditsLoading = false;
          });
        }
      } else {
        if (!mounted) return;
        setState(() {
          _freeOrderCredits = 0;
          _freeOrdersAvailable = 0;
          _creditsLoading = false;
        });
      }
    } else {
      if (!mounted) return;
      setState(() {
        _freeOrderCredits = 0;
        _freeOrdersAvailable = 0;
        _creditsLoading = false;
      });
    }
  } catch (e) {
    debugPrint('Error loading free order credits: $e');
    if (!mounted) return;
    setState(() {
      _freeOrderCredits = 0;
      _freeOrdersAvailable = 0;
      _creditsLoading = false;
    });
  }

  _checkIfPageReady();
}

Future<void> _convertCreditsToFreeOrders(String userId, int newFreeOrders, int remainingCredits, Map<String, dynamic> currentData) async {
  try {
    final int currentFreeOrders = currentData['freeOrdersAvailable'] ?? 0;
    final int totalFreeOrders = currentFreeOrders + newFreeOrders;
    
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'freeOrderCredits': remainingCredits,
      'freeOrdersAvailable': totalFreeOrders,
      'freeOrder': totalFreeOrders > 0, // Set to true if any free orders available
    });
  } catch (e) {
    debugPrint('Error converting credits to free orders: $e');
  }
}



Widget _buildFreeOrderBar() {
  if (_creditsLoading) {
    return const SizedBox(
      height: 150,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  final int creditsNeeded = 5 - _freeOrderCredits;
  final int filledPartitions = _freeOrderCredits;

  return Padding(
    padding: const EdgeInsets.all(16),
    child: GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EarnCreditsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Available free orders (if any)
            if (_freeOrdersAvailable > 0) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA500),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  _freeOrdersAvailable == 1 
                      ? 'You have 1 free order available!'
                      : 'You have $_freeOrdersAvailable free orders available!',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Progress toward next free order
            Text(
              '$creditsNeeded credits until next free order',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Progress bar with 5 partitions
            Container(
              height: 24,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Row(
                children: List.generate(5, (index) {
                  final bool isFilled = index < filledPartitions;
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isFilled ? const Color(0xFFFFA500) : Colors.transparent,
                        border: index < 4 
                            ? const Border(right: BorderSide(color: Colors.white, width: 1))
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Text below the bar
            const Text(
              'Click to earn free credits',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

 // Widget _buildLittleGuyWidget() {
 //   if (!_videoInitialized) return const SizedBox.shrink();

 //   return Padding(
 //     padding: const EdgeInsets.all(16),
 //     child: _buildCascadingWindow(
 //       child: Container(
 //         color: Colors.white,
 //         padding: const EdgeInsets.all(8),
 //         child: AspectRatio(
 //           aspectRatio: _videoController.value.aspectRatio,
 //           child: VideoPlayer(_videoController),
 //         ),
 //       ),
 //     ),
 //   );
 // }

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
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
                                child: Container(
                                    height: 3, color: Color(0xFFFFC278)),
                              ),
                              Positioned(
                                top: 0,
                                bottom: 0,
                                left: 0,
                                child: Container(
                                    width: 3, color: Color(0xFFFFC278)),
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
                                      top: BorderSide(
                                          color: Colors.white, width: 2),
                                      left: BorderSide(
                                          color: Colors.white, width: 2),
                                      bottom: BorderSide(
                                          color: Color(0xFF5E5E5E), width: 2),
                                      right: BorderSide(
                                          color: Color(0xFF5E5E5E), width: 2),
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
                                  if (item['iconPath'] != null &&
                                      item['iconPath'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          left: 24, right: 8),
                                      child: Image.asset(
                                        item['iconPath'],
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12, horizontal: 16),
                                      child: item['type'] == 'social'
                                          ? Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
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
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    _buildSocialIcon(
                                                        'assets/icon/discord.png',
                                                        'https://discord.gg/Syr3HwunX3'),
                                                    const SizedBox(width: 16),
                                                    _buildSocialIcon(
                                                        'assets/icon/tiktok.png',
                                                        'https://tiktok.com/@dissonant.tt'),
                                                    const SizedBox(width: 16),
                                                    _buildSocialIcon(
                                                        'assets/icon/instagram.png',
                                                        'https://instagram.com/dissonant.ig'),
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

Widget _buildCascadingWindow({required Widget child}) {
  return Stack(
    children: [
      Positioned(
        left: 8,
        top: 8,
        child: _singleWindow(color: Colors.grey.shade800, child: const SizedBox.shrink()),
      ),
      Positioned(
        left: 4,
        top: 4,
        child: _singleWindow(color: Colors.grey.shade700, child: const SizedBox.shrink()),
      ),
      _singleWindow(
        color: const Color(0xFF4A626D), // base color: grey-blue
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  height: 24,
                  color: const Color(0xFF4A626D),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: const [
                      Expanded(
                        child: Text(
                          'UnderConstruction.exe',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                      Icon(Icons.close, color: Colors.white, size: 16),
                    ],
                  ),
                ),
                // Highlight overlay on top and left
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.11),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 1,
                    color: Colors.white.withOpacity(0.11),
                  ),
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    ],
  );
}





Widget _singleWindow({required Color color, required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Colors.black),
    ),
    child: child,
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
    child: LayoutBuilder(
      builder: (context, constraints) {
        // Use available width to calculate album size
        final double totalSpacing = 2 * 16 + 2 * 12; // outer + inner padding
        final double albumSize = (constraints.maxWidth - totalSpacing) / 3;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + arrow
              Row(
                children: [
                  const Text(
                    'Latest Albums',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Image.asset(
                    'assets/orangearrow.png',
                    width: 12,
                    height: 12,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: latestAlbums.map((feedItem) {
                  final album = feedItem.album;
                  return Container(
                    width: albumSize,
                    height: albumSize,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 0.5),
                    ),
                    child: Image.network(
                      album.albumImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.error),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    ),
  );
}






  void _checkIfPageReady() {
    if (!mounted) return;
    if (!_newsLoading && !_latestLoading && !_creditsLoading) {
      setState(() {
        _pageReady = true;
      });
    }
  }

  /* ─────────────────────────  MAIN BUILD  ───────────────────────── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GrainyBackgroundWidget(
        child: SafeArea(
          child: _pageReady
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: SizedBox(
                          width: 600,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(height: 24),
                                _buildNewsCarousel(),
                                _buildLatestAlbumsStrip(),
                                _buildFreeOrderBar(),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                )
              : const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}
