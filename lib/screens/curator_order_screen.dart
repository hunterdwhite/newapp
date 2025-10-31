import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/star_rating_widget.dart';
import '../services/curator_service.dart';
import 'public_profile_screen.dart';
import 'product_details_screen.dart';

class CuratorOrderScreen extends StatefulWidget {
  @override
  _CuratorOrderScreenState createState() => _CuratorOrderScreenState();
}

class _CuratorOrderScreenState extends State<CuratorOrderScreen> {
  final TextEditingController _searchController = TextEditingController();
  final CuratorService _curatorService = CuratorService();
  
  List<Map<String, dynamic>> _favoriteCurators = [];
  List<Map<String, dynamic>> _featuredCurators = [];
  List<Map<String, dynamic>> _allCurators = [];
  List<Map<String, dynamic>> _searchResults = [];
  
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCurators();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim();
      _isSearching = _searchQuery.isNotEmpty;
    });
    
    if (_searchQuery.isNotEmpty) {
      _performSearch(_searchQuery);
    }
  }

  Future<void> _loadCurators() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Load favorite curators
      final favoriteCurators = await _curatorService.getFavoriteCurators(user.uid);
      
      // Enrich favorite curators with stats (order count, rating, review count)
      for (var curator in favoriteCurators) {
        final orderCount = await _getCuratorOrderCount(curator['userId']);
        curator['orderCount'] = orderCount;
        
        // Get rating information
        final ratingInfo = await _curatorService.getCuratorRating(curator['userId']);
        curator['rating'] = ratingInfo['rating'];
        curator['reviewCount'] = ratingInfo['reviewCount'];
        
        curator['isFeatured'] = curator['isFeatured'] ?? false;
      }
      
      // Load all curators with order counts and featured status
      final allCurators = await _loadCuratorsWithStats();
      
      // Separate featured curators
      final featuredCurators = allCurators.where((curator) => curator['isFeatured'] == true).toList();
      
      // Sort curators by order count (descending)
      favoriteCurators.sort((a, b) => (b['orderCount'] as int).compareTo(a['orderCount'] as int));
      allCurators.sort((a, b) => (b['orderCount'] as int).compareTo(a['orderCount'] as int));
      featuredCurators.sort((a, b) => (b['orderCount'] as int).compareTo(a['orderCount'] as int));

      // Check if widget is still mounted before calling setState
      if (!mounted) return;
      
      setState(() {
        _favoriteCurators = favoriteCurators;
        _featuredCurators = featuredCurators;
        _allCurators = allCurators;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading curators: $e');
      
      // Check if widget is still mounted before calling setState
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadCuratorsWithStats() async {
    try {
      // Get all curators
      final curators = await _curatorService.getAllCurators(limit: 100);
      
      // Add order count, featured status, and rating to each curator
      for (var curator in curators) {
        // Get order count for this curator
        final orderCount = await _getCuratorOrderCount(curator['userId']);
        curator['orderCount'] = orderCount;
        
        // Get rating information
        final ratingInfo = await _curatorService.getCuratorRating(curator['userId']);
        curator['rating'] = ratingInfo['rating'];
        curator['reviewCount'] = ratingInfo['reviewCount'];
        
        // Check if curator is featured (you can add this field to user documents)
        curator['isFeatured'] = curator['isFeatured'] ?? false;
      }
      
      return curators;
    } catch (e) {
      print('Error loading curators with stats: $e');
      return [];
    }
  }

  Future<int> _getCuratorOrderCount(String curatorId) async {
    try {
      // Force fresh data from server, not cache
      // Only count truly completed orders: kept and returnedConfirmed
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('curatorId', isEqualTo: curatorId)
          .where('status', whereIn: ['kept', 'returnedConfirmed'])
          .get(const GetOptions(source: Source.server));
      
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting curator order count: $e');
      return 0;
    }
  }

  Future<void> _performSearch(String query) async {
    try {
      final results = await _curatorService.searchCurators(query);
      
      // Add order counts and ratings to search results
      for (var curator in results) {
        final orderCount = await _getCuratorOrderCount(curator['userId']);
        curator['orderCount'] = orderCount;
        
        // Get rating information
        final ratingInfo = await _curatorService.getCuratorRating(curator['userId']);
        curator['rating'] = ratingInfo['rating'];
        curator['reviewCount'] = ratingInfo['reviewCount'];
        
        curator['isFeatured'] = curator['isFeatured'] ?? false;
      }
      
      // Sort search results by order count
      results.sort((a, b) => (b['orderCount'] as int).compareTo(a['orderCount'] as int));
      
      // Check if widget is still mounted before calling setState
      if (!mounted) return;
      
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Error performing search: $e');
      
      // Check if widget is still mounted before calling setState
      if (!mounted) return;
      
      setState(() {
        _searchResults = [];
      });
    }
  }

  void _selectCurator(Map<String, dynamic> curator) {
    // Navigate to product details screen with selected curator
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(
          productType: 'community',
          curatorId: curator['userId'],
        ),
      ),
    );
  }

  void _viewCuratorProfile(Map<String, dynamic> curator) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfileScreen(userId: curator['userId']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GrainyBackgroundWidget(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _refreshCurators,
                        child: _buildCuratorList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshCurators() async {
    // Check if widget is still mounted before calling setState
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    await _loadCurators();
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              '<',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Choose Your Curator',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151515),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search curators by username...',
            hintStyle: TextStyle(color: Colors.white54),
            prefixIcon: Icon(Icons.search, color: Colors.white54),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCuratorList() {
    if (_isSearching) {
      return _buildSearchResults();
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_favoriteCurators.isNotEmpty) ...[
            _buildSectionHeader('Your Favorite Curators', Icons.star),
            _buildCuratorSection(_favoriteCurators),
            const SizedBox(height: 24),
          ],
          if (_featuredCurators.isNotEmpty) ...[
            _buildSectionHeader('Featured Curators', Icons.verified),
            _buildCuratorSection(_featuredCurators),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('All Curators', Icons.people),
          _buildCuratorSection(_allCurators),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No curators found',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Search Results', Icons.search),
          _buildCuratorSection(_searchResults),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE46A14), size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuratorSection(List<Map<String, dynamic>> curators) {
    if (curators.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16.0),
        child: Text(
          'No curators available',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Column(
      children: curators.map((curator) => _buildCuratorCard(curator)).toList(),
    );
  }

  Widget _buildCuratorCard(Map<String, dynamic> curator) {
    final orderCount = curator['orderCount'] as int? ?? 0;
    final isFeatured = curator['isFeatured'] as bool? ?? false;
    final bio = curator['bio'] as String? ?? '';
    final favoriteGenres = List<String>.from(curator['favoriteGenres'] ?? []);
    final rating = (curator['rating'] as num?)?.toDouble() ?? 0.0;
    final reviewCount = curator['reviewCount'] as int? ?? 0;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCurrentUser = currentUser != null && curator['userId'] == currentUser.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFeatured ? const Color(0xFFE46A14) : Colors.white24,
          width: isFeatured ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Profile picture placeholder
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: curator['profilePictureUrl'] != null
                        ? Image.network(
                            curator['profilePictureUrl'],
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.person,
                              color: Colors.white54,
                              size: 30,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              curator['username'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE46A14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'CURATOR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isFeatured) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              color: Color(0xFFE46A14),
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          StarRatingWidget(
                            rating: rating,
                            size: 14,
                            totalReviews: reviewCount,
                            showRatingText: reviewCount > 0,
                          ),
                          if (reviewCount == 0) ...[
                            const Text(
                              'No reviews yet',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$orderCount orders completed',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white54),
                  onPressed: () => _viewCuratorProfile(curator),
                ),
              ],
            ),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                bio,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (favoriteGenres.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: favoriteGenres.take(3).map((genre) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE46A14).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE46A14), width: 1),
                    ),
                    child: Text(
                      genre,
                      style: const TextStyle(
                        color: Color(0xFFE46A14),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCurrentUser ? null : () => _selectCurator(curator),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCurrentUser ? Colors.grey[600] : const Color(0xFFE46A14),
                  foregroundColor: isCurrentUser ? Colors.grey[400] : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  isCurrentUser ? 'Cannot Order From Yourself' : 'Select This Curator',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isCurrentUser ? Colors.grey[400] : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
