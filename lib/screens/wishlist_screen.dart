import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../models/album_model.dart';
import '../services/discogs_service.dart';
import 'album_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  final String userId;

  const WishlistScreen({Key? key, required this.userId}) : super(key: key);

  @override
  _WishlistScreenState createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Map<String, dynamic>> _wishlistItems = [];
  bool _isLoadingLocal = true;
  bool _isEditMode = false;

  bool _discogsLinked = false;
  String? _discogsUsername;
  String? _discogsAccessToken;
  String? _discogsAccessSecret;

  List<Map<String, String>> _discogsItems = [];
  bool _isLoadingDiscogs = false;

  final DiscogsService _discogsService = DiscogsService();

  bool get _isOwner {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == widget.userId;
  }

  @override
  void initState() {
    super.initState();
    _fetchLocalWishlist();
    _loadDiscogsTokens();
  }

  Future<void> _fetchLocalWishlist() async {
    setState(() => _isLoadingLocal = true);
    try {
      final wishlistSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('wishlist')
          .orderBy('dateAdded', descending: true)
          .get();

      final items = <Map<String, dynamic>>[];

      for (final doc in wishlistSnapshot.docs) {
        final data = doc.data();
        final docAlbumId = data['albumId'] ?? doc.id;

        String albumName = data['albumName'] ?? 'Unknown Album';
        String albumImageUrl = data['albumImageUrl'] ?? '';
        String artist = data['artist'] ?? '';
        String releaseYear = data['releaseYear']?.toString() ?? '';

        if (docAlbumId.isNotEmpty) {
          final albumSnap = await FirebaseFirestore.instance
              .collection('albums')
              .doc(docAlbumId)
              .get();
          if (albumSnap.exists) {
            final aData = albumSnap.data()!;
            albumName = aData['albumName'] ?? albumName;
            albumImageUrl = aData['coverUrl'] ?? albumImageUrl;
            artist = aData['artist'] ?? artist;
            releaseYear = aData['releaseYear']?.toString() ?? releaseYear;
          }
        }

        items.add({
          'albumId': docAlbumId,
          'albumName': albumName,
          'albumImageUrl': albumImageUrl,
          'artist': artist,
          'releaseYear': releaseYear,
        });
      }

      setState(() {
        _wishlistItems = items;
        _isLoadingLocal = false;
      });
    } catch (e) {
      print('Error fetching local wishlist: $e');
      setState(() => _isLoadingLocal = false);
    }
  }

  Future<void> _removeFromWishlist(String albumId) async {
    if (_isOwner) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('wishlist')
          .doc(albumId)
          .delete();
      setState(() {
        _wishlistItems.removeWhere((item) => item['albumId'] == albumId);
      });
    }
  }

  void _toggleEditMode() {
    if (_isOwner) {
      setState(() => _isEditMode = !_isEditMode);
    }
  }

  Future<void> _loadDiscogsTokens() async {
    try {
      final authData = await _discogsService.loadAuthData(widget.userId);
      if (authData == null) return;

      _discogsLinked = true;
      _discogsAccessToken = authData['accessToken'];
      _discogsAccessSecret = authData['accessSecret'];
      _discogsUsername = authData['username'];

      _fetchDiscogsWantlist();
    } catch (e) {
      print('Error loading discogs tokens: $e');
    }
  }

  Future<void> _fetchDiscogsWantlist() async {
    if (!_discogsLinked ||
        _discogsAccessToken == null ||
        _discogsAccessSecret == null ||
        _discogsUsername == null) return;

    setState(() => _isLoadingDiscogs = true);

    try {
      final items = await _discogsService.getWantlist(
        _discogsUsername!,
        _discogsAccessToken!,
        _discogsAccessSecret!,
      );
      setState(() => _discogsItems = items);
    } catch (e) {
      print('Error fetching Discogs wantlist: $e');
    } finally {
      setState(() => _isLoadingDiscogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isOwner ? 'My Wishlist' : 'Wishlist'),
          actions: [
            if (_isOwner)
              TextButton(
                onPressed: _toggleEditMode,
                child: Text(
                  _isEditMode ? 'Done' : 'Edit',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Wishlist'),
              Tab(text: 'Discogs Wantlist'),
            ],
          ),
        ),
        body: GrainyBackgroundWidget(
          child: TabBarView(
            children: [
              _buildLocalTabContent(),
              _buildDiscogsTabContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalTabContent() {
    if (_isLoadingLocal) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_wishlistItems.isEmpty) {
      return const Center(child: Text('No items in wishlist.'));
    }

    if (_isEditMode) {
      return ListView.builder(
        itemCount: _wishlistItems.length,
        itemBuilder: (context, index) {
          final item = _wishlistItems[index];
          return Card(
            child: ListTile(
              leading: item['albumImageUrl'].isNotEmpty
                  ? Image.network(item['albumImageUrl'])
                  : const Icon(Icons.album),
              title: Text(item['albumName']),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _removeFromWishlist(item['albumId']),
              ),
            ),
          );
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _wishlistItems.length,
      itemBuilder: (context, index) {
        final item = _wishlistItems[index];
        final album = Album(
          albumId: item['albumId'],
          albumName: item['albumName'],
          albumImageUrl: item['albumImageUrl'],
          artist: item['artist'],
          releaseYear: item['releaseYear'],
        );

        return GestureDetector(
          onTap: () {
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
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    album.albumImageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(album.albumName, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(album.artist, style: const TextStyle(fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  // Inside _buildDiscogsTabContent()
Widget _buildDiscogsTabContent() {
  if (!_discogsLinked) {
    return const Center(child: Text('Discogs account not linked.'));
  }
  if (_isLoadingDiscogs) {
    return const Center(child: CircularProgressIndicator());
  }
  if (_discogsItems.isEmpty) {
    return const Center(child: Text('No items in Discogs wantlist.'));
  }

  return GridView.builder(
    padding: const EdgeInsets.all(8),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 0.8,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
    ),
    itemCount: _discogsItems.length,
    itemBuilder: (context, index) {
      final item = _discogsItems[index];
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

}
