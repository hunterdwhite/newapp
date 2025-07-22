import 'package:cloud_firestore/cloud_firestore.dart';
import 'base_service.dart';

class FirebaseService extends BaseService {
  @override
  String get serviceName => 'FirebaseService';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addOrder(String userId, String address) async {
    await _firestore.collection('orders').add({
      'userId': userId,
      'address': address,
      'status': 'new',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getOrders() {
    return _firestore.collection('orders').orderBy('timestamp', descending: true).snapshots();
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore.collection('orders').doc(orderId).update({'status': status});
  }
}