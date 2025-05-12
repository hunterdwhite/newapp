import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:oauth1/oauth1.dart' as oauth1;
import '../widgets/grainy_background_widget.dart';
import '../models/album.dart';
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

  static const _discogsConsumerKey = 'EzVdIgMVbCnRNcwacndA';
  static const _discogsConsumerSecret = 'CUqIDOCeEoFmREnzjKqTmKpstenTGnsE';

  late oauth1.SignatureMethod _signatureMethod;
  late oauth1.ClientCredentials _clientCredentials;

  bool get _isOwner {
    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == widget.userId;
  }

  @override
  void initState() {
    super.initState();
    _fetchLocalWishlist();
    _loadDiscogsTokens();

    _signatureMethod = oauth1.SignatureMethods.hmacSha1;
    _clientCredentials = oauth1.ClientCredentials(
      _discogsConsumerKey,
      _discogsConsumerSecret,
    );
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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final data = userDoc.data();
      if (data == null || data['discogsLinked'] != true) return;

      _discogsLinked = true;
      _discogsAccessToken = data['discogsAccessToken'];
      _discogsAccessSecret = data['discogsTokenSecret'];
      _discogsUsername = data['discogsUsername'];

      _fetchDiscogsWantlist();
    } catch (e) {
      print('Error loading discogs tokens: $e');
    }
  }

  Future<void> _fetchDiscogsWantlist() async {
    if (!_discogsLinked ||
        _discogsAccessToken == null ||
        _discogsAccessSecret == null) return;

    setState(() => _isLoadingDiscogs = true);

    try {
      final client = oauth1.Client(
        _signatureMethod,
        _clientCredentials,
        oauth1.Credentials(_discogsAccessToken!, _discogsAccessSecret!),
      );

      final response = await client.get(
        Uri.parse('https://api.discogs.com/users/${_discogsUsername ?? 'placeholder'}/wants'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final wants = data['wants'] as List<dynamic>;
        final items = <Map<String, String>>[];

        for (var item in wants) {
          final info = item['basic_information'];
          if (info != null) {
            items.add({
              'image': info['cover_image'] ?? '',
              'album': (info['title'] ?? '').toString().replaceAll(RegExp(r'[^\x00-\x7F]'), ''),
              'artist': (info['artists']?[0]?['name'] ?? '').toString().replaceAll(RegExp(r'[^\x00-\x7F]'), ''),
            });
          }
        }

        setState(() => _discogsItems = items);
      }
    } catch (e) {
      print('Error fetching Discogs: $e');
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
        body: BackgroundWidget(
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
                builder: (_) => AlbumDetailsScreen(album: album),
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

  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
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
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      item['image'] ?? '',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item['album'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    item['artist'] ?? '',
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

}
