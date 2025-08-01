import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/home_screen.dart';

class ReferralService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Generate a unique referral code
  static String _generateReferralCode() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final Random random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Create or get referral code for user
  static Future<String> getOrCreateReferralCode(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (data.containsKey('referralCode') && data['referralCode'] != null) {
          return data['referralCode'];
        }
      }
      
      // Generate new code and ensure it's unique
      String newCode;
      bool isUnique = false;
      int attempts = 0;
      
      do {
        newCode = _generateReferralCode();
        final existingCodes = await _firestore
            .collection('users')
            .where('referralCode', isEqualTo: newCode)
            .get();
        
        isUnique = existingCodes.docs.isEmpty;
        attempts++;
        
        if (attempts > 10) {
          // If we can't find a unique code after 10 attempts, make it longer
          newCode = _generateReferralCode() + _generateReferralCode().substring(0, 2);
          break;
        }
      } while (!isUnique);
      
      // Save the code to user document
      await _firestore.collection('users').doc(userId).update({
        'referralCode': newCode,
        'referralCount': FieldValue.increment(0), // Initialize if doesn't exist
        'totalReferralCredits': FieldValue.increment(0), // Initialize if doesn't exist
        'firstOrderReferralCredits': FieldValue.increment(0), // Initialize if doesn't exist
      });
      
      return newCode;
    } catch (e) {
      print('Error creating referral code: $e');
      return _generateReferralCode(); // Fallback
    }
  }

  // Validate referral code and get referrer info
  static Future<Map<String, dynamic>?> validateReferralCode(String code) async {
    try {
      print('Validating referral code: $code');
      
      final querySnapshot = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: code.toUpperCase())
          .get();
      
      print('Found ${querySnapshot.docs.length} users with referral code: ${code.toUpperCase()}');
      
      if (querySnapshot.docs.isNotEmpty) {
        final referrerDoc = querySnapshot.docs.first;
        print('Referrer found: ${referrerDoc.id}');
        return {
          'referrerId': referrerDoc.id,
          'referrerData': referrerDoc.data(),
        };
      }
      print('No user found with referral code: ${code.toUpperCase()}');
      return null;
    } catch (e) {
      print('Error validating referral code: $e');
      return null;
    }
  }

  // Process a successful referral (called when new user completes registration)
  static Future<bool> processReferral(String referralCode, String newUserId) async {
    try {
      print('Processing referral: code=$referralCode, newUserId=$newUserId');
      
      final referrerInfo = await validateReferralCode(referralCode);
      if (referrerInfo == null) {
        print('Referral code validation failed: $referralCode');
        return false;
      }
      
      final String referrerId = referrerInfo['referrerId'];
      print('Found referrer: $referrerId');
      
      // Check if this user was already referred by someone else
      final newUserDoc = await _firestore.collection('users').doc(newUserId).get();
      if (newUserDoc.exists && newUserDoc.data()!.containsKey('referredBy')) {
        print('User $newUserId already has a referrer');
        return false; // User already has a referrer
      }
      
      // Prevent self-referral
      if (referrerId == newUserId) {
        print('Self-referral attempted: $newUserId');
        return false;
      }
      
      // Create referral record
      final referralRecord = {
        'referrerId': referrerId,
        'referredUserId': newUserId,
        'referralCode': referralCode.toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'completed',
        'creditAwarded': false,
        'hasPlacedFirstOrder': false,
        'firstOrderCreditAwarded': false,
      };
      
      final referralRef = await _firestore.collection('referrals').add(referralRecord);
      print('Created referral record: ${referralRef.id}');
      
      // Update new user with referrer info
      await _firestore.collection('users').doc(newUserId).update({
        'referredBy': referrerId,
        'referralUsed': referralCode.toUpperCase(),
      });
      print('Updated new user with referrer info');
      
      // Award credit to referrer
      await HomeScreen.addFreeOrderCredits(referrerId, 1);
      print('Awarded 1 credit to referrer: $referrerId');
      
      // Update referrer stats
      await _firestore.collection('users').doc(referrerId).update({
        'referralCount': FieldValue.increment(1),
        'totalReferralCredits': FieldValue.increment(1),
      });
      print('Updated referrer stats');
      
      // Mark credit as awarded in referral record
      await referralRef.update({'creditAwarded': true});
      print('Marked credit as awarded in referral record');
      
      return true;
    } catch (e) {
      print('Error processing referral: $e');
      return false;
    }
  }

  // Process when a referred user makes their first order
  static Future<bool> processReferredUserFirstOrder(String userId) async {
    try {
      print('DEBUG: processReferredUserFirstOrder called for userId: $userId');
      // Check if this user was referred
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists || !userDoc.data()!.containsKey('referredBy')) {
        print('DEBUG: processReferredUserFirstOrder - User was not referred or user doc does not exist');
        return false; // User wasn't referred
      }
      
      final referrerId = userDoc.data()!['referredBy'];
      print('DEBUG: processReferredUserFirstOrder - Found referrerId: $referrerId');
      
      // Find the referral record
      final referralQuery = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: referrerId)
          .where('referredUserId', isEqualTo: userId)
          .where('firstOrderCreditAwarded', isEqualTo: false)
          .get();
      
      print('DEBUG: processReferredUserFirstOrder - Found ${referralQuery.docs.length} referral records to process');
      
      if (referralQuery.docs.isEmpty) {
        print('DEBUG: processReferredUserFirstOrder - No referral record found or credit already awarded');
        return false; // No referral record found or credit already awarded
      }
      
      final referralDoc = referralQuery.docs.first;
      
      print('DEBUG: processReferredUserFirstOrder - Awarding 2 credits to referrer: $referrerId');
      // Award 2 credits to referrer for first order
      await HomeScreen.addFreeOrderCredits(referrerId, 2);
      
      print('DEBUG: processReferredUserFirstOrder - Updating referral record');
      // Update referral record
      await referralDoc.reference.update({
        'hasPlacedFirstOrder': true,
        'firstOrderCreditAwarded': true,
        'firstOrderCreditAwardedAt': FieldValue.serverTimestamp(),
      });
      
      print('DEBUG: processReferredUserFirstOrder - Updating referrer stats');
      // Update referrer stats
      await _firestore.collection('users').doc(referrerId).update({
        'firstOrderReferralCredits': FieldValue.increment(2),
        'totalReferralCredits': FieldValue.increment(2),
      });
      
      print('DEBUG: processReferredUserFirstOrder - Successfully completed');
      return true;
    } catch (e) {
      print('Error processing referred user first order: $e');
      return false;
    }
  }

  // Get list of referred users with their order status
  static Future<List<Map<String, dynamic>>> getReferredUsers(String userId) async {
    try {
      print('DEBUG: getReferredUsers for userId: $userId');
      final referralsQuery = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .get();
      
      print('DEBUG: Found ${referralsQuery.docs.length} referral documents for referred users');
      
      List<Map<String, dynamic>> referredUsers = [];
      
      for (final referralDoc in referralsQuery.docs) {
        final referralData = referralDoc.data();
        final referredUserId = referralData['referredUserId'];
        
        // Get referred user's info
        final userDoc = await _firestore.collection('users').doc(referredUserId).get();
        final userData = userDoc.exists ? userDoc.data()! : {};
        
        // Check if user has placed any orders
        final ordersQuery = await _firestore
            .collection('orders')
            .where('userId', isEqualTo: referredUserId)
            .limit(1)
            .get();
        
        final hasPlacedOrder = ordersQuery.docs.isNotEmpty;
        
        referredUsers.add({
          'referralId': referralDoc.id,
          'referredUserId': referredUserId,
          'referredUserEmail': userData['email'] ?? 'Unknown',
          'referredUserDisplayName': userData['username'] ?? userData['displayName'] ?? 'Unknown User',
          'joinedAt': referralData['createdAt'],
          'hasPlacedFirstOrder': hasPlacedOrder,
          'firstOrderCreditAwarded': referralData['firstOrderCreditAwarded'] ?? false,
        });
      }
      
      print('DEBUG: Returning ${referredUsers.length} referred users');
      return referredUsers;
    } catch (e) {
      print('Error getting referred users: $e');
      return [];
    }
  }

  // Share referral code
  static Future<void> shareReferralCode(String referralCode) async {
    try {
      final String shareText = '''Join me on DISSONANT! 

Discover CDs curated just for you. Use my referral code when you sign up:

${referralCode}

Download now and join the movement!''';

      await Share.share(
        shareText,
        subject: 'Join DISSONANT with my referral code!',
      );
    } catch (e) {
      print('Error sharing referral code: $e');
    }
  }

  // Get user's referral stats
  static Future<Map<String, dynamic>> getReferralStats(String userId) async {
    try {
      // Force fresh data from server to immediately show updated stats
      final userDoc = await _firestore.collection('users').doc(userId).get(const GetOptions(source: Source.server));
      final userData = userDoc.data() ?? {};
      
      final referralCode = userData['referralCode'] ?? '';
      final totalReferralCredits = userData['totalReferralCredits'] ?? 0;
      final firstOrderReferralCredits = userData['firstOrderReferralCredits'] ?? 0;

      // Get all referrals for this user to count them accurately
      final referralsQuery = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .get(const GetOptions(source: Source.server));
      final referralCount = referralsQuery.docs.length;
      
      print('DEBUG: getReferralStats for userId: $userId');
      print('DEBUG: Found ${referralsQuery.docs.length} referral documents');
      print('DEBUG: referralCount from user doc: ${userData['referralCount']}');
      print('DEBUG: Returning referralCount: $referralCount');
      
      // Get recent referrals for display (without orderBy to avoid index requirement)
      final recentReferrals = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .limit(5)
          .get(const GetOptions(source: Source.server));
      
      // Count how many referred users have placed first orders
      final firstOrderReferrals = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: userId)
          .where('firstOrderCreditAwarded', isEqualTo: true)
          .get(const GetOptions(source: Source.server));
      
      return {
        'referralCode': referralCode,
        'referralCount': referralCount,
        'totalReferralCredits': totalReferralCredits,
        'firstOrderReferralCredits': firstOrderReferralCredits,
        'firstOrderReferralCount': firstOrderReferrals.docs.length,
        'recentReferrals': recentReferrals.docs.map((doc) => doc.data()).toList(),
      };
    } catch (e) {
      print('Error getting referral stats: $e');
      return {
        'referralCode': '',
        'referralCount': 0,
        'totalReferralCredits': 0,
        'firstOrderReferralCredits': 0,
        'firstOrderReferralCount': 0,
        'recentReferrals': [],
      };
    }
  }

  // Manual function to check and award first order credits (for debugging/fixing)
  static Future<void> manuallyCheckAndAwardFirstOrderCredits(String userId) async {
    try {
      print('DEBUG: manuallyCheckAndAwardFirstOrderCredits for userId: $userId');
      
      // Check if user has placed any orders
      final ordersQuery = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();
      
      if (ordersQuery.docs.isEmpty) {
        print('DEBUG: manuallyCheckAndAwardFirstOrderCredits - User has no orders');
        return;
      }
      
      // Check if user was referred
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists || !userDoc.data()!.containsKey('referredBy')) {
        print('DEBUG: manuallyCheckAndAwardFirstOrderCredits - User was not referred');
        return;
      }
      
      final referrerId = userDoc.data()!['referredBy'];
      print('DEBUG: manuallyCheckAndAwardFirstOrderCredits - Found referrerId: $referrerId');
      
      // Find referral record where credit hasn't been awarded
      final referralQuery = await _firestore
          .collection('referrals')
          .where('referrerId', isEqualTo: referrerId)
          .where('referredUserId', isEqualTo: userId)
          .where('firstOrderCreditAwarded', isEqualTo: false)
          .get();
      
      if (referralQuery.docs.isEmpty) {
        print('DEBUG: manuallyCheckAndAwardFirstOrderCredits - No referral record found or credit already awarded');
        return;
      }
      
      // Award the credits manually
      await processReferredUserFirstOrder(userId);
      print('DEBUG: manuallyCheckAndAwardFirstOrderCredits - Successfully awarded credits');
      
    } catch (e) {
      print('Error in manuallyCheckAndAwardFirstOrderCredits: $e');
    }
  }

  // Initialize referral code for existing users (run once during migration)
  static Future<void> initializeReferralCodesForExistingUsers() async {
    try {
      final usersWithoutCodes = await _firestore
          .collection('users')
          .where('referralCode', isNull: true)
          .get();
      
      for (final doc in usersWithoutCodes.docs) {
        await getOrCreateReferralCode(doc.id);
      }
    } catch (e) {
      print('Error initializing referral codes: $e');
    }
  }
} 