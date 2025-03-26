import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../models/album.dart';
import 'album_detail_screen.dart';

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

  bool get _isOwner {
    final currentUser = FirebaseAuth.instance.currentUser;
    return (currentUser != null && currentUser.uid == widget.userId);
  }

  @override
  void initState() {
    super.initState();
    _fetchMusicHistory();
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

  @override
  Widget build(BuildContext context) {
    final title = _isOwner ? 'My Music Library' : 'Music Library';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterMenu,
            ),
        ],
      ),
      body: BackgroundWidget(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _musicItems.isEmpty
                ? const Center(child: Text('No albums found.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(8.0),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: 1.0,
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
                              builder: (_) => AlbumDetailsScreen(album: album),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
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
                      );
                    },
                  ),
      ),
    );
  }
}
