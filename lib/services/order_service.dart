import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

        if (exitStatus == 'REJECTED') {
          return snapshot.docs.first.id;
        }

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

  // 🎯 THE CHANAKYA TRUST SCORE ENGINE
  Future<void> updateTrustScore(String userId, double delta,
      {required bool isReward}) async {
    try {
      final userRef = _db.collection('users').doc(userId);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        // Default to 80.0 (Innocent until proven guilty)
        double currentScore = 80.0;
        if (snapshot.exists && snapshot.data()?['trustScore'] != null) {
          currentScore = (snapshot.data()?['trustScore'] as num).toDouble();
        }

        double newScore = currentScore;

        if (isReward) {
          // 🛡️ DIMINISHING RECOVERY (Anti-Gaming Shield)
          double appliedReward = delta; // default +2
          if (currentScore < 40) {
            appliedReward = 0.25; // Brutal redemption path
          } else if (currentScore < 60) {
            appliedReward = 0.5;
          } else if (currentScore < 80) {
            appliedReward = 1.0;
          }
          newScore = currentScore + appliedReward;
          if (newScore > 100) newScore = 100.0;
        } else {
          // ⚔️ SURGICAL STRIKE PENALTY
          newScore = currentScore - delta;
          if (newScore < 0) newScore = 0.0;
        }

        // 🧠 Update the user's permanent record
        transaction.set(
            userRef,
            {
              'trustScore': double.parse(newScore.toStringAsFixed(2)),
              'lastActivityAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint("Trust Score Engine Error: $e");
    }
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
    // Base Check
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

    double calculatedTotalWeight = 0.0;
    for (var item in items) {
      double wpu = double.tryParse(item['weight_per_unit']?.toString() ?? '') ??
          double.tryParse(item['weight']?.toString() ?? '') ??
          0.0;
      int q = int.tryParse(
              item['qty']?.toString() ?? item['quantity']?.toString() ?? '1') ??
          1;
      calculatedTotalWeight +=
          double.tryParse(item['total_item_weight']?.toString() ?? '') ??
              (wpu * q);
    }
    calculatedTotalWeight =
        double.parse(calculatedTotalWeight.toStringAsFixed(3));

    double actualMeasuredWeight = calculatedTotalWeight; // Simulated for now
    double weightDiff = (calculatedTotalWeight - actualMeasuredWeight).abs();

    // ⚖️ PRO-LEVEL TOLERANCE BANDS (Percentage Based)
    double diffPercentage = calculatedTotalWeight > 0
        ? (weightDiff / calculatedTotalWeight) * 100
        : 0;

    String riskLevel = 'LOW';
    String recommendation = 'APPROVE';

    if (diffPercentage > 12.0) {
      riskLevel = 'HIGH';
      recommendation = 'REJECT';
    } else if (diffPercentage > 5.0 && diffPercentage <= 12.0) {
      riskLevel = 'MEDIUM';
      recommendation = 'MANUAL CHECK';
    }

    String? existingId = correctionOrderId ?? await getActiveOrderId(user.uid);
    DocumentReference orderRef = existingId != null
        ? _db.collection('orders').doc(existingId)
        : _db.collection('orders').doc();

    List<dynamic> revisionHistory = [];
    if (existingId != null) {
      try {
        DocumentSnapshot oldDoc = await orderRef.get();
        if (oldDoc.exists) {
          final oldData = oldDoc.data() as Map<String, dynamic>;
          revisionHistory = List.from(oldData['revisionHistory'] ?? []);
          revisionHistory.add({
            'revisionTime': DateTime.now().toIso8601String(),
            'items': oldData['items'],
            'totalAmount': oldData['totalAmount'],
            'riskLevel': oldData['riskLevel'],
            'exitStatus': oldData['exitStatus'],
          });
        }
      } catch (e) {}
    }

    WriteBatch batch = _db.batch();
    String status =
        paymentMode == 'CASH' ? 'payment_pending_cash' : 'payment_pending_upi';

    Map<String, dynamic> orderData = {
      'userId': user.uid,
      'userEmail': realEmail,
      'items': items,
      'totalAmount': totalAmount,
      'gstTotal': gstTotal,

      'totalWeight': calculatedTotalWeight,
      'weightVerifiedAtGate': false,
      'weightMismatchFlag': diffPercentage > 12.0,

      'totalExpectedWeight': calculatedTotalWeight,
      'weightToleranceUsed': 12.0, // Storing max tolerance %
      'weightDifference': weightDiff,
      'riskLevel': riskLevel,
      'guardRecommendation': recommendation,

      'paymentMode': paymentMode,
      'status': status,
      'paymentStatus': 'PENDING',
      'exitStatus': 'PENDING',
      'wasEverRejected': existingId != null ? true : false,
      'isDeleted': false,
      'revisionHistory': revisionHistory,

      'timestamp': FieldValue.serverTimestamp(),
      'qrExpiresAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 8))),
      'branchCode': 'MART01',
    };

    batch.set(orderRef, orderData, SetOptions(merge: true));

    for (var item in items) {
      DocumentReference productRef =
          _db.collection('products').doc(item['barcode']);
      batch.update(productRef, {
        'stock': FieldValue.increment(-int.parse((item['qty'] ?? 1).toString()))
      });
    }

    await batch.commit();
    return orderRef.id;
  }

  Stream<DocumentSnapshot> getOrderStatusStream(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots();
  }
}
