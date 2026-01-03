import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CuratorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get favorite curators for a specific user
  Future<List<Map<String, dynamic>>> getFavoriteCurators(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return [];

      final userData = userDoc.data() as Map<String, dynamic>;
      final favoriteCuratorIds = List<String>.from(userData['favoriteCurators'] ?? []);
      
      if (favoriteCuratorIds.isEmpty) return [];

      final curators = <Map<String, dynamic>>[];
      
      // Get each favorite curator's profile
      for (final curatorId in favoriteCuratorIds) {
        final curatorDoc = await _firestore.collection('users').doc(curatorId).get();
        if (curatorDoc.exists) {
          final curatorData = curatorDoc.data() as Map<String, dynamic>;
          if (curatorData['isCurator'] == true) {
            final profileCustomization = curatorData['profileCustomization'] as Map<String, dynamic>?;
            final bio = profileCustomization?['bio'] ?? '';
            final favoriteGenres = List<String>.from(profileCustomization?['favoriteGenres'] ?? []);
            
            curators.add({
              'userId': curatorId,
              'username': curatorData['username'] ?? 'Unknown',
              'profilePictureUrl': curatorData['profilePictureUrl'],
              'bio': bio,
              'favoriteGenres': favoriteGenres,
              'curatorJoinedAt': curatorData['curatorJoinedAt'],
              'isFeatured': curatorData['isFeatured'] ?? false,
            });
          }
        }
      }
      
      return curators;
    } catch (e) {
      print('Error getting favorite curators: $e');
      return [];
    }
  }

  /// Get all curators with optional limit
  Future<List<Map<String, dynamic>>> getAllCurators({int limit = 100}) async {
    try {
      Query query = _firestore
          .collection('users')
          .where('isCurator', isEqualTo: true);
      
      if (limit > 0) {
        query = query.limit(limit);
      }
      
      final snapshot = await query.get();
      final curators = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final userData = doc.data() as Map<String, dynamic>;
        final profileCustomization = userData['profileCustomization'] as Map<String, dynamic>?;
        final bio = profileCustomization?['bio'] ?? '';
        final favoriteGenres = List<String>.from(profileCustomization?['favoriteGenres'] ?? []);
        
        curators.add({
          'userId': doc.id,
          'username': userData['username'] ?? 'Unknown',
          'profilePictureUrl': userData['profilePictureUrl'],
          'bio': bio,
          'favoriteGenres': favoriteGenres,
          'curatorJoinedAt': userData['curatorJoinedAt'],
          'isFeatured': userData['isFeatured'] ?? false,
        });
      }
      
      return curators;
    } catch (e) {
      print('Error getting all curators: $e');
      return [];
    }
  }

  /// Get all curators for client-side pagination
  /// Returns list of all curators sorted by orderCount (most popular first)
  /// Pagination is done client-side to avoid needing a Firestore composite index
  Future<List<Map<String, dynamic>>> getAllCuratorsForPagination() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isCurator', isEqualTo: true)
          .get();
      
      final curators = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final userData = doc.data();
        final profileCustomization = userData['profileCustomization'] as Map<String, dynamic>?;
        final bio = profileCustomization?['bio'] ?? '';
        final favoriteGenres = List<String>.from(profileCustomization?['favoriteGenres'] ?? []);
        
        curators.add({
          'userId': doc.id,
          'username': userData['username'] ?? 'Unknown',
          'profilePictureUrl': userData['profilePictureUrl'],
          'bio': bio,
          'favoriteGenres': favoriteGenres,
          'curatorJoinedAt': userData['curatorJoinedAt'],
          'isFeatured': userData['isFeatured'] ?? false,
          // Read denormalized orderCount for consistent initial sorting
          'orderCount': userData['curatorOrderCount'] ?? 0,
          'averageRating': userData['curatorAverageRating'] ?? 0.0,
          'reviewCount': userData['curatorReviewCount'] ?? 0,
        });
      }
      
      // Sort by order count (most popular first) for consistent ordering
      curators.sort((a, b) => (b['orderCount'] as int).compareTo(a['orderCount'] as int));
      
      return curators;
    } catch (e) {
      print('Error getting all curators for pagination: $e');
      return [];
    }
  }
  
  /// Update curator stats on their user document (denormalization for fast queries)
  /// This should be called when an order is completed
  Future<void> updateCuratorStats(String curatorId) async {
    try {
      // Count completed orders
      final ordersSnapshot = await _firestore
          .collection('orders')
          .where('curatorId', isEqualTo: curatorId)
          .where('status', whereIn: ['kept', 'returnedConfirmed'])
          .get();
      
      final orderCount = ordersSnapshot.docs.length;
      
      // Calculate average rating from curatorReviews subcollection
      final reviewsSnapshot = await _firestore
          .collection('users')
          .doc(curatorId)
          .collection('curatorReviews')
          .get();
      
      double averageRating = 0.0;
      int reviewCount = reviewsSnapshot.docs.length;
      
      if (reviewCount > 0) {
        double totalRating = 0;
        for (final doc in reviewsSnapshot.docs) {
          totalRating += (doc.data()['rating'] ?? 0).toDouble();
        }
        averageRating = totalRating / reviewCount;
      }
      
      // Update denormalized fields on user document
      await _firestore.collection('users').doc(curatorId).update({
        'curatorOrderCount': orderCount,
        'curatorAverageRating': averageRating,
        'curatorReviewCount': reviewCount,
      });
      
      print('Updated curator stats for $curatorId: $orderCount orders, $averageRating avg rating');
    } catch (e) {
      print('Error updating curator stats: $e');
    }
  }

  /// Search curators by username, bio, or favorite genres
  Future<List<Map<String, dynamic>>> searchCurators(String query) async {
    if (query.trim().isEmpty) return getAllCurators();

    try {
      final queryLower = query.toLowerCase();
      
      // Get all curators and filter client-side (Firestore doesn't support complex text search)
      final allCurators = await getAllCurators(limit: 100);
      
      return allCurators.where((curator) {
        final username = (curator['username'] as String).toLowerCase();
        final bio = (curator['bio'] as String).toLowerCase();
        final favoriteGenres = (curator['favoriteGenres'] as List<String>)
            .map((s) => s.toLowerCase()).toList();
        
        return username.contains(queryLower) ||
               bio.contains(queryLower) ||
               favoriteGenres.any((genre) => genre.contains(queryLower));
      }).toList();
    } catch (e) {
      print('Error searching curators: $e');
      return [];
    }
  }

  /// Add curator to favorites
  Future<bool> addToFavorites(String curatorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'favoriteCurators': FieldValue.arrayUnion([curatorId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error adding curator to favorites: $e');
      return false;
    }
  }

  /// Remove curator from favorites
  Future<bool> removeFromFavorites(String curatorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'favoriteCurators': FieldValue.arrayRemove([curatorId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error removing curator from favorites: $e');
      return false;
    }
  }

  /// Check if a curator is favorited by current user
  Future<bool> isFavorited(String curatorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final favoriteCurators = List<String>.from(userData['favoriteCurators'] ?? []);
        return favoriteCurators.contains(curatorId);
      }
    } catch (e) {
      print('Error checking if curator is favorited: $e');
    }
    return false;
  }

  /// Get curator order count
  Future<int> getCuratorOrderCount(String curatorId) async {
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('curatorId', isEqualTo: curatorId)
          .where('status', whereIn: ['kept', 'returned', 'returnedConfirmed'])
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting curator order count: $e');
      return 0;
    }
  }

  /// Get curator rating and review count
  Future<Map<String, dynamic>> getCuratorRating(String curatorId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(curatorId)
          .collection('curatorReviews')
          .get();
      
      if (snapshot.docs.isEmpty) {
        return {'rating': 0.0, 'reviewCount': 0};
      }

      double totalRating = 0;
      int reviewCount = snapshot.docs.length;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        totalRating += (data['rating'] as num).toDouble();
      }
      
      double averageRating = totalRating / reviewCount;
      
      return {
        'rating': averageRating,
        'reviewCount': reviewCount,
      };
    } catch (e) {
      print('Error getting curator rating: $e');
      return {'rating': 0.0, 'reviewCount': 0};
    }
  }

  /// Get curator reviews with order details
  Future<List<Map<String, dynamic>>> getCuratorReviews(String curatorId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(curatorId)
          .collection('curatorReviews')
          .orderBy('timestamp', descending: true)
          .get();
      
      final reviews = <Map<String, dynamic>>[];
      
      for (final doc in snapshot.docs) {
        final reviewData = doc.data();
        
        // Get order details
        final orderDoc = await _firestore
            .collection('orders')
            .doc(reviewData['orderId'])
            .get();
        
        // Get album details if available
        Map<String, dynamic>? albumData;
        if (orderDoc.exists) {
          final orderData = orderDoc.data() as Map<String, dynamic>;
          final albumId = orderData['albumId'];
          if (albumId != null) {
            final albumDoc = await _firestore
                .collection('albums')
                .doc(albumId)
                .get();
            if (albumDoc.exists) {
              albumData = albumDoc.data() as Map<String, dynamic>;
            }
          }
        }
        
        // Get reviewer username
        String reviewerUsername = 'Anonymous';
        if (reviewData['userId'] != null) {
          final userDoc = await _firestore
              .collection('users')
              .doc(reviewData['userId'])
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            reviewerUsername = userData['username'] ?? 'Anonymous';
          }
        }
        
        reviews.add({
          'reviewId': doc.id,
          'rating': reviewData['rating'],
          'comment': reviewData['comment'] ?? '',
          'createdAt': reviewData['timestamp'],
          'reviewerUsername': reviewerUsername,
          'albumTitle': albumData?['albumName'] ?? 'Unknown Album',
          'albumArtist': albumData?['artist'] ?? 'Unknown Artist',
          'albumCoverUrl': albumData?['coverUrl'],
        });
      }
      
      return reviews;
    } catch (e) {
      print('Error getting curator reviews: $e');
      return [];
    }
  }

  /// Submit a review for a curator
  Future<bool> submitCuratorReview({
    required String curatorId,
    required String orderId,
    required int rating,
    String? comment,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check if review already exists for this order
      final existingReview = await _firestore
          .collection('users')
          .doc(curatorId)
          .collection('curatorReviews')
          .where('orderId', isEqualTo: orderId)
          .where('userId', isEqualTo: user.uid)
          .get();
      
      if (existingReview.docs.isNotEmpty) {
        // Update existing review
        await _firestore
            .collection('users')
            .doc(curatorId)
            .collection('curatorReviews')
            .doc(existingReview.docs.first.id)
            .update({
          'rating': rating,
          'comment': comment ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Create new review
        await _firestore
            .collection('users')
            .doc(curatorId)
            .collection('curatorReviews')
            .add({
          'orderId': orderId,
          'userId': user.uid,
          'rating': rating,
          'comment': comment ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
      return true;
    } catch (e) {
      print('Error submitting curator review: $e');
      return false;
    }
  }
}