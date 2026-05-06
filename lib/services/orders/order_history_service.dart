// lib/services/orders/order_history_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../utils/user_session.dart';

class OrderHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 📜 FIX: Converted to STREAM for real-time status updates!
  Stream<List<Map<String, dynamic>>> getUserOrderHistoryStream(String userId) {
    return _db
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .where('tenantId', isEqualTo: UserSession.tenantId)
        .where('paymentStatus',
            isEqualTo: 'PAID') // Hata sakte ho agar PENDING bhi dikhana hai
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              Map<String, dynamic> data = doc.data();
              data['orderId'] = doc.id;
              return data;
            }).toList());
  }

  // 🧾 FETCH SINGLE ORDER DETAILS (For viewing digital receipt)
  Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      final doc = await _db.collection('orders').doc(orderId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint("Single Order Fetch Error: $e");
      return null;
    }
  }
}
