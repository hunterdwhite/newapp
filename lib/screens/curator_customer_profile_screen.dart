import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../services/firestore_service.dart';

class CuratorCustomerProfileScreen extends StatefulWidget {
  final String userId;

  const CuratorCustomerProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _CuratorCustomerProfileScreenState createState() => _CuratorCustomerProfileScreenState();
}

class _CuratorCustomerProfileScreenState extends State<CuratorCustomerProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  List<DocumentSnapshot> _userOrders = [];
  List<DocumentSnapshot> _userWishlist = [];

  @override
  void initState() {
    super.initState();
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    try {
      // Load user data
      final userDoc = await _firestoreService.getUserDoc(widget.userId);
      if (userDoc != null && userDoc.exists) {
        _userData = userDoc.data() as Map<String, dynamic>;
      }

      // Load user orders (for order history context)
      _userOrders = await _firestoreService.getOrdersForUser(widget.userId);

      // Load user wishlist
      _userWishlist = await _firestoreService.getWishlistForUser(widget.userId);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading customer data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Profile'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: GrainyBackgroundWidget(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _userData == null
                ? const Center(
                    child: Text(
                      'Customer data not found',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : _buildCustomerProfile(),
      ),
    );
  }

  Widget _buildCustomerProfile() {
    final username = _userData!['username'] ?? 'Unknown User';
    final email = _userData!['email'] ?? 'No email';
    final profileCustomization = _userData!['profileCustomization'] as Map<String, dynamic>?;
    final tasteProfile = _userData!['tasteProfile'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(username, email, profileCustomization),
          const SizedBox(height: 24),
          
          // Taste Profile Section
          _buildTasteProfileSection(tasteProfile),
          const SizedBox(height: 24),
          
          // Order History Section
          _buildOrderHistorySection(),
          const SizedBox(height: 24),
          
          // Wishlist Section
          _buildWishlistSection(),
        ],
      ),
    );
  }

  Widget _buildHeader(String username, String email, Map<String, dynamic>? profileCustomization) {
    final bio = profileCustomization?['bio'] as String?;
    final favoriteGenres = profileCustomization?['favoriteGenres'] as List<dynamic>?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.orangeAccent,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Bio:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bio,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
          if (favoriteGenres != null && favoriteGenres.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Favorite Genres:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: favoriteGenres.map((genre) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.2),
                    border: Border.all(color: Colors.orangeAccent, width: 1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    genre.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orangeAccent,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTasteProfileSection(Map<String, dynamic>? tasteProfile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.orangeAccent, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Taste Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orangeAccent,
            ),
          ),
          const SizedBox(height: 16),
          if (tasteProfile == null) ...[
            const Text(
              'No taste profile available',
              style: TextStyle(color: Colors.white70),
            ),
          ] else ...[
            _buildTasteProfileItem('Genres', tasteProfile['genres']),
            const SizedBox(height: 12),
            _buildTasteProfileItem('Decades', tasteProfile['decades']),
            const SizedBox(height: 12),
            _buildTasteProfileItem('Albums Listened', tasteProfile['albumsListened']),
            const SizedBox(height: 12),
            _buildTasteProfileItem('Musical Bio', tasteProfile['musicalBio']),
          ],
        ],
      ),
    );
  }

  Widget _buildTasteProfileItem(String label, dynamic value) {
    String displayValue;
    
    if (value is List) {
      displayValue = value.isNotEmpty ? value.join(', ') : 'Not specified';
    } else if (value is String) {
      displayValue = value.isNotEmpty ? value : 'Not specified';
    } else {
      displayValue = 'Not specified';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          displayValue,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderHistorySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order History (${_userOrders.length} orders)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (_userOrders.isEmpty) ...[
            const Text(
              'No previous orders',
              style: TextStyle(color: Colors.white70),
            ),
          ] else ...[
            ..._userOrders.take(5).map((orderDoc) {
              final orderData = orderDoc.data() as Map<String, dynamic>;
              final status = orderData['status'] ?? 'Unknown';
              final timestamp = orderData['timestamp'] as Timestamp?;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Order ${orderDoc.id.substring(0, 8)} - $status',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    if (timestamp != null)
                      Text(
                        _formatDate(timestamp.toDate()),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
            if (_userOrders.length > 5)
              Text(
                '... and ${_userOrders.length - 5} more orders',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWishlistSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wishlist (${_userWishlist.length} items)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (_userWishlist.isEmpty) ...[
            const Text(
              'No wishlist items',
              style: TextStyle(color: Colors.white70),
            ),
          ] else ...[
            ..._userWishlist.take(10).map((wishlistDoc) {
              final wishlistData = wishlistDoc.data() as Map<String, dynamic>;
              final albumName = wishlistData['albumName'] ?? 'Unknown Album';
              final artist = wishlistData['artist'] ?? 'Unknown Artist';
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.music_note,
                      color: Colors.orangeAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$artist - $albumName',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            if (_userWishlist.length > 10)
              Text(
                '... and ${_userWishlist.length - 10} more items',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return Colors.green;
      case 'sent':
        return Colors.yellow;
      case 'delivered':
        return Colors.blue;
      case 'returned':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }
}
