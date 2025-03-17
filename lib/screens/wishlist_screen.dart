import 'package:dissonantapp2/widgets/grainy_background_widget.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/album.dart';
import '../screens/album_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  @override
  _WishlistScreenState createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<Map<String, dynamic>> _wishlistItems = [];
  bool _isLoading = true;
  bool _isEditMode = false; // For edit mode

  @override
  void initState() {
    super.initState();
    _fetchWishlistItems();
  }

  Future<void> _fetchWishlistItems() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      QuerySnapshot wishlistSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('wishlist')
          .orderBy('dateAdded', descending: true)
          .get();

      List<Map<String, dynamic>> wishlistItems = wishlistSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'albumId': doc.id,
          'albumName': data['albumName'] ?? 'Unknown Album',
          'albumImageUrl': data['albumImageUrl'] ?? '',
          // You can add defaults for artist and releaseYear if needed:
          'artist': data['artist'] ?? '',
          'releaseYear': data['releaseYear']?.toString() ?? '',
        };
      }).toList();

      setState(() {
        _wishlistItems = wishlistItems;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFromWishlist(String albumId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('wishlist')
          .doc(albumId)
          .delete();
      setState(() {
        _wishlistItems.removeWhere((item) => item['albumId'] == albumId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Album removed from your wishlist')),
      );
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  void _orderAlbum(String albumId) {
    // Navigate to order screen or implement ordering logic
    Navigator.pushNamed(context, '/order', arguments: {'albumId': albumId});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wishlist'),
        actions: [
          TextButton(
            onPressed: _toggleEditMode,
            child: Text(
              _isEditMode ? 'Done' : 'Edit Wishlist',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: BackgroundWidget(
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _wishlistItems.isEmpty
                ? Center(child: Text('Your wishlist is empty'))
                : _isEditMode
                    ? ListView.builder(
                        itemCount: _wishlistItems.length,
                        itemBuilder: (context, index) {
                          final item = _wishlistItems[index];
                          return Card(
                            margin: EdgeInsets.all(8.0),
                            child: ListTile(
                              leading: item['albumImageUrl'] != ''
                                  ? Image.network(item['albumImageUrl'])
                                  : Icon(Icons.album),
                              title: Text(item['albumName']),
                              trailing: IconButton(
                                icon: Icon(Icons.delete),
                                onPressed: () {
                                  _removeFromWishlist(item['albumId']);
                                },
                              ),
                            ),
                          );
                        },
                      )
                    : Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: GridView.builder(
                          padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: _wishlistItems.length,
                          itemBuilder: (context, index) {
                            final item = _wishlistItems[index];
                            return GestureDetector(
                              onTap: () {
                                // Create an Album instance using the data from wishlist
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
                                  child: item['albumImageUrl'] != ''
                                      ? Center(
                                          child: Image.network(
                                            item['albumImageUrl'],
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
      ),
    );
  }
}
