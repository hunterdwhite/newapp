/// Script to add free order fields to existing users
/// Run this once to give all existing users 1 free community curator order
/// 
/// To run: dart scripts/add_free_orders_to_users.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  print('Starting migration to add free orders to existing users...');
  
  // Initialize Firebase - you may need to configure this for your project
  // await Firebase.initializeApp();
  
  final firestore = FirebaseFirestore.instance;
  
  try {
    // Get all users
    final usersSnapshot = await firestore.collection('users').get();
    
    print('Found ${usersSnapshot.docs.length} users');
    
    int updatedCount = 0;
    int skippedCount = 0;
    
    for (var userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      
      // Only update if user doesn't already have these fields
      if (!userData.containsKey('freeOrder') || 
          !userData.containsKey('freeOrdersAvailable')) {
        
        await userDoc.reference.update({
          'freeOrder': true,
          'freeOrdersAvailable': 1,
          'freeOrderCredits': userData['freeOrderCredits'] ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        updatedCount++;
        print('Updated user: ${userDoc.id}');
      } else {
        skippedCount++;
        print('Skipped user (already has fields): ${userDoc.id}');
      }
    }
    
    print('\n=== Migration Complete ===');
    print('Updated: $updatedCount users');
    print('Skipped: $skippedCount users');
    
  } catch (e) {
    print('Error during migration: $e');
  }
}



