// lib/services/orders/order_history_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../utils/user_session.dart';

class OrderHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 📜 FETCH PAST ORDERS FOR USER PROFILE
  Future<List<Map<String, dynamic>>> getUserOrderHistory(String userId) async {
    try {
      // Fetching only completed or exited orders
      final snapshot = await _db
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .where('tenantId',
              isEqualTo: UserSession.tenantId) // 🚀 SAAS INJECTION
          .where('paymentStatus', isEqualTo: 'PAID')
          .orderBy('timestamp', descending: true)
          .limit(20) // Limit for pagination/performance
          .get();

      return snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data();
        data['orderId'] = doc.id; // Injecting document ID for UI reference
        return data;
      }).toList();
    } catch (e) {
      debugPrint("Order History Fetch Error: $e");
      return [];
    }
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
