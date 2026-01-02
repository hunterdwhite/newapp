import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'home_screen.dart';
import 'public_profile_screen.dart';
import 'admin_album_selection_screen.dart';

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
  int _totalUserCount = 0;

  final _albumFormKey = GlobalKey<FormState>();
  String _artist = '';
  String _albumName = '';
  String _releaseYear = '';
  String _quality = '';
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
      // Fetch active users and total count in parallel
      final results = await Future.wait([
        _fetchUsersWithStatus(),
        _fetchTotalUserCount(),
      ]);
      
      setState(() {
        _cachedUsers = results[0] as List<Map<String, dynamic>>;
        _totalUserCount = results[1] as int;
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
  
  /// Get total user count (fast aggregation query)
  Future<int> _fetchTotalUserCount() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .count()
        .get();
    return snapshot.count ?? 0;
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
            child: Text('Add Album to Inventory'),
          ),
          // Add refresh button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _refreshData,
                  icon: _isLoading
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.refresh),
                  label: Text(_isLoading ? 'Loading...' : 'Refresh'),
                ),
                Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_totalUserCount total users',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${_cachedUsers?.length ?? 0} with active orders',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
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
                              dotColor = Colors
                                  .green; // GREEN for new Dissonant orders (original behavior)
                              statusText = 'New Order (Dissonant)';
                              break;
                            case 'curator_assigned':
                              dotColor = Colors
                                  .red; // RED for curator assigned but no work started
                              statusText = 'Curator Assigned';
                              break;
                            case 'in_progress':
                              dotColor =
                                  Colors.orange; // ORANGE for curator working
                              statusText = 'Curator Working';
                              break;
                            case 'album_selected':
                              dotColor = Colors
                                  .green; // GREEN for album selected (ready for admin)
                              statusText = 'Album Selected';
                              break;
                            case 'ready_to_ship':
                              dotColor = Colors
                                  .purple; // PURPLE for ready to ship (highest priority!)
                              statusText = 'Ready to Ship';
                              break;
                            case 'sent':
                              dotColor = Colors
                                  .yellow; // YELLOW for sent (original behavior)
                              statusText = 'Sent';
                              break;
                            case 'returned':
                              dotColor = Colors
                                  .blue; // BLUE for returned (original behavior)
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

  /// OPTIMIZED: Query active orders first, then batch-load related data
  /// This reduces 1000+ queries down to ~10 queries total
  Future<List<Map<String, dynamic>>> _fetchUsersWithStatus() async {
    // Step 1: Query ONLY orders with active statuses (instead of all users)
    final activeStatuses = [
      'new',
      'curator_assigned', 
      'in_progress',
      'ready_to_ship',
      'sent',
      'returned',
    ];
    
    // Get all active orders in ONE query
    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', whereIn: activeStatuses)
        .orderBy('timestamp', descending: true)
        .get();
    
    if (ordersSnapshot.docs.isEmpty) {
      return [];
    }
    
    // Step 2: Collect unique user IDs, curator IDs, and album IDs
    final Set<String> userIds = {};
    final Set<String> curatorIds = {};
    final Set<String> albumIds = {};
    
    // Map to track latest order per user (we only care about their most recent active order)
    final Map<String, QueryDocumentSnapshot> latestOrderByUser = {};
    
    for (var orderDoc in ordersSnapshot.docs) {
      final orderData = orderDoc.data();
      final userId = orderData['userId'] as String?;
      if (userId == null) continue;
      
      // Only keep the latest order per user (they're already sorted by timestamp desc)
      if (!latestOrderByUser.containsKey(userId)) {
        latestOrderByUser[userId] = orderDoc;
        userIds.add(userId);
        
        final curatorId = orderData['curatorId'] as String?;
        if (curatorId != null && curatorId.isNotEmpty) {
          curatorIds.add(curatorId);
        }
        
        final albumId = orderData['albumId'] ?? orderData['details']?['albumId'];
        if (albumId != null && albumId.isNotEmpty) {
          albumIds.add(albumId);
        }
      }
    }
    
    // Step 3: Batch-load all users, curators, and albums in parallel
    final usersFuture = _batchGetDocuments('users', userIds.toList());
    final curatorsFuture = curatorIds.isNotEmpty 
        ? _batchGetDocuments('users', curatorIds.toList())
        : Future.value(<String, Map<String, dynamic>>{});
    final albumsFuture = albumIds.isNotEmpty
        ? _batchGetDocuments('albums', albumIds.toList())
        : Future.value(<String, Map<String, dynamic>>{});
    
    final results = await Future.wait([usersFuture, curatorsFuture, albumsFuture]);
    final usersMap = results[0];
    final curatorsMap = results[1];
    final albumsMap = results[2];
    
    // Step 4: Build the result list
    List<Map<String, dynamic>> usersWithStatus = [];
    
    for (var entry in latestOrderByUser.entries) {
      final userId = entry.key;
      final orderDoc = entry.value;
      final orderData = orderDoc.data() as Map<String, dynamic>?;
      if (orderData == null) continue; // Skip if order data is null
      
      final userData = usersMap[userId];
      if (userData == null) continue; // Skip if user not found
      
      final status = orderData['status'] as String? ?? '';
      final orderTs = orderData['timestamp'] as Timestamp?;
      final curatorId = orderData['curatorId'] as String?;
      final details = orderData['details'] as Map<String, dynamic>?;
      final albumId = orderData['albumId'] as String? ?? details?['albumId'] as String?;
      
      // Determine display status
      String finalStatus = _mapOrderStatusToDisplayStatus(status, albumId);
      
      // Get curator info from pre-loaded map
      String? curatorInfo;
      if (curatorId != null && curatorsMap.containsKey(curatorId)) {
        curatorInfo = curatorsMap[curatorId]?['username'] ?? 'Unknown Curator';
      }
      
      // Get album info from pre-loaded map
      String? albumInfo;
      if (albumId != null && albumsMap.containsKey(albumId)) {
        final albumData = albumsMap[albumId];
        albumInfo = '${albumData?['artist'] ?? 'Unknown'} - ${albumData?['albumName'] ?? 'Unknown'}';
      }
      
      usersWithStatus.add({
        'userId': userId,
        'user': userData,
        'status': finalStatus,
        'earliestNewTimestamp': orderTs,
        'curatorInfo': curatorInfo,
        'albumInfo': albumInfo,
        'orderId': orderDoc.id,
      });
    }
    
    // Step 5: Sort by priority
    final statusOrder = [
      'ready_to_ship',
      'curator_assigned',
      'in_progress',
      'new',
      'album_selected',
      'sent',
      'returned',
      'none'
    ];
    
    usersWithStatus.sort((a, b) {
      final indexA = statusOrder.indexOf(a['status'] as String);
      final indexB = statusOrder.indexOf(b['status'] as String);
      if (indexA != indexB) return indexA.compareTo(indexB);
      
      // Oldest first for urgent items
      final tsA = a['earliestNewTimestamp'] as Timestamp?;
      final tsB = b['earliestNewTimestamp'] as Timestamp?;
      if (tsA != null && tsB != null) {
        return tsA.compareTo(tsB);
      }
      return 0;
    });
    
    return usersWithStatus;
  }
  
  /// Batch-load documents by IDs (Firestore allows up to 10 in whereIn)
  Future<Map<String, Map<String, dynamic>>> _batchGetDocuments(
      String collection, List<String> ids) async {
    if (ids.isEmpty) return {};
    
    final Map<String, Map<String, dynamic>> results = {};
    
    // Firestore whereIn is limited to 10 items, so batch them
    for (var i = 0; i < ids.length; i += 10) {
      final batchIds = ids.skip(i).take(10).toList();
      final snapshot = await FirebaseFirestore.instance
          .collection(collection)
          .where(FieldPath.documentId, whereIn: batchIds)
          .get();
      
      for (var doc in snapshot.docs) {
        results[doc.id] = doc.data();
      }
    }
    
    return results;
  }
  
  /// Map order status to display status
  String _mapOrderStatusToDisplayStatus(String status, dynamic albumId) {
    switch (status) {
      case 'new':
        return 'new';
      case 'curator_assigned':
        return 'curator_assigned';
      case 'in_progress':
        // If album selected during in_progress, show as album_selected
        if (albumId != null && albumId.toString().isNotEmpty) {
          return 'album_selected';
        }
        return 'in_progress';
      case 'ready_to_ship':
        return 'ready_to_ship';
      case 'sent':
        return 'sent';
      case 'returned':
        return 'returned';
      default:
        return 'none';
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
                    decoration:
                        TextDecoration.underline, // Optional visual indication
                  ),
                ),
              ),
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
                    Text('Orders:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
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
                            readyToShipOrders.isNotEmpty
                                ? readyToShipOrders.first
                                : null;

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
                            final lastOrderData = olderOrders.first.data()
                                as Map<String, dynamic>?;
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
                                  Text(
                                      'Status: ${orderData['status'] ?? 'N/A'}'),
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
                          final orderData = newestReadyToShipOrder.data()
                              as Map<String, dynamic>;
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
                                  Text(
                                      'Status: ${orderData['status'] ?? 'N/A'}'),
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
                          final isReturned = (status == 'returned') &&
                              !(data['returnConfirmed'] ?? false);

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
                                      title: Text(
                                          'Older Order (No album assigned)'),
                                      subtitle: Text('Status: $status'),
                                    );
                                  }
                                  final albumData = albumSnapshot.data!.data()
                                      as Map<String, dynamic>;
                                  final artist =
                                      albumData['artist'] ?? 'Unknown';
                                  final name =
                                      albumData['albumName'] ?? 'Unknown';
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
                      child: Text(
                          showWishlist ? 'Hide Wishlist' : 'Show Wishlist'),
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
    // If the order is 'new' => "Select Album" button
    else if (order['status'] == 'new') {
      return ElevatedButton(
        onPressed: () {
          _showSelectAlbumDialog(orderId, order['address'], userId);
        },
        child: Text('Select Album'),
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
                  _buildTextField(
                      'Release Year', (value) => _releaseYear = value),
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

  void _showSelectAlbumDialog(String orderId, String address, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminAlbumSelectionScreen(
          orderId: orderId,
          orderData: {'address': address, 'userId': userId},
          onAlbumSelected: (albumId, albumData) {
            _selectAlbumForOrder(orderId, albumId, albumData);
          },
        ),
      ),
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

  Future<void> _selectAlbumForOrder(
      String orderId, String albumId, Map<String, dynamic> albumData) async {
    try {
      await _firestoreService.updateOrderWithAlbum(orderId, albumId);

      // Refresh the admin dashboard data
      await _refreshData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Album "${albumData['albumName']}" by ${albumData['artist']} selected! Ready to ship.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting album: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      // Get the order to check if it has a curator
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      final orderData = orderDoc.data();
      final curatorId = orderData?['curatorId'] as String?;

      // Award 1 free order credit to the curator for completing the order BEFORE marking as sent
      // This ensures the credit is awarded even if the order update fails
      bool creditAwarded = false;
      if (curatorId != null && curatorId.isNotEmpty) {
        try {
          print(
              'Awarding 1 credit to curator $curatorId for completing order $orderId');
          await HomeScreen.addFreeOrderCredits(curatorId, 1);
          creditAwarded = true;
          print('Successfully awarded credit to curator $curatorId');
        } catch (e) {
          print('Error awarding credit to curator: $e');
          // Don't fail the whole operation if credit award fails
        }
      }

      // Update order status from 'ready_to_ship' to 'sent'
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': 'sent',
        'shippedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'curatorCreditAwarded': creditAwarded, // Track if curator was paid
        'curatorCreditAwardedAt':
            creditAwarded ? FieldValue.serverTimestamp() : null,
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
