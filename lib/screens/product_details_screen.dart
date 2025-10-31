import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/grainy_background_widget.dart';
import '../widgets/retro_button_widget.dart';
import '../services/firestore_service.dart';
import '../services/pricing_service.dart';
import 'cart_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productType;
  final String? curatorId;

  const ProductDetailsScreen({
    Key? key,
    required this.productType,
    this.curatorId,
  }) : super(key: key);

  @override
  _ProductDetailsScreenState createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final PricingService _pricingService = PricingService();
  
  double? _selectedPrice;
  String _selectedPriceLabel = '';
  Map<String, dynamic>? _curatorInfo;
  bool _isLoadingCurator = false;
  bool _hasFreeOrder = false;
  List<double> _priceOptions = [];
  bool _isLoadingPrices = true;

  final Map<String, Map<String, dynamic>> _productInfo = {
    'dissonant': {
      'title': 'Dissonant Curated Experience',
      'subtitle': 'Expert-selected music discovery',
      'description': 'Our team of music experts handpicks albums from across genres and eras, focusing on both trending releases and timeless classics. Each selection is carefully chosen to expand your musical horizons.',
      'icon': 'assets/dissonantordericon.png',
      'features': [
        'Curated by music industry professionals',
        'Mix of new releases and classic albums',
        'Detailed liner notes and background info',
        'Surprise selections you\'ll love',
        'Quality guarantee - love it or return it',
      ],
    },
    'community': {
      'title': 'Community Curated Experience',
      'subtitle': 'Personal recommendations from real music lovers',
      'description': 'Connect with passionate music enthusiasts in our community. Each curator brings their unique taste and perspective, offering personalized recommendations based on your preferences.',
      'icon': 'assets/curateicon.png',
      'features': [
        'Personal curator selection',
        'Direct communication with your curator',
        'Tailored to your specific tastes',
        'Community-driven discovery',
        'Build lasting music connections',
      ],
    },
  };


  @override
  void initState() {
    super.initState();
    _loadPricing();
    _loadUserData();
    if (widget.curatorId != null) {
      _loadCuratorInfo();
    }
  }

  Future<void> _loadPricing() async {
    try {
      final priceOptions = await _pricingService.getPriceOptions(widget.productType);
      if (mounted) {
        setState(() {
          _priceOptions = priceOptions;
          _isLoadingPrices = false;
        });
      }
    } catch (e) {
      print('Error loading pricing: $e');
      // Fallback to default prices
      if (mounted) {
        setState(() {
          _priceOptions = widget.productType == 'community' 
            ? [5.99, 7.99, 9.99] 
            : [7.99, 9.99, 12.99];
          _isLoadingPrices = false;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirestoreService().getUserDoc(user.uid);
      if (userDoc != null && userDoc.exists) {
        final docData = userDoc.data() as Map<String, dynamic>?;
        if (docData != null) {
          if (!mounted) return;
          setState(() {
            // Free orders only apply to community curator orders, not Dissonant orders
            _hasFreeOrder = (docData['freeOrder'] ?? false) && widget.productType == 'community';
            // If user has free order for community curator, set a default price for cart functionality
            if (_hasFreeOrder) {
              _selectedPrice = 0.0;
              _selectedPriceLabel = 'FREE';
            }
          });
        }
      }
    }
  }

  Future<void> _loadCuratorInfo() async {
    if (widget.curatorId == null) return;
    
    setState(() {
      _isLoadingCurator = true;
    });

    try {
      // Load curator data directly from users collection (same as curator service)
      final curatorDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.curatorId!)
          .get();
      
      if (curatorDoc.exists && mounted) {
        final userData = curatorDoc.data() as Map<String, dynamic>;
        final profileCustomization = userData['profileCustomization'] as Map<String, dynamic>?;
        
        final curatorInfo = {
          'userId': widget.curatorId!,
          'username': userData['username'] ?? 'Unknown',
          'profilePictureUrl': userData['profilePictureUrl'],
          'bio': profileCustomization?['bio'] ?? '',
          'favoriteGenres': List<String>.from(profileCustomization?['favoriteGenres'] ?? []),
        };
        
        setState(() {
          _curatorInfo = curatorInfo;
          _isLoadingCurator = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCurator = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productInfo = _productInfo[widget.productType] ?? _productInfo['dissonant']!;
    
    return Scaffold(
      body: GrainyBackgroundWidget(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProductHeader(productInfo),
                      SizedBox(height: 24),
                      if (widget.curatorId != null) ...[
                        _buildCuratorInfo(),
                        SizedBox(height: 24),
                      ],
                      _buildProductDescription(productInfo),
                      SizedBox(height: 24),
                      _buildPriceSelection(),
                      SizedBox(height: 24),
                      _buildAddToCartButton(),
                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text(
              '<',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 16),
          Text(
            'Curation Type',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeader(Map<String, dynamic> productInfo) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                productInfo['icon'],
                fit: BoxFit.contain,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.productType == 'community' ? 'Community Curation' : 'Dissonant Curation',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuratorInfo() {
    if (_isLoadingCurator) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
          ),
        ),
      );
    }

    if (_curatorInfo == null) {
      return SizedBox.shrink();
    }

    final username = _curatorInfo!['username'] ?? 'Unknown Curator';
    final bio = _curatorInfo!['bio'] ?? '';
    final favoriteGenres = List<String>.from(_curatorInfo!['favoriteGenres'] ?? []);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: Colors.orangeAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Curated By',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              // Profile picture
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.orangeAccent, width: 2),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: ClipOval(
                  child: _curatorInfo!['profilePictureUrl'] != null && _curatorInfo!['profilePictureUrl'].isNotEmpty
                    ? Image.network(
                        _curatorInfo!['profilePictureUrl'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            color: Colors.orangeAccent,
                            size: 24,
                          );
                        },
                      )
                    : Icon(
                        Icons.person,
                        color: Colors.orangeAccent,
                        size: 24,
                      ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  username,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (bio.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              bio,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
          if (favoriteGenres.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              'Favorite Genres:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: favoriteGenres.take(3).map((genre) {
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orangeAccent, width: 1),
                  ),
                  child: Text(
                    genre,
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
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

  Widget _buildProductDescription(Map<String, dynamic> productInfo) {
    final String description = widget.productType == 'community' 
      ? 'An album selected by your chosen curator along with a digital note explaining why they chose it for you!'
      : 'An album hand picked by a member of the Dissonant team along with a handwritten note explaining why we chose it for you!';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildPriceSelection() {
    if (_hasFreeOrder) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_giftcard, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  'Your Order is Free!',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'You have a free credit that covers the full cost of this community curator order. No payment required!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'FREE',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingPrices) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pay What You Can Afford',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Select Price:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<double>(
                value: _selectedPrice,
                hint: Text(
                  _priceOptions.isEmpty ? 'Loading prices...' : 'Choose a price...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white54,
                  ),
                ),
                items: _priceOptions.map((price) {
                  return DropdownMenuItem<double>(
                    value: price,
                    child: Text(
                      '\$${price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: _priceOptions.isEmpty ? null : (double? newValue) {
                  setState(() {
                    _selectedPrice = newValue;
                    _selectedPriceLabel = newValue != null ? '\$${newValue.toStringAsFixed(2)}' : '';
                  });
                },
                icon: Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
                dropdownColor: Color(0xFF2A2A2A),
                style: TextStyle(color: Colors.white),
                isExpanded: true,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildAddToCartButton() {
    final canAddToCart = _selectedPrice != null;
    
    if (_hasFreeOrder) {
      return RetroButtonWidget(
        text: 'Add Free Order to Cart',
        onPressed: _addToCart,
        style: RetroButtonStyle.light,
        customWidth: double.infinity,
      );
    }
    
    return RetroButtonWidget(
      text: canAddToCart 
        ? 'Add to Cart - \$${_selectedPrice!.toStringAsFixed(2)}'
        : 'Select a price option',
      onPressed: canAddToCart ? _addToCart : null,
      style: RetroButtonStyle.light,
      customWidth: double.infinity,
    );
  }

  void _addToCart() {
    if (_selectedPrice == null) return;
    
    // Navigate to cart screen with selected product
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          productType: widget.productType,
          selectedPrice: _selectedPrice!,
          priceLabel: _selectedPriceLabel,
          curatorId: widget.curatorId,
        ),
      ),
    );
  }
}
