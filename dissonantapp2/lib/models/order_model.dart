import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderModel extends ChangeNotifier {
  bool hasOrdered = false;
  List<String> previousAddresses = [];

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> loadOrderData() async {
    final prefs = await SharedPreferences.getInstance();
    hasOrdered = prefs.getBool('hasOrdered') ?? false;
    previousAddresses = prefs.getStringList('previousAddresses') ?? [];
    notifyListeners();
  }

  Future<void> saveAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    previousAddresses.add(address);
    await prefs.setStringList('previousAddresses', previousAddresses);
    notifyListeners();
  }

  Future<void> placeOrder(String address, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    hasOrdered = true;
    await prefs.setBool('hasOrdered', hasOrdered);

    // Save order to Firestore
    await _firestore.collection('orders').add({
      'userId': userId,
      'address': address,
      'status': 'new',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!previousAddresses.contains(address)) {
      await saveAddress(address);
    }
    notifyListeners();
  }

  Future<void> resetOrder() async {
    final prefs = await SharedPreferences.getInstance();
    hasOrdered = false;
    await prefs.setBool('hasOrdered', hasOrdered);
    notifyListeners();
  }
}