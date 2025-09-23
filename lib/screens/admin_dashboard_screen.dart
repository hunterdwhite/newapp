import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import 'public_profile_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  @override
  _AdminDashboardScreenState createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  /// Whether to show ALL users (including those with no orders).
  bool showAllUsers = false;
  
  /// Cache for user data to improve performance
  List<Map<String, dynamic>>? _cachedUsers;
  bool _isLoading = false;

  final _albumFormKey = GlobalKey<FormState>();
  String _artist = '';
  String _albumName = '';
  String _releaseYear = '';
  String _quality = '';
  String _albumId = '';
  String _coverUrl = '';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userData = await _fetchUsersWithStatus();
      setState(() {
        _cachedUsers = userData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load data: $e')),
      );
    }
  }

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
          // Add refresh button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _refreshData,
                  icon: _isLoading 
                    ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.refresh),
                  label: Text(_isLoading ? 'Loading...' : 'Refresh'),
                ),
                Spacer(),
                Text('${_cachedUsers?.length ?? 0} users loaded'),
              ],
            ),
          ),
          SizedBox(height: 8),
          // Status legend
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Status Legend:', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 4),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _buildLegendItem(Colors.purple, 'Ready to Ship'),
                    _buildLegendItem(Colors.green, 'New/Ready'),
                    _buildLegendItem(Colors.red, 'Curator Assigned'),
                    _buildLegendItem(Colors.orange, 'Curator Working'),
                    _buildLegendItem(Colors.yellow, 'Sent'),
                    _buildLegendItem(Colors.blue, 'Returned'),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: _cachedUsers == null
                ? Center(child: CircularProgressIndicator())
                : Builder(
                    builder: (context) {
                      final allUsers = _cachedUsers!;
                      final visibleUsers = showAllUsers
                          ? allUsers
                          : allUsers.where((u) {
                              final status = u['status'];
                              return status != 'none' && 
                                     status != 'kept' && 
                                     status != 'delivered' && 
                                     status != 'returnedConfirmed';
                            }).toList();

                      return ListView.builder(
                        itemCount: visibleUsers.length,
                        itemBuilder: (context, index) {
                          final userMap = visibleUsers[index];
                          final user = userMap['user'] as Map<String, dynamic>;
                          final userId = userMap['userId'] as String;
                          final status = userMap['status'] as String;

                          // Enhanced dot color system maintaining original Dissonant workflow + curator tracking
                          Color dotColor;
                          String statusText = '';
                          switch (status) {
                            case 'new':
                              dotColor = Colors.green; // GREEN for new Dissonant orders (original behavior)
                              statusText = 'New Order (Dissonant)';
                              break;
                            case 'curator_assigned':
                              dotColor = Colors.red; // RED for curator assigned but no work started
                              statusText = 'Curator Assigned';
                              break;
                            case 'in_progress':
                              dotColor = Colors.orange; // ORANGE for curator working
                              statusText = 'Curator Working';
                              break;
                            case 'album_selected':
                              dotColor = Colors.green; // GREEN for album selected (ready for admin)
                              statusText = 'Album Selected';
                              break;
                            case 'ready_to_ship':
                              dotColor = Colors.purple; // PURPLE for ready to ship (highest priority!)
                              statusText = 'Ready to Ship';
                              break;
                            case 'sent':
                              dotColor = Colors.yellow; // YELLOW for sent (original behavior)
                              statusText = 'Sent';
                              break;
                            case 'returned':
                              dotColor = Colors.blue; // BLUE for returned (original behavior)
                              statusText = 'Returned';
                              break;
                            default:
                              dotColor = Colors.transparent;
                              statusText = 'No Orders';
                              break;
                          }

                          return ListTile(
                            leading: dotColor != Colors.transparent
                                ? Icon(Icons.circle, color: dotColor, size: 12)
                                : null,
                            title: Text(user['username'] ?? 'Unknown'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user['email'] ?? ''),
                                if (statusText.isNotEmpty)
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: dotColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                // Show curator info for relevant statuses
                                if (userMap['curatorInfo'] != null)
                                  Text(
                                    'Curator: ${userMap['curatorInfo']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                // Show album info for selected status
                                if (userMap['albumInfo'] != null)
                                  Text(
                                    'Album: ${userMap['albumInfo']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
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
      final userData = userDoc.data();

      final statusInfo = await _determineUserStatusInfo(userId);
      usersWithStatus.add({
        'userId': userId,
        'user': userData,
        'status': statusInfo['status'],
        'earliestNewTimestamp': statusInfo['earliestNewTimestamp'],
        'curatorInfo': statusInfo['curatorInfo'],
        'albumInfo': statusInfo['albumInfo'],
      });
    }

    // Sort by priority: ready_to_ship (HIGHEST) -> urgent curator items -> ready items -> active -> none
    final statusOrder = ['ready_to_ship', 'curator_assigned', 'in_progress', 'new', 'album_selected', 'sent', 'returned', 'none'];
    usersWithStatus.sort((a, b) {
      final statusA = a['status'] as String;
      final statusB = b['status'] as String;

      final indexA = statusOrder.indexOf(statusA);
      final indexB = statusOrder.indexOf(statusB);
      if (indexA != indexB) return indexA.compareTo(indexB);

      // If same status, sort by timestamp (oldest first for urgent statuses)
      if (['ready_to_ship', 'curator_assigned', 'in_progress', 'new', 'album_selected'].contains(statusA)) {
        final tsA = a['earliestNewTimestamp'];
        final tsB = b['earliestNewTimestamp'];
        if (tsA != null && tsB != null) {
          return tsA.compareTo(tsB); // Oldest first for urgent items
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
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (ordersSnapshot.docs.isEmpty) {
      return {
        'status': 'none',
        'earliestNewTimestamp': null,
        'curatorInfo': null,
        'albumInfo': null,
      };
    }

    final latestOrder = ordersSnapshot.docs.first;
    final orderData = latestOrder.data();
    final status = orderData['status'] ?? '';
    final orderTs = orderData['timestamp'] as Timestamp?;
    final curatorId = orderData['curatorId'] as String?;
    // Fix: Check both new (root level) and old (details) data structures for albumId
    final albumId = orderData['albumId'] ?? orderData['details']?['albumId'];

    String finalStatus = 'none';
    String? curatorInfo;
    String? albumInfo;

    // Determine status based on order progression - maintains both Dissonant and Curator routes
    switch (status) {
      case 'new':
        // Traditional Dissonant route - show as green (ready for admin action)
        finalStatus = 'new';
        break;
      case 'curator_assigned':
        finalStatus = 'curator_assigned';
        // Fetch curator username
        if (curatorId != null && curatorId.isNotEmpty) {
          try {
            final curatorDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(curatorId)
                .get();
            if (curatorDoc.exists) {
              final curatorData = curatorDoc.data() as Map<String, dynamic>;
              curatorInfo = curatorData['username'] ?? 'Unknown Curator';
            }
          } catch (e) {
            curatorInfo = 'Unknown Curator';
          }
        }
        break;
      case 'in_progress':
        finalStatus = 'in_progress';
        // Curator is working on selection
        if (curatorId != null && curatorId.isNotEmpty) {
          try {
            final curatorDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(curatorId)
                .get();
            if (curatorDoc.exists) {
              final curatorData = curatorDoc.data() as Map<String, dynamic>;
              curatorInfo = curatorData['username'] ?? 'Unknown Curator';
            }
          } catch (e) {
            curatorInfo = 'Unknown Curator';
          }
        }
        
        // Check if album has been selected
        if (albumId != null && albumId.isNotEmpty) {
          finalStatus = 'album_selected';
          try {
            final albumDoc = await FirebaseFirestore.instance
                .collection('albums')
                .doc(albumId)
                .get();
            if (albumDoc.exists) {
              final albumData = albumDoc.data() as Map<String, dynamic>;
              albumInfo = '${albumData['artist']} - ${albumData['albumName']}';
            }
          } catch (e) {
            albumInfo = 'Unknown Album';
          }
        }
        break;
      case 'sent':
        finalStatus = 'sent';
        if (albumId != null && albumId.isNotEmpty) {
          try {
            final albumDoc = await FirebaseFirestore.instance
                .collection('albums')
                .doc(albumId)
                .get();
            if (albumDoc.exists) {
              final albumData = albumDoc.data() as Map<String, dynamic>;
              albumInfo = '${albumData['artist']} - ${albumData['albumName']}';
            }
          } catch (e) {
            albumInfo = 'Unknown Album';
          }
        }
        break;
      case 'ready_to_ship':
        // CRITICAL: Curator has selected album, admin needs to ship it!
        finalStatus = 'ready_to_ship';
        
        if (albumId != null && albumId.isNotEmpty) {
          try {
            final albumDoc = await FirebaseFirestore.instance
                .collection('albums')
                .doc(albumId)
                .get();
            if (albumDoc.exists) {
              final albumData = albumDoc.data() as Map<String, dynamic>;
              albumInfo = '${albumData['artist']} - ${albumData['albumName']}';
            } else {
              albumInfo = 'Album not found';
            }
          } catch (e) {
            albumInfo = 'Error loading album';
          }
        } else {
          albumInfo = 'No album selected';
        }
        
        // Also get curator info for ready_to_ship orders
        if (curatorId != null && curatorId.isNotEmpty) {
          try {
            final curatorDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(curatorId)
                .get();
            if (curatorDoc.exists) {
              final curatorData = curatorDoc.data() as Map<String, dynamic>;
              curatorInfo = curatorData['username'] ?? 'Unknown Curator';
            }
          } catch (e) {
            curatorInfo = 'Unknown Curator';
          }
        }
        break;
      case 'returned':
        finalStatus = 'returned';
        break;
      case 'delivered':
      case 'kept':
      case 'returnedConfirmed':
        // Skip these completed statuses - admin doesn't need to see them
        finalStatus = 'none';
        break;
      default:
        finalStatus = 'none';
    }

    return {
      'status': finalStatus,
      'earliestNewTimestamp': orderTs,
      'curatorInfo': curatorInfo,
      'albumInfo': albumInfo,
    };
  }

  void _showUserDetails(String userId, Map<String, dynamic> user) {
    bool showWishlist = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, setState) {
            return AlertDialog(
            title: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PublicProfileScreen(userId: userId),
                  ),
                );
              },
              child: Text(
                user['username'] ?? 'Unknown',
                style: TextStyle(
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline, // Optional visual indication
                ),
              ),
            ),              content: SingleChildScrollView(
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

                        // Separate new orders and ready_to_ship orders (both need action buttons)
                        final newOrders = orders
                            .where((o) =>
                                (o.data() as Map<String, dynamic>)['status'] ==
                                'new')
                            .toList();
                        final readyToShipOrders = orders
                            .where((o) =>
                                (o.data() as Map<String, dynamic>)['status'] ==
                                'ready_to_ship')
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
                        readyToShipOrders.sort((a, b) {
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
                        final newestReadyToShipOrder =
                            readyToShipOrders.isNotEmpty ? readyToShipOrders.first : null;

                        // The rest are older orders (excluding newest new and newest ready_to_ship)
                        final olderOrders = <DocumentSnapshot>[];
                        for (final order in orders) {
                          if (newestNewOrder != null &&
                              order.id == newestNewOrder.id) {
                            continue;
                          }
                          if (newestReadyToShipOrder != null &&
                              order.id == newestReadyToShipOrder.id) {
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

                          // find last known address from older orders
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
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text('Address: $currentAddress'),
                                      ),
                                      if (addressDiffers)
                                        Icon(Icons.warning, color: Colors.red),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text('Status: ${orderData['status'] ?? 'N/A'}'),
                                ],
                              ),
                              trailing: _buildOrderActions(
                                orderData,
                                orderId,
                                userId,
                              ),
                            ),
                          );
                        }

                        // If there's a newest "ready_to_ship" order, show it in detail
                        if (newestReadyToShipOrder != null) {
                          final orderData =
                              newestReadyToShipOrder.data() as Map<String, dynamic>;
                          final orderId = newestReadyToShipOrder.id;
                          final currentAddress = orderData['address'] ?? 'N/A';

                          orderWidgets.add(
                            ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Address: $currentAddress'),
                                  SizedBox(height: 4),
                                  Text('Status: ${orderData['status'] ?? 'N/A'}'),
                                ],
                              ),
                              trailing: _buildOrderActions(
                                orderData,
                                orderId,
                                userId,
                              ),
                            ),
                          );
                        }

                        // Show minimal info for older orders
                        olderOrders.forEach((orderDoc) {
                          final data = orderDoc.data() as Map<String, dynamic>;
                          final albumId = data['albumId'] as String?;
                          final status = data['status'] ?? 'N/A';
                          final isReturned =
                              (status == 'returned') && !(data['returnConfirmed'] ?? false);

                          // If the order is returned but NOT confirmed,
                          // skip showing album info, show address + confirm button
                          if (isReturned) {
                            // Show the address + 'Confirm Return'
                            final address = data['address'] ?? 'N/A';
                            orderWidgets.add(
                              ListTile(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 8,
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Address: $address'),
                                    SizedBox(height: 4),
                                    Text('Status: returned'),
                                  ],
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _confirmReturn(orderDoc.id),
                                  child: Text('Confirm Return'),
                                ),
                              ),
                            );
                          } else {
                            // Otherwise, load the album doc as normal
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
                                      title: Text('Older Order (No album assigned)'),
                                      subtitle: Text('Status: $status'),
                                    );
                                  }
                                  final albumData = albumSnapshot.data!.data()
                                      as Map<String, dynamic>;
                                  final artist = albumData['artist'] ?? 'Unknown';
                                  final name = albumData['albumName'] ?? 'Unknown';
                                  return ListTile(
                                    title: Text('$artist - $name'),
                                    subtitle: Text('Status: $status'),
                                  );
                                },
                              ),
                            );
                          }
                        });

                        return Column(children: orderWidgets);
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
    // If the order is 'returned' => "Confirm Return" button
    if (order['status'] == 'returned') {
      return ElevatedButton(
        onPressed: () {
          _confirmReturn(orderId);
        },
        child: Text('Confirm Return'),
      );
    }
    // If the order is 'ready_to_ship' => "Mark as Sent" button
    else if (order['status'] == 'ready_to_ship') {
      return ElevatedButton(
        onPressed: () {
          _markAsSent(orderId);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
        child: Text('Mark as Sent'),
      );
    }
    // If the order is 'new' => "Send Album" button
    else if (order['status'] == 'new') {
      return ElevatedButton(
        onPressed: () {
          _showSendAlbumDialog(orderId, order['address'], userId);
        },
        child: Text('Send Album'),
      );
    }
    // Otherwise no action
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
    // Mark the order doc, e.g. set `returnConfirmed = true` or `status=returnedConfirmed`
    await _firestoreService.confirmReturn(orderId);
    setState(() {});
  }

  Future<void> _markAsSent(String orderId) async {
    try {
      // Update order status from 'ready_to_ship' to 'sent'
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'sent',
        'shippedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Refresh the data to show updated status
      _refreshData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as sent!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking as sent: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 12),
        SizedBox(width: 4),
        Text(
          label, 
          style: TextStyle(
            fontSize: 12,
            color: Colors.black,
          ),
        ),
      ],
    );
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
