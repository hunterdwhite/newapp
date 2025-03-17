import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../models/album.dart';
import '../screens/album_detail_screen.dart';

class MyMusicLibraryScreen extends StatefulWidget {
  @override
  _MyMusicLibraryScreenState createState() => _MyMusicLibraryScreenState();
}

class _MyMusicLibraryScreenState extends State<MyMusicLibraryScreen> {
  final _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _musicItems = [];

  // _filterStatus: 
  // null means default (show orders with status in ['kept', 'returnedConfirmed'])
  // 'kept' means only orders with status "kept"
  // 'returnedConfirmed' means only orders with status "returnedConfirmed"
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _fetchMusicHistory();
  }

  Future<void> _fetchMusicHistory() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      Query ordersQuery = FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: currentUser.uid);

      if (_filterStatus == null) {
        // Default filter: only show "kept" and "returnedConfirmed"
        ordersQuery = ordersQuery.where('status', whereIn: ['kept', 'returnedConfirmed']);
      } else {
        ordersQuery = ordersQuery.where('status', isEqualTo: _filterStatus);
      }

      final ordersSnapshot = await ordersQuery.get();

      // Collect albumIds from orders
      final albumIds = <String>[];
      for (final doc in ordersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final albumId = data['albumId'] ?? data['details']?['albumId'];
        if (albumId != null) {
          albumIds.add(albumId);
        }
      }

      // Fetch album docs for each unique albumId
      final uniqueIds = albumIds.toSet();
      final musicItems = <Map<String, dynamic>>[];

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
            // We use the coverUrl field as the album image URL:
            'albumImageUrl': aData['coverUrl'] ?? '',
          });
        }
      }

      setState(() {
        _musicItems = musicItems;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching MyMusic library: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Music Library'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: Colors.white),
            onSelected: (value) {
              setState(() {
                if (value == 'clear') {
                  _filterStatus = null;
                } else if (value == 'kept') {
                  _filterStatus = 'kept';
                } else if (value == 'returned') {
                  _filterStatus = 'returnedConfirmed';
                }
                _isLoading = true;
              });
              _fetchMusicHistory();
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'clear', child: Text('Clear Filter')),
              PopupMenuItem(value: 'kept', child: Text('Kept')),
              PopupMenuItem(value: 'returned', child: Text('Returned')),
            ],
          )
        ],
      ),
      body: BackgroundWidget(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _musicItems.isEmpty
                ? Center(child: Text('No albums in your music library.'))
                : GridView.builder(
                    padding: EdgeInsets.all(8.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8.0,
                      mainAxisSpacing: 8.0,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _musicItems.length,
                    itemBuilder: (context, index) {
                      final item = _musicItems[index];
                      final coverUrl = item['albumImageUrl'] as String?;
                      return GestureDetector(
                        onTap: () {
                          // Create an Album instance using your Album model
                          final album = Album(
                            albumId: item['albumId'],
                            albumName: item['albumName'],
                            artist: item['artist'],
                            releaseYear: item['releaseYear'],
                            albumImageUrl: item['albumImageUrl'],
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AlbumDetailsScreen(album: album),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: coverUrl != null && coverUrl.isNotEmpty
                                ? Center(
                                    child: Image.network(
                                      coverUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  )
                                : Icon(Icons.album, size: 50),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
