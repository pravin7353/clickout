// lib/services/orders/order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../security/fraud_detection_service.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 💉 INJECTED SECURITY SERVICE
  final FraudDetectionService _fraudDetector = FraudDetectionService();

  Future<String?> getActiveOrderId(String userId) async {
    try {
      final snapshot = await _db
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        String status = (data['status'] ?? '').toString().toUpperCase();
        String payStatus =
            (data['paymentStatus'] ?? '').toString().toUpperCase();
        String exitStatus = (data['exitStatus'] ?? '').toString().toUpperCase();

        if (exitStatus == 'REJECTED') return snapshot.docs.first.id;
        if (payStatus == 'PENDING' &&
            (status.contains('PENDING') || status.contains('PAYMENT'))) {
          return snapshot.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint("Query Error: $e");
    }
    return null;
  }

  Future<String> createOrUpdateOrder({
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double gstTotal,
    required String paymentMode,
    String? correctionOrderId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    String realEmail = user.email ?? 'Guest';
    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['email'] != null && data['email'].toString().isNotEmpty) {
          realEmail = data['email'];
        }
      }
    } catch (e) {
      debugPrint("Email fetch error: $e");
    }

    // 🛡️ DELEGATE TO FRAUD DETECTION SERVICE
    final riskProfile = _fraudDetector.evaluateCartRisk(items);

    String? existingId = correctionOrderId ?? await getActiveOrderId(user.uid);
    DocumentReference orderRef = existingId != null
        ? _db.collection('orders').doc(existingId)
        : _db.collection('orders').doc();

    String finalPaymentStatus = 'PENDING';
    String finalExitStatus = 'PENDING';
    String finalStatus =
        paymentMode == 'CASH' ? 'payment_pending_cash' : 'payment_pending_upi';

    double finalTotalAmount = totalAmount;
    double finalGstTotal = gstTotal;
    int gatePassVersion = 1;
    List<dynamic> revisionHistory = [];

    if (existingId != null) {
      try {
        DocumentSnapshot oldDoc = await orderRef.get();
        if (oldDoc.exists) {
          final oldData = oldDoc.data() as Map<String, dynamic>;

          if (oldData['paymentStatus'] == 'PAID') {
            finalPaymentStatus = 'PAID';
            finalExitStatus = 'READY_FOR_EXIT';
            finalStatus = 'PAID';
            gatePassVersion = (oldData['gatePassVersion'] ?? 1) + 1;
          }

          revisionHistory = List.from(oldData['revisionHistory'] ?? []);
          revisionHistory.add({
            'revisionTime': DateTime.now().toIso8601String(),
            'items': oldData['items'],
            'totalAmount': oldData['totalAmount'],
            'riskLevel': oldData['riskLevel'],
            'exitStatus': oldData['exitStatus'],
            'gatePassVersion': oldData['gatePassVersion'] ?? 1,
          });
        }
      } catch (e) {}
    }

    WriteBatch batch = _db.batch();

    Map<String, dynamic> orderData = {
      'userId': user.uid,
      'userEmail': realEmail,
      'items': items,
      'totalAmount': finalTotalAmount,
      'gstTotal': finalGstTotal,

      // Data from Risk Profile
      'totalWeight': riskProfile['calculatedTotalWeight'],
      'weightVerifiedAtGate': false,
      'weightMismatchFlag': riskProfile['weightMismatchFlag'],
      'totalExpectedWeight': riskProfile['calculatedTotalWeight'],
      'weightToleranceUsed': 12.0,
      'weightDifference': riskProfile['weightDiff'],
      'riskLevel': riskProfile['riskLevel'],
      'guardRecommendation': riskProfile['recommendation'],

      'paymentMode': paymentMode,
      'status': finalStatus,
      'paymentStatus': finalPaymentStatus,
      'exitStatus': finalExitStatus,
      'wasEverRejected': existingId != null,
      'isCorrectionMode': existingId != null,
      'gatePassVersion': gatePassVersion,
      'isDeleted': false,
      'revisionHistory': revisionHistory,
      'timestamp': FieldValue.serverTimestamp(),
      'qrExpiresAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 8))),
      'branchCode': 'MART01',
    };

    batch.set(orderRef, orderData, SetOptions(merge: true));

    if (existingId == null) {
      for (var item in items) {
        DocumentReference productRef =
            _db.collection('products').doc(item['barcode']);
        batch.update(productRef, {
          'stock':
              FieldValue.increment(-int.parse((item['qty'] ?? 1).toString()))
        });
      }
    }

    await batch.commit();
    return orderRef.id;
  }

  Stream<DocumentSnapshot> getOrderStatusStream(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots();
  }
}
