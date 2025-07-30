import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../models/album_model.dart';
import '../services/discogs_service.dart';
import 'album_detail_screen.dart';
import 'link_discogs_screen.dart';

class MyMusicLibraryScreen extends StatefulWidget {
  final String userId; // Pass in any user’s ID
  const MyMusicLibraryScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _MyMusicLibraryScreenState createState() => _MyMusicLibraryScreenState();
}

class _MyMusicLibraryScreenState extends State<MyMusicLibraryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _musicItems = [];
  String? _filterStatus;

  // Discogs integration
  bool _discogsLinked = false;
  String? _discogsUsername;
  String? _discogsAccessToken;
  String? _discogsAccessSecret;
  List<Map<String, String>> _discogsCollection = [];
  bool _isLoadingDiscogs = false;

  final DiscogsService _discogsService = DiscogsService();

  bool get _isOwner {
    final currentUser = FirebaseAuth.instance.currentUser;
    return (currentUser != null && currentUser.uid == widget.userId);
  }

  @override
  void initState() {
    super.initState();
    _fetchMusicHistory();
    _loadDiscogsTokens();
  }

  Future<void> _fetchMusicHistory() async {
    print('MyMusicLibraryScreen loading for userId = ${widget.userId}');
    try {
      // If userId is empty, user never passed a valid ID. Show a message so you can debug.
      if (widget.userId.isEmpty) {
        print('ERROR: No userId provided to MyMusicLibraryScreen!');
        setState(() {
          _isLoading = false;
          _musicItems = []; // or show an error
        });
        return;
      }

      // Build query
      Query ordersQuery = FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: widget.userId);

      // If no filter, show kept & returnedConfirmed
      if (_filterStatus == null) {
        ordersQuery = ordersQuery.where(
          'status',
          whereIn: ['kept', 'returnedConfirmed'],
        );
      } else {
        ordersQuery = ordersQuery.where('status', isEqualTo: _filterStatus);
      }

      final ordersSnapshot = await ordersQuery.get();
      print(
        'Fetched ${ordersSnapshot.docs.length} order docs for userId ${widget.userId}',
      );

      // Collect albumIds
      final albumIds = <String>[];
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final albumId = data['albumId'] ?? data['details']?['albumId'];
        if (albumId != null) albumIds.add(albumId);
      }
      final uniqueIds = albumIds.toSet();
      final musicItems = <Map<String, dynamic>>[];

      // Fetch album docs
      for (final aId in uniqueIds) {
        final albumDoc = await FirebaseFirestore.instance
            .collection('albums')
            .doc(aId)
            .get();
        if (albumDoc.exists) {
          final aData = albumDoc.data() as Map<String, dynamic>;
          musicItems.add({
            'albumId': aId,
            'albumName': aData['albumName'] ?? 'Unknown Album',
            'artist': aData['artist'] ?? 'Unknown Artist',
            'releaseYear': aData['releaseYear']?.toString() ?? 'Unknown Year',
            'albumImageUrl': aData['coverUrl'] ?? '',
          });
        }
      }

      setState(() {
        _musicItems = musicItems;
        _isLoading = false;
      });
      print(
        'MyMusicLibraryScreen => found ${_musicItems.length} albums for userId = ${widget.userId}',
      );
    } catch (e) {
      print('Error fetching library for userId=${widget.userId}: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.clear),
            title: const Text('Clear Filter'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _filterStatus = null;
                _isLoading = true;
              });
              _fetchMusicHistory();
            },
          ),
          ListTile(
            leading: const Icon(Icons.save),
            title: const Text('Kept'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _filterStatus = 'kept';
                _isLoading = true;
              });
              _fetchMusicHistory();
            },
          ),
          ListTile(
            leading: const Icon(Icons.undo),
            title: const Text('Returned'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() {
                _filterStatus = 'returnedConfirmed';
                _isLoading = true;
              });
              _fetchMusicHistory();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadDiscogsTokens() async {
    try {
      final authData = await _discogsService.loadAuthData(widget.userId);
      if (authData == null) return;

      _discogsLinked = true;
      _discogsAccessToken = authData['accessToken'];
      _discogsAccessSecret = authData['accessSecret'];
      _discogsUsername = authData['username'];

      _fetchDiscogsCollection();
    } catch (e) {
      print('Error loading discogs tokens: $e');
    }
  }

  Future<void> _fetchDiscogsCollection() async {
    if (!_discogsLinked ||
        _discogsAccessToken == null ||
        _discogsAccessSecret == null ||
        _discogsUsername == null) return;

    setState(() => _isLoadingDiscogs = true);

    try {
      final items = await _discogsService.getCollection(
        _discogsUsername!,
        _discogsAccessToken!,
        _discogsAccessSecret!,
      );
      setState(() => _discogsCollection = items);
    } catch (e) {
      print('Error fetching Discogs collection: $e');
    } finally {
      setState(() => _isLoadingDiscogs = false);
    }
  }

  Widget _buildLocalLibraryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_musicItems.isEmpty) {
      return const Center(child: Text('No albums found.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 0.8,
      ),
      itemCount: _musicItems.length,
      itemBuilder: (context, index) {
        final item = _musicItems[index];
        final coverUrl = item['albumImageUrl'] as String;
        return GestureDetector(
          onTap: () {
            final album = Album(
              albumId: item['albumId'],
              albumName: item['albumName'],
              artist: item['artist'],
              releaseYear: item['releaseYear'],
              albumImageUrl: coverUrl,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AlbumDetailScreen(album: album),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: coverUrl.isNotEmpty
                      ? Image.network(
                          coverUrl,
                          fit: BoxFit.contain,
                        )
                      : const Icon(Icons.album, size: 50),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item['albumName'],
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item['artist'],
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscogsCollectionTab() {
    if (!_discogsLinked) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.link_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Link your Discogs account to view your collection',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
                          if (_isOwner)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LinkDiscogsScreen()),
                    ).then((_) {
                      // Refresh tokens after returning from link screen
                      _loadDiscogsTokens();
                    });
                  },
                  child: const Text('Link Discogs Account'),
                ),
          ],
        ),
      );
    }
    if (_isLoadingDiscogs) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_discogsCollection.isEmpty) {
      return const Center(child: Text('No albums in Discogs collection.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _discogsCollection.length,
      itemBuilder: (context, index) {
        final item = _discogsCollection[index];
        return GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(item['album'] ?? 'Unknown'),
                content: Text('By ${item['artist'] ?? 'Unknown'}'),
              ),
            );
          },
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item['image'] ?? '',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item['album'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                item['artist'] ?? '',
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isOwner ? 'My Music Library' : 'Music Library';

    // Always use 2 tabs to prevent DefaultTabController length mismatch
    const tabs = <Widget>[
      Tab(text: 'Library'),
      Tab(text: 'Discogs Collection'),
    ];
    final tabViews = <Widget>[
      _buildLocalLibraryTab(),
      _buildDiscogsCollectionTab(),
    ];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (_isOwner)
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilterMenu,
              ),
          ],
          bottom: const TabBar(tabs: tabs),
        ),
        body: GrainyBackgroundWidget(
          child: TabBarView(children: tabViews),
        ),
      ),
    );
  }
}
