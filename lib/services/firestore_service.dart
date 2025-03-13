// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// ------------------------
  /// Existing Methods
  /// ------------------------

  // Check if a username exists in the usernames collection
  Future<bool> checkUsernameExists(String username) async {
    final doc = await _firestore.collection('usernames').doc(username).get();
    return doc.exists;
  }

  // Add a username to the usernames collection
  Future<void> addUsername(String username, String userId) async {
    await _firestore.collection('usernames').doc(username).set({
      'userId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> hasOutstandingOrders(String userId) async {
    QuerySnapshot ordersSnapshot = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('status', whereIn: ['sent', 'returned'])
        .get();

    return ordersSnapshot.docs.isNotEmpty;
  }

  Future<void> deleteUserData(String userId) async {
    WriteBatch batch = _firestore.batch();

    // Delete user document in 'users' collection
    DocumentReference userDocRef = _firestore.collection('users').doc(userId);
    batch.delete(userDocRef);

    // Delete public profile
    DocumentReference publicProfileRef = userDocRef.collection('public').doc('profile');
    batch.delete(publicProfileRef);

    // Remove username from 'usernames' collection
    // First, get the username
    DocumentSnapshot publicProfileDoc = await publicProfileRef.get();
    if (publicProfileDoc.exists && publicProfileDoc.data() != null) {
      String username = publicProfileDoc['username'];
      DocumentReference usernameDocRef = _firestore.collection('usernames').doc(username);
      batch.delete(usernameDocRef);
    }

    // Delete user's wishlist items
    CollectionReference wishlistRef = userDocRef.collection('wishlist');
    QuerySnapshot wishlistSnapshot = await wishlistRef.get();
    for (DocumentSnapshot doc in wishlistSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete user's orders
    QuerySnapshot ordersSnapshot = await _firestore.collection('orders').where('userId', isEqualTo: userId).get();
    for (DocumentSnapshot doc in ordersSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Commit the batch
    await batch.commit();
  }

  Future<Map<String, dynamic>?> getUserPublicProfile(String userId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('public')
        .doc('profile')
        .get();
    return doc.data();
  }

  Future<DocumentSnapshot?> getOrderById(String orderId) async {
    final doc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .get();
    return doc.exists ? doc : null;
  }

  Future<void> addReview({
    required String albumId,
    required String userId,
    required String orderId,
    required String comment,
  }) {
    final reviewRef = FirebaseFirestore.instance
        .collection('albums')
        .doc(albumId)
        .collection('reviews')
        .doc();
    return reviewRef.set({
      'userId': userId,
      'orderId': orderId,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateReview({
    required String albumId,
    required String reviewId,
    required String comment,
  }) {
    return FirebaseFirestore.instance
        .collection('albums')
        .doc(albumId)
        .collection('reviews')
        .doc(reviewId)
        .update({'comment': comment, 'timestamp': FieldValue.serverTimestamp()});
  }

  // Remove a username from the usernames collection
  Future<void> removeUsername(String username) async {
    await _firestore.collection('usernames').doc(username).delete();
  }

  /// Cast a new genre vote for a user.
  /// This method should only be called if the user hasn't voted yet.
  Future<void> castGenreVote({
    required String albumId,
    required String userId,
    required String chosenGenre,
  }) async {
    final albumRef = _firestore.collection('albums').doc(albumId);
    final userVoteRef = albumRef.collection('genreUserVotes').doc(userId);

    await _firestore.runTransaction((transaction) async {
      // Check if user has already voted
      final userVoteSnap = await transaction.get(userVoteRef);
      if (userVoteSnap.exists) {
        throw Exception("User has already voted");
      }

      // Get the album document
      final albumSnap = await transaction.get(albumRef);
      if (!albumSnap.exists) {
        throw Exception("Album does not exist");
      }

      // Get current genreVotes map, initialize if missing
      Map<String, dynamic> genreVotes = {};
      if (albumSnap.data()!.containsKey('genreVotes')) {
        genreVotes = Map<String, dynamic>.from(albumSnap['genreVotes']);
      }

      // Increment the chosen genre count
      if (genreVotes.containsKey(chosenGenre)) {
        if (genreVotes[chosenGenre] is int) {
          genreVotes[chosenGenre] = genreVotes[chosenGenre]! + 1;
        } else {
          throw Exception("Invalid genreVotes count type for genre '$chosenGenre'. Expected int.");
        }
      } else {
        genreVotes[chosenGenre] = 1;
      }

      // Update genreVotes map in album document using update to prevent overwriting other fields
      transaction.update(albumRef, {'genreVotes': genreVotes});

      // Set user's genre vote
      transaction.set(userVoteRef, {'genre': chosenGenre});
    });
  }

  /// Change the genre vote of a user for a specific album.
  /// This method decrements the old genre's count and increments the new genre's count.
  Future<void> changeGenreVote({
    required String albumId,
    required String userId,
    required String newGenre,
  }) async {
    final albumRef = _firestore.collection('albums').doc(albumId);
    final userVoteRef = albumRef.collection('genreUserVotes').doc(userId);

    await _firestore.runTransaction((transaction) async {
      // Get the user's current genre vote
      final userVoteSnap = await transaction.get(userVoteRef);
      if (!userVoteSnap.exists) {
        throw Exception("User has not voted yet");
      }

      final oldGenre = userVoteSnap['genre'] as String?;
      if (oldGenre == null) {
        throw Exception("Existing genre vote is invalid");
      }

      if (oldGenre == newGenre) {
        // No change needed
        print("User '$userId' attempted to change genre to the same genre '$newGenre'. No action taken.");
        return;
      }

      // Get the album document
      final albumSnap = await transaction.get(albumRef);
      if (!albumSnap.exists) {
        throw Exception("Album does not exist");
      }

      // Get current genreVotes map, initialize if missing
      Map<String, dynamic> genreVotes = {};
      if (albumSnap.data()!.containsKey('genreVotes')) {
        genreVotes = Map<String, dynamic>.from(albumSnap['genreVotes']);
      }

      // Decrement the old genre count
      if (genreVotes.containsKey(oldGenre)) {
        if (genreVotes[oldGenre] is int) {
          int oldCount = genreVotes[oldGenre];
          if (oldCount > 1) {
            genreVotes[oldGenre] = oldCount - 1;
          } else {
            // Remove genre if count reaches 0
            genreVotes.remove(oldGenre);
          }
        } else {
          throw Exception("Invalid genreVotes count type for genre '$oldGenre'. Expected int.");
        }
      } else {
        // Handle inconsistency if old genre not found
        print("Inconsistency detected: Old genre '$oldGenre' not found in genreVotes for album '$albumId'.");
      }

      // Increment the new genre count
      if (genreVotes.containsKey(newGenre)) {
        if (genreVotes[newGenre] is int) {
          genreVotes[newGenre] = genreVotes[newGenre]! + 1;
        } else {
          throw Exception("Invalid genreVotes count type for genre '$newGenre'. Expected int.");
        }
      } else {
        genreVotes[newGenre] = 1;
      }

      // Update genreVotes map in album document using update to prevent overwriting other fields
      transaction.update(albumRef, {'genreVotes': genreVotes});

      // Update the user's genre vote
      transaction.update(userVoteRef, {'genre': newGenre});
    });
  }

  /// Retrieve the current genre vote of a user for a specific album.
  Future<String?> getUserGenreVote(String albumId, String userId) async {
    final doc = await _firestore
        .collection('albums')
        .doc(albumId)
        .collection('genreUserVotes')
        .doc(userId)
        .get();
    return doc.exists ? doc['genre'] as String? : null;
  }

  /// Updates the taste profile of a user.
  Future<void> updateTasteProfile(String userId, Map<String, dynamic> tasteProfileData) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'tasteProfile': tasteProfileData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update taste profile: $e');
    }
  }

  // Add user to the users collection and create public profile
  Future<void> addUser(
    String userId,
    String username,
    String email,
    String country,
  ) async {
    // Create the main user document with private data
    await _firestore.collection('users').doc(userId).set({
      'username': username, // <-- Add this field
      'email': email,
      'country': country,
      'addresses': [],
      'hasOrdered': false,
      'tasteProfile': null,
      'customizations': {
        'themeColor': '#C0C0C0',
        'fontStyle': 'MS Sans Serif',
        'layout': 'default',
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create the public profile in the 'public' subcollection
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('public')
        .doc('profile')
        .set({
      'username': username,
      // Add other public fields if necessary
    });
  }

// In FirestoreService class
Future<List<DocumentSnapshot>> getWishlistForUser(String userId) async {
  final wishlistSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('wishlist')
      .get();

  return wishlistSnapshot.docs; // list of docs in the wishlist subcollection
}


  Future<void> updateOrderReturnStatus(
      String orderId, bool returnConfirmed) async {
    await _firestore.collection('orders').doc(orderId).update({
      'returnConfirmed': returnConfirmed,
      'updatedAt': FieldValue.serverTimestamp(), // Added updatedAt timestamp
    });
  }

  Future<void> addOrder(String userId, String address, {int flowVersion = 1,}) async {
    await _firestore.collection('orders').add({
      'userId': userId,
      'address': address,
      'status': 'new',
      'flowVersion': flowVersion,
      'timestamp': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(), 
      'details': {},
    });

    await _firestore.collection('users').doc(userId).update({
      'hasOrdered': true,
      'updatedAt': FieldValue.serverTimestamp(), // Added updatedAt timestamp
    });
  }

// For retrieving the user document
  Future<DocumentSnapshot?> getUserDoc(String? uid) async {
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(uid).get();
  }

  // For updating the user document
  Future<void> updateUserDoc(String uid, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update(data);
  }

  Future<void> updateOrderWithAlbum(String orderId, String albumId) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': 'sent',
      'albumId': albumId,
      'details.albumId': albumId, // <--- Add this line
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(), // Added updatedAt timestamp
    });

    if (status == 'returned' || status == 'kept') {
      DocumentSnapshot orderDoc =
          await _firestore.collection('orders').doc(orderId).get();
      String userId = orderDoc['userId'];
      await _firestore.collection('users').doc(userId).update({
        'hasOrdered': false,
        'updatedAt': FieldValue.serverTimestamp(), // Added updatedAt timestamp
      });
    }
  }

  Future<void> submitFeedback(
      String orderId, Map<String, dynamic> feedback) async {
    await _firestore.collection('orders').doc(orderId).update({
      'feedback': feedback,
      'updatedAt': FieldValue.serverTimestamp(), // Added updatedAt timestamp
    });
  }

  Future<bool> isAdmin(String userId) async {
    DocumentSnapshot doc =
        await _firestore.collection('admins').doc(userId).get();
    return doc.exists;
  }

  Future<List<DocumentSnapshot>> getAllUsers() async {
    QuerySnapshot snapshot = await _firestore.collection('users').get();
    return snapshot.docs;
  }

  Future<List<DocumentSnapshot>> getOrdersForUser(String userId) async {
    QuerySnapshot snapshot = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .get();
    return snapshot.docs;
  }

  Future<List<DocumentSnapshot>> getUnfulfilledOrders() async {
    QuerySnapshot snapshot = await _firestore
        .collection('orders')
        .where('status', isEqualTo: 'new')
        .get();
    return snapshot.docs;
  }

  Future<DocumentReference> addAlbum(String artist, String albumName,
      String releaseYear, String quality, String coverUrl) async {
    DocumentReference albumRef = await _firestore.collection('albums').add({
      'artist': artist,
      'albumName': albumName,
      'releaseYear': releaseYear,
      'quality': quality,
      'coverUrl': coverUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'genreVotes': {}, // Initialize genreVotes as an empty map
    });
    return albumRef;
  }

  Future<void> addToWishlist({
    required String userId,
    required String albumId,
    required String albumName,
    required String albumImageUrl,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .doc(albumId)
        .set({
      'albumName': albumName,
      'albumImageUrl': albumImageUrl,
      'dateAdded': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentSnapshot> getAlbumById(String albumId) async {
    return await _firestore.collection('albums').doc(albumId).get();
  }

  Future<List<DocumentSnapshot>> getAllAlbums() async {
    QuerySnapshot snapshot = await _firestore.collection('albums').get();
    return snapshot.docs;
  }

  Future<void> confirmReturn(String orderId) async {
    try {
      await _firestore.collection('orders').doc(orderId).update({
        'returnConfirmed': true,
        'status': 'returnedConfirmed', // Update the status if needed
        'updatedAt': FieldValue.serverTimestamp(), // Added updatedAt timestamp
      });
    } catch (e) {
      print('Error confirming return: $e');
      throw e;
    }
  }

  Future<List<DocumentSnapshot>> getPreviousAddresses(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (userDoc.exists && userDoc.data()!.containsKey('previousAddresses')) {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('addresses')
          .get();
      return snapshot.docs;
    }
    return [];
  }

  Future<Map<String, int>> getUserAlbumStats(String userId) async {
    final QuerySnapshot keptAlbumsQuery = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'kept')
        .get();

    final QuerySnapshot sentBackAlbumsQuery = await _firestore
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'returnedConfirmed')
        .get();

    return {
      'albumsKept': keptAlbumsQuery.docs.length,
      'albumsSentBack': sentBackAlbumsQuery.docs.length,
    };
  }

  Future<DocumentSnapshot> getUserStats(String userId) async {
    return await _firestore.collection('users').doc(userId).get();
  }

  /// ------------------------
  /// New Methods for Followers/Following System
  /// ------------------------

  /// Follows a user.
  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      if (currentUserId == targetUserId) {
        throw Exception("You cannot follow yourself.");
      }

      // Create a batch to ensure atomicity
      WriteBatch batch = _firestore.batch();

      // Reference paths
      DocumentReference followingRef = _firestore
          .collection('following')
          .doc(currentUserId)
          .collection('userFollowing')
          .doc(targetUserId);

      DocumentReference followersRef = _firestore
          .collection('followers')
          .doc(targetUserId)
          .collection('userFollowers')
          .doc(currentUserId);

      DocumentReference currentUserDoc = _firestore.collection('users').doc(currentUserId);
      DocumentReference targetUserDoc = _firestore.collection('users').doc(targetUserId);

      // Check if already following
      DocumentSnapshot followingSnap = await followingRef.get();
      if (followingSnap.exists) {
        throw Exception("You are already following this user.");
      }

      // Set following document
      batch.set(followingRef, {
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Set followers document
      batch.set(followersRef, {
        'followedAt': FieldValue.serverTimestamp(),
      });

      // Increment followingCount and followersCount
      batch.update(currentUserDoc, {
        'followingCount': FieldValue.increment(1),
      });

      batch.update(targetUserDoc, {
        'followersCount': FieldValue.increment(1),
      });

      // Commit the batch
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to follow user: $e');
    }
  }

  /// Unfollows a user.
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      // Create a batch to ensure atomicity
      WriteBatch batch = _firestore.batch();

      // Reference paths
      DocumentReference followingRef = _firestore
          .collection('following')
          .doc(currentUserId)
          .collection('userFollowing')
          .doc(targetUserId);

      DocumentReference followersRef = _firestore
          .collection('followers')
          .doc(targetUserId)
          .collection('userFollowers')
          .doc(currentUserId);

      DocumentReference currentUserDoc = _firestore.collection('users').doc(currentUserId);
      DocumentReference targetUserDoc = _firestore.collection('users').doc(targetUserId);

      // Check if not following
      DocumentSnapshot followingSnap = await followingRef.get();
      if (!followingSnap.exists) {
        throw Exception("You are not following this user.");
      }

      // Delete following document
      batch.delete(followingRef);

      // Delete followers document
      batch.delete(followersRef);

      // Decrement followingCount and followersCount
      batch.update(currentUserDoc, {
        'followingCount': FieldValue.increment(-1),
      });

      batch.update(targetUserDoc, {
        'followersCount': FieldValue.increment(-1),
      });

      // Commit the batch
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to unfollow user: $e');
    }
  }

  /// Retrieves a list of follower IDs for a user.
  Future<List<String>> getFollowers(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('followers')
          .doc(userId)
          .collection('userFollowers')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      throw Exception('Failed to retrieve followers: $e');
    }
  }

  /// Retrieves a list of following IDs for a user.
  Future<List<String>> getFollowing(String userId) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('following')
          .doc(userId)
          .collection('userFollowing')
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      throw Exception('Failed to retrieve following: $e');
    }
  }

  /// Retrieves whether the current user is following the target user.
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('following')
          .doc(currentUserId)
          .collection('userFollowing')
          .doc(targetUserId)
          .get();

      return doc.exists;
    } catch (e) {
      throw Exception('Failed to check follow status: $e');
    }
  }

  /// ------------------------
  /// New Methods for Profile Customizations
  /// ------------------------

  /// Updates the customization settings of a user.
  Future<void> updateUserCustomizations(String userId, Map<String, dynamic> customizationData) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'customizations': customizationData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user customizations: $e');
    }
  }

  /// Retrieves the customization settings of a user.
  Future<Map<String, dynamic>?> getUserCustomizations(String userId) async {
    try {
      // Cast the DocumentSnapshot to include the expected data type
      DocumentSnapshot<Map<String, dynamic>> userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        // Access the 'customizations' field safely
        return userDoc.data()?['customizations'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      throw Exception('Failed to retrieve user customizations: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      // Fetch the main user document
      DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        return null;
      }

      Map<String, dynamic>? userData = userDoc.data();
      if (userData == null) {
        return null;
      }

      // Fetch the public profile
      DocumentSnapshot<Map<String, dynamic>> publicProfileDoc =
          await _firestore.collection('users').doc(userId).collection('public').doc('profile').get();

      if (publicProfileDoc.exists && publicProfileDoc.data() != null) {
        userData.addAll(publicProfileDoc.data()!);
      }

      return userData;
    } catch (e) {
      print('Error fetching user profile: $e');
      return null;
    }
  }

  /// ------------------------
  /// Image Upload Methods
  /// ------------------------

  /// Uploads a profile picture and returns its URL.
  Future<String> uploadProfilePicture(String userId, String filePath) async {
    try {
      File file = File(filePath);
      Reference storageRef = _storage.ref().child('profile_pictures').child('$userId.png');
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload profile picture: $e');
    }
  }

  /// Deletes a review from an album's "reviews" subcollection.
  Future<void> deleteReview({
    required String albumId,
    required String reviewId,
  }) async {
    await _firestore
        .collection('albums')
        .doc(albumId)
        .collection('reviews')
        .doc(reviewId)
        .delete();
  }

  /// Uploads a banner image and returns its URL.
  Future<String> uploadBannerImage(String userId, String filePath) async {
    try {
      File file = File(filePath);
      Reference storageRef = _storage.ref().child('banner_images').child('$userId.png');
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload banner image: $e');
    }
  }


/// Updates the profile picture URL in the public profile.
Future<void> updateUserPublicProfilePicture(
    String userId, String profilePictureUrl) async {
  try {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('public')
        .doc('profile')
        .update({
      'profilePictureUrl': profilePictureUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    throw Exception('Failed to update profile picture: $e');
  }
}

/// Updates the banner image URL in the public profile.
Future<void> updateUserBannerPicture(
    String userId, String bannerUrl) async {
  try {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('public')
        .doc('profile')
        .update({
      'bannerUrl': bannerUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    throw Exception('Failed to update banner image: $e');
  }
}
  /// ------------------------
  /// Additional Existing Methods (Preserved)
  /// ------------------------

  // ... [All other existing methods remain unchanged]

  /// Note: Ensure that all existing methods you provided are included above.
}
