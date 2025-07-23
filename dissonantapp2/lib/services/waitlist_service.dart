import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class WaitlistService {
  static final _firestore = FirebaseFirestore.instance;

  /// Adds [email] to the waitlist with 'status' = 'pending' and no inviteKey yet.
  /// No key is returned to the user. Admin can later set 'inviteKey' and 'status' = 'approved'.
  static Future<void> addEmailToWaitlist(String email) async {
    // Convert email to a doc ID (remove special chars, etc.).
    final docId = email.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase();

    final docRef = _firestore.collection('waitlist').doc(docId);

    // Optional existence check for friendlier error messages
    final existingSnap = await docRef.get();
    if (existingSnap.exists) {
      throw Exception('This email is already on the waitlist.');
    }

    // Create a doc with minimal data; 'inviteKey' is null for now
    await docRef.set({
      'email': email,
      'inviteKey': null,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Verifies that [inviteKey] belongs to a doc with 'status' = 'approved'.
  /// Returns 'true' if valid, else 'false'.
  static Future<bool> verifyInviteKey(String inviteKey) async {
    // Query for a doc in 'waitlist' that matches this inviteKey
    final query = await _firestore
        .collection('waitlist')
        .where('inviteKey', isEqualTo: inviteKey)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return false; // No doc has this key
    }
    final docData = query.docs.first.data();
    // Check that doc's status = 'approved'
    if (docData['status'] == 'approved') {
      return true;
    } else {
      return false;
    }
  }
}
