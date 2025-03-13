import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  /// Whether to show ALL users (including those with no orders).
  bool showAllUsers = false;

  final _albumFormKey = GlobalKey<FormState>();
  String _artist = '';
  String _albumName = '';
  String _releaseYear = '';
  String _quality = '';
  String _albumId = '';
  String _coverUrl = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_alt),
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.library_music),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AlbumListScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
              );
            },
            child: Text('Go to Home Page'),
          ),
          ElevatedButton(
            onPressed: _showAddAlbumDialog,
            child: Text('Add New Album'),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchUsersWithStatus(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final allUsers = snapshot.data!;
                final visibleUsers = showAllUsers
                    ? allUsers
                    : allUsers.where((u) => u['status'] != 'none').toList();

                return ListView.builder(
                  itemCount: visibleUsers.length,
                  itemBuilder: (context, index) {
                    final userMap = visibleUsers[index];
                    final user = userMap['user'] as Map<String, dynamic>;
                    final userId = userMap['userId'] as String;
                    final status = userMap['status'] as String;

                    // Dot color
                    Color dotColor;
                    switch (status) {
                      case 'new':
                        dotColor = Colors.green;
                        break;
                      case 'active':
                        dotColor = Colors.yellow;
                        break;
                      case 'returned':
                        dotColor = Colors.blue;
                        break;
                      default:
                        dotColor = Colors.transparent;
                        break;
                    }

                    return ListTile(
                      leading: dotColor != Colors.transparent
                          ? Icon(Icons.circle, color: dotColor, size: 12)
                          : null,
                      title: Text(user['username'] ?? 'Unknown'),
                      subtitle: Text(user['email'] ?? ''),
                      onTap: () {
                        _showUserDetails(userId, user);
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Toggle button at the bottom
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  showAllUsers = !showAllUsers;
                });
              },
              child: Text(
                showAllUsers ? 'Hide Inactive Users' : 'Show All Users',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchUsersWithStatus() async {
    final usersSnapshot =
        await FirebaseFirestore.instance.collection('users').get();

    List<Map<String, dynamic>> usersWithStatus = [];

    for (var userDoc in usersSnapshot.docs) {
      final userId = userDoc.id;
      final userData = userDoc.data() as Map<String, dynamic>;

      final statusInfo = await _determineUserStatusInfo(userId);
      usersWithStatus.add({
        'userId': userId,
        'user': userData,
        'status': statusInfo['status'],
        'earliestNewTimestamp': statusInfo['earliestNewTimestamp'],
      });
    }

    // Sort by status: new -> active -> returned -> none
    final statusOrder = ['new', 'active', 'returned', 'none'];
    usersWithStatus.sort((a, b) {
      final statusA = a['status'] as String;
      final statusB = b['status'] as String;

      final indexA = statusOrder.indexOf(statusA);
      final indexB = statusOrder.indexOf(statusB);
      if (indexA != indexB) return indexA.compareTo(indexB);

      // If both "new", compare earliestNewTimestamp
      if (statusA == 'new') {
        final tsA = a['earliestNewTimestamp'] as Timestamp?;
        final tsB = b['earliestNewTimestamp'] as Timestamp?;
        if (tsA != null && tsB != null) {
          return tsA.compareTo(tsB);
        } else if (tsA == null && tsB != null) {
          return 1;
        } else if (tsA != null && tsB == null) {
          return -1;
        }
      }
      return 0;
    });

    return usersWithStatus;
  }

  Future<Map<String, dynamic>> _determineUserStatusInfo(String userId) async {
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .get();

    bool hasNewOrder = false;
    bool hasActiveOrder = false;
    bool hasReturnedOrder = false;
    Timestamp? earliestNewTimestamp;

    for (var orderDoc in ordersSnapshot.docs) {
      final status = orderDoc['status'] ?? '';
      final orderTs = orderDoc['timestamp'] as Timestamp?;

      if (status == 'new') {
        hasNewOrder = true;
        if (orderTs != null) {
          if (earliestNewTimestamp == null ||
              orderTs.compareTo(earliestNewTimestamp) < 0) {
            earliestNewTimestamp = orderTs;
          }
        }
      } else if (status == 'sent') {
        hasActiveOrder = true;
      } else if (status == 'returned') {
        hasReturnedOrder = true;
      }
    }

    if (hasNewOrder) {
      return {
        'status': 'new',
        'earliestNewTimestamp': earliestNewTimestamp,
      };
    } else if (hasActiveOrder) {
      return {
        'status': 'active',
        'earliestNewTimestamp': null,
      };
    } else if (hasReturnedOrder) {
      return {
        'status': 'returned',
        'earliestNewTimestamp': null,
      };
    } else {
      return {
        'status': 'none',
        'earliestNewTimestamp': null,
      };
    }
  }

  void _showUserDetails(String userId, Map<String, dynamic> user) {
    bool showWishlist = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
              title: Text(user['username'] ?? 'User Details'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: ${user['email'] ?? 'N/A'}'),
                    SizedBox(height: 10),
                    Text(
                      'Taste Profile:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    _buildTasteProfile(
                      user['tasteProfile'] as Map<String, dynamic>?,
                    ),
                    SizedBox(height: 10),
                    Text('Orders:', style: TextStyle(fontWeight: FontWeight.bold)),
                    FutureBuilder<List<DocumentSnapshot>>(
                      future: _firestoreService.getOrdersForUser(userId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final orders = snapshot.data ?? [];
                        if (orders.isEmpty) {
                          return Text('No orders available');
                        }

                        // Separate new orders
                        final newOrders = orders
                            .where((o) =>
                                (o.data() as Map<String, dynamic>)['status'] ==
                                'new')
                            .toList();
                        newOrders.sort((a, b) {
                          final aTs =
                              (a.data() as Map<String, dynamic>)['timestamp']
                                  as Timestamp?;
                          final bTs =
                              (b.data() as Map<String, dynamic>)['timestamp']
                                  as Timestamp?;
                          if (aTs == null || bTs == null) return 0;
                          return bTs.compareTo(aTs);
                        });
                        final newestNewOrder =
                            newOrders.isNotEmpty ? newOrders.first : null;

                        final olderOrders = <DocumentSnapshot>[];
                        for (final order in orders) {
                          if (newestNewOrder != null &&
                              order.id == newestNewOrder.id) {
                            continue;
                          }
                          olderOrders.add(order);
                        }

                        List<Widget> orderWidgets = [];

                        // If there's a newest "new" order, show it in detail
                        if (newestNewOrder != null) {
                          final orderData =
                              newestNewOrder.data() as Map<String, dynamic>;
                          final orderId = newestNewOrder.id;
                          final currentAddress = orderData['address'] ?? 'N/A';

                          // find last known address from olderOrders
                          olderOrders.sort((a, b) {
                            final aTs =
                                (a.data() as Map<String, dynamic>)['timestamp']
                                    as Timestamp?;
                            final bTs =
                                (b.data() as Map<String, dynamic>)['timestamp']
                                    as Timestamp?;
                            if (aTs == null && bTs == null) return 0;
                            if (aTs == null) return 1;
                            if (bTs == null) return -1;
                            return bTs.compareTo(aTs);
                          });

                          String? lastKnownAddress;
                          if (olderOrders.isNotEmpty) {
                            final lastOrderData =
                                olderOrders.first.data() as Map<String, dynamic>?;
                            lastKnownAddress = lastOrderData?['address'];
                          }
                          bool addressDiffers = false;
                          if (lastKnownAddress != null &&
                              lastKnownAddress.isNotEmpty &&
                              currentAddress != lastKnownAddress) {
                            addressDiffers = true;
                          }

                          orderWidgets.add(
                            ListTile(
                              title: Row(
                                children: [
                                  Text('Address: $currentAddress'),
                                  if (addressDiffers) ...[
                                    SizedBox(width: 6),
                                    Icon(Icons.warning, color: Colors.red),
                                  ],
                                ],
                              ),
                              subtitle:
                                  Text('Status: ${orderData['status'] ?? 'N/A'}'),
                              trailing: _buildOrderActions(
                                orderData,
                                orderId,
                                userId,
                              ),
                            ),
                          );
                        }

                        // Minimal info for older orders
                        olderOrders.forEach((orderDoc) {
                          final data = orderDoc.data() as Map<String, dynamic>;
                          final albumId = data['albumId'] as String?;
                          final status = data['status'] ?? 'N/A';

                          orderWidgets.add(
                            FutureBuilder<DocumentSnapshot?>(
                              future: (albumId != null && albumId.isNotEmpty)
                                  ? _firestoreService.getAlbumById(albumId)
                                  : Future.value(null),
                              builder: (context, albumSnapshot) {
                                if (albumSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return ListTile(
                                    title: Text('Loading album info...'),
                                  );
                                }
                                if (albumSnapshot.data == null ||
                                    !albumSnapshot.data!.exists) {
                                  return ListTile(
                                    title:
                                        Text('Older Order (No album assigned)'),
                                    subtitle: Text('Status: $status'),
                                  );
                                }
                                final albumData =
                                    albumSnapshot.data!.data() as Map<String, dynamic>;
                                final artist = albumData['artist'] ?? 'Unknown';
                                final name = albumData['albumName'] ?? 'Unknown';
                                return ListTile(
                                  title: Text('$artist - $name'),
                                  subtitle: Text('Status: $status'),
                                );
                              },
                            ),
                          );
                        });

                        return Column(
                          children: orderWidgets,
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    // Show/hide wishlist
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          showWishlist = !showWishlist;
                        });
                      },
                      child:
                          Text(showWishlist ? 'Hide Wishlist' : 'Show Wishlist'),
                    ),
                    if (showWishlist)
                      FutureBuilder<List<DocumentSnapshot>>(
                        future: _firestoreService.getWishlistForUser(userId),
                        builder: (context, wishlistSnapshot) {
                          if (wishlistSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }
                          if (!wishlistSnapshot.hasData ||
                              wishlistSnapshot.data!.isEmpty) {
                            return Text('No wishlist found.');
                          }
                          final wishlistDocs = wishlistSnapshot.data!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: wishlistDocs.map((doc) {
                              final wData = doc.data() as Map<String, dynamic>;
                              final albumName = wData['albumName'] ?? 'Unknown';
                              // or any other fields: wData['artist'], etc.
                              return Text('• $albumName');
                            }).toList(),
                          );
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTasteProfile(Map<String, dynamic>? tasteProfile) {
    if (tasteProfile == null) {
      return Text('No taste profile available');
    }

    List<Widget> profileWidgets = [];

    List<String> genres = List<String>.from(tasteProfile['genres'] ?? []);
    profileWidgets.add(
      Text('Genres: ${genres.isNotEmpty ? genres.join(', ') : 'N/A'}'),
    );

    List<String> decades = List<String>.from(tasteProfile['decades'] ?? []);
    profileWidgets.add(
      Text('Decades: ${decades.isNotEmpty ? decades.join(', ') : 'N/A'}'),
    );

    String albumsListened = tasteProfile['albumsListened'] ?? 'N/A';
    profileWidgets.add(Text('Albums Listened: $albumsListened'));

    String musicalBio = tasteProfile['musicalBio'] ?? 'N/A';
    profileWidgets.add(Text('Musical Bio: $musicalBio'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: profileWidgets,
    );
  }

  Widget _buildOrderActions(
      Map<String, dynamic> order, String orderId, String userId) {
    // If the order is 'returned' but not confirmed, show "Confirm Return" button
    if (order['status'] == 'returned' &&
        (order['returnConfirmed'] ?? false) == false) {
      return ElevatedButton(
        onPressed: () {
          _confirmReturn(orderId);
        },
        child: Text('Confirm Return'),
      );
    }
    // If the order is 'new', show "Send Album" button
    else if (order['status'] == 'new') {
      return ElevatedButton(
        onPressed: () {
          _showSendAlbumDialog(orderId, order['address'], userId);
        },
        child: Text('Send Album'),
      );
    }
    // Otherwise, no action needed
    else {
      return Text('No action needed');
    }
  }

  void _showAddAlbumDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add Album'),
          content: Form(
            key: _albumFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField('Artist', (value) => _artist = value),
                  _buildTextField('Album Name', (value) => _albumName = value),
                  _buildTextField('Release Year', (value) => _releaseYear = value),
                  _buildTextField('Quality', (value) => _quality = value),
                  _buildTextField('Cover URL', (value) => _coverUrl = value),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _albumFormKey.currentState?.reset();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _addAlbum();
                Navigator.of(context).pop();
                _albumFormKey.currentState?.reset();
              },
              child: Text('Add Album'),
            ),
          ],
        );
      },
    );
  }

  void _showSendAlbumDialog(String orderId, String address, String userId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Send Album'),
          content: Form(
            key: _albumFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField('Artist', (value) => _artist = value),
                  _buildTextField('Album Name', (value) => _albumName = value),
                  _buildTextField('Release Year', (value) => _releaseYear = value),
                  _buildTextField('Quality', (value) => _quality = value),
                  _buildTextField('Cover URL', (value) => _coverUrl = value),
                  _buildTextField(
                    'Album ID (if reusing existing album)',
                    (value) => _albumId = value,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _albumFormKey.currentState?.reset();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _sendAlbum(orderId, address, userId);
                Navigator.of(context).pop();
                _albumFormKey.currentState?.reset();
              },
              child: Text('Send'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField(String label, Function(String) onChanged) {
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      onChanged: (value) {
        setState(() {
          onChanged(value);
        });
      },
    );
  }

  Future<void> _sendAlbum(String orderId, String address, String userId) async {
    String albumId;

    if (_albumId.isNotEmpty) {
      albumId = _albumId;
    } else {
      DocumentReference albumRef = await _firestoreService.addAlbum(
        _artist,
        _albumName,
        _releaseYear,
        _quality,
        _coverUrl,
      );
      albumId = albumRef.id;
    }

    await _firestoreService.updateOrderWithAlbum(orderId, albumId);
    setState(() {});
  }

  Future<void> _addAlbum() async {
    if (_albumFormKey.currentState?.validate() ?? false) {
      _albumFormKey.currentState?.save();
      await _firestoreService.addAlbum(
        _artist,
        _albumName,
        _releaseYear,
        _quality,
        _coverUrl,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Album added successfully')),
      );
      setState(() {});
    }
  }

  Future<void> _confirmReturn(String orderId) async {
    await _firestoreService.confirmReturn(orderId);
    setState(() {});
  }
}

class AlbumListScreen extends StatelessWidget {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Album List'),
      ),
      body: FutureBuilder<List<DocumentSnapshot>>(
        future: _firestoreService.getAllAlbums(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final albums = snapshot.data ?? [];

          return ListView.builder(
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index].data() as Map<String, dynamic>;

              return ListTile(
                title: Text(album['albumName'] ?? 'Unknown'),
                subtitle: Text(
                  'Artist: ${album['artist'] ?? 'N/A'} '
                  '- Year: ${album['releaseYear'] ?? 'N/A'} '
                  '- Quality: ${album['quality'] ?? 'N/A'}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}
