import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

// 🔍 SMART CHECK: Query simplified to match existing indexes
  Future<String?> getActiveOrderId(String userId) async {
    try {
      final snapshot = await _db
          .collection('orders')
          .where('userId', isEqualTo: userId)
          // Humne 'status' aur 'paymentStatus' ke complex filters hata diye hain
          // Kyunki humein sirf LATEST order dhoondna hai
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        String status = (data['status'] ?? '').toString().toUpperCase();
        String payStatus =
            (data['paymentStatus'] ?? '').toString().toUpperCase();

        // Check: Agar order abhi bhi PENDING hai, tabhi uska ID return karo
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

    // ⚖️ CALCULATE EXPECTED WEIGHT
    double calculatedTotalWeight = 0.0;
    for (var item in items) {
      double itemWeight =
          double.tryParse(item['total_item_weight'].toString()) ??
              (double.tryParse(item['weight_per_unit'].toString()) ?? 0.0) *
                  (int.tryParse(item['qty'].toString()) ?? 1);
      calculatedTotalWeight += itemWeight;
    }
    calculatedTotalWeight =
        double.parse(calculatedTotalWeight.toStringAsFixed(3));

    // 🧠 AI ENGINE: Tolerance Calculation
    double tolerance = 10.0; // Default <= 500g
    if (calculatedTotalWeight > 2000) {
      tolerance = 50.0;
    } else if (calculatedTotalWeight > 500) {
      tolerance = 25.0;
    }

    // 🔮 FUTURE HARDWARE LOGIC: Simulate Actual Weight (For now, diff is 0)
    // Kal ko jab scale aayega, ye diff automatically hardware se aayega.
    double actualMeasuredWeight = calculatedTotalWeight;
    double weightDiff = (calculatedTotalWeight - actualMeasuredWeight).abs();

    // 🚨 RISK CALCULATION LAYER
    String riskLevel = 'LOW';
    String recommendation = 'APPROVE';

    if (weightDiff > tolerance) {
      riskLevel = 'HIGH';
      recommendation = 'REJECT';
    } else if (weightDiff > 0 && weightDiff <= tolerance) {
      riskLevel = 'MEDIUM';
      recommendation = 'MANUAL CHECK';
    }

    // 🕵️‍♂️ SMART FRAUD DETECTION: Check past history of user!
    try {
      final pastSuspiciousOrders = await _db
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .where('wasEverRejected', isEqualTo: true) // Check past caught issues
          .limit(1)
          .get();

      if (pastSuspiciousOrders.docs.isNotEmpty && riskLevel == 'LOW') {
        riskLevel = 'MEDIUM';
        recommendation =
            'MANUAL CHECK'; // Customer ka track record kharab hai, Guard ko alert karo!
      }
    } catch (e) {
      debugPrint("AI Risk Engine Error: $e");
    }

    WriteBatch batch = _db.batch();
    String? existingId = await getActiveOrderId(user.uid);
    DocumentReference orderRef = existingId != null
        ? _db.collection('orders').doc(existingId)
        : _db.collection('orders').doc();

    String status =
        paymentMode == 'CASH' ? 'payment_pending_cash' : 'payment_pending_upi';

    Map<String, dynamic> orderData = {
      'userId': user.uid,
      'userEmail': realEmail,
      'items': items,
      'totalAmount': totalAmount,
      'gstTotal': gstTotal,

      'totalWeight': calculatedTotalWeight, // Legacy
      'weightVerifiedAtGate': false,
      'weightMismatchFlag': weightDiff > tolerance,

      // 🧠 INJECT AI DATA INTO FIRESTORE
      'totalExpectedWeight': calculatedTotalWeight,
      'weightToleranceUsed': tolerance,
      'weightDifference': weightDiff,
      'riskLevel': riskLevel,
      'guardRecommendation': recommendation,

      'paymentMode': paymentMode,
      'status': status,
      'paymentStatus': 'PENDING',
      'timestamp': FieldValue.serverTimestamp(),
      'qrExpiresAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 4))),
      'exitStatus': 'PENDING',
      'branchCode': 'MART01',
    };

    batch.set(orderRef, orderData, SetOptions(merge: true));

    for (var item in items) {
      DocumentReference productRef =
          _db.collection('products').doc(item['barcode']);
      batch.update(productRef, {'stock': FieldValue.increment(-item['qty'])});
    }

    await batch.commit();
    return orderRef.id;
  }

  Stream<DocumentSnapshot> getOrderStatusStream(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots();
  }
}
