// lib/services/orders/order_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../security/fraud_detection_service.dart';
import '../../utils/user_session.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FraudDetectionService _fraudDetector = FraudDetectionService();

  Future<String?> getActiveOrderId(String userId) async {
    try {
      final snapshot = await _db
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .where('tenantId',
              isEqualTo: UserSession.tenantId) // 🚀 SAAS INJECTION
          .where('storeId', isEqualTo: UserSession.storeId) // 🚀 SAAS INJECTION
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
    } catch (e) {}

    final riskProfile = _fraudDetector.evaluateCartRisk(items);

    // 🛑 THE MASTER FIX 1: Bypass stale pending orders!
    // Always create a Fresh Gate Pass unless Guard specifically sent it back for correction.
    String? existingId = correctionOrderId;

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
      'qrConsumed': false,
      'revisionHistory': revisionHistory,
      'timestamp': FieldValue.serverTimestamp(),
      'qrExpiresAt':
          Timestamp.fromDate(DateTime.now().add(const Duration(hours: 8))),
      // 🚀 THE SAAS INJECTION ENGINE
      'tenantId': UserSession.tenantId,
      'storeId': UserSession.storeId,
      'branchCode': UserSession.branchCode,
    };

    if (existingId != null) {
      orderData['verifiedAt'] = FieldValue.delete();
      orderData['verifiedByGuardId'] = FieldValue.delete();
    }

    batch.set(orderRef, orderData, SetOptions(merge: true));

    // ==========================================================
    // 🚀 THE BULLETPROOF INVENTORY ENGINE (Query Method)
    // ==========================================================
    if (existingId == null) {
      for (var item in items) {
        String barcode = item['barcode']?.toString() ?? '';
        if (barcode.isEmpty) continue;

        int qty = int.tryParse(item['quantity']?.toString() ??
                item['qty']?.toString() ??
                '1') ??
            1;
        String cType = item['clearanceType'] ?? '';
        int buyQty = int.tryParse(item['buyQty']?.toString() ?? '1') ?? 1;
        int freeQty = int.tryParse(item['freeQty']?.toString() ?? '0') ?? 0;
        String freeProductId = item['freeProductId'] ?? '';

        int mainItemDeduction = qty;
        int crossItemDeduction = 0;

        if (cType == 'BOGO') {
          int combos = buyQty > 0 ? (qty ~/ buyQty) : 0;
          mainItemDeduction = qty + (combos * freeQty);
        } else if (cType == 'BUY_X_GET_Y' && freeProductId.isNotEmpty) {
          int combos = buyQty > 0 ? (qty ~/ buyQty) : 0;
          crossItemDeduction = combos * freeQty;
        }

        // 🛑 THE MASTER FIX 2: Query by Field Name! (Bypasses double-quote string glitches)
        final pSnap = await _db
            .collection('products')
            .where('barcode', isEqualTo: barcode)
            .where('tenantId',
                isEqualTo: UserSession.tenantId) // 🚀 SAAS INJECTION
            .where('storeId',
                isEqualTo: UserSession.storeId) // 🚀 SAAS INJECTION
            .limit(1)
            .get();
        if (pSnap.docs.isNotEmpty) {
          batch.update(pSnap.docs.first.reference, {
            'physicalStock': FieldValue.increment(-mainItemDeduction),
            'soldStock': FieldValue.increment(mainItemDeduction)
          });
        }

        if (crossItemDeduction > 0) {
          final fSnap = await _db
              .collection('products')
              .where('barcode', isEqualTo: freeProductId)
              .limit(1)
              .get();
          if (fSnap.docs.isNotEmpty) {
            batch.update(fSnap.docs.first.reference, {
              'physicalStock': FieldValue.increment(-crossItemDeduction),
              'soldStock': FieldValue.increment(crossItemDeduction)
            });
          }
        }
      }
    }

    await batch.commit();
    return orderRef.id;
  }

  Stream<DocumentSnapshot> getOrderStatusStream(String orderId) {
    return _db.collection('orders').doc(orderId).snapshots();
  }
}
