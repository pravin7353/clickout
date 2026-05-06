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
    String? existingCartOrderId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    // 🚀 THE FIX: FETCH ACTUAL NAME AND PHONE FROM USER PROFILE
    String realEmail = user.email ?? 'Guest';
    String realName = user.displayName ?? '';
    String realPhone = user.phoneNumber ?? '';

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['email'] != null && data['email'].toString().isNotEmpty) {
          realEmail = data['email'];
        }
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          realName = data['name'];
        } else if (data['firstName'] != null) {
          realName = "${data['firstName']} ${data['lastName'] ?? ''}".trim();
        }
        if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
          realPhone = data['phone'];
        } else if (data['mobile'] != null) {
          realPhone = data['mobile'];
        }
      }
    } catch (e) {}

    // Fallback to UID if name is empty or "customer"
    if (realName.trim().isEmpty ||
        realName.trim().toLowerCase() == 'customer' ||
        realName.trim().toLowerCase() == 'walk-in customer') {
      realName = user.uid;
    }

    final riskProfile = _fraudDetector.evaluateCartRisk(items);

    // 🛑 THE MASTER FIX 1: Bypass stale pending orders!
    // Reuses same order ID if user goes back to cart (No ghost duplicate orders!)
    bool isGuardCorrection =
        correctionOrderId != null; // 🚀 BUG 3 FIX: Isolate real corrections
    String? existingId = correctionOrderId ?? existingCartOrderId;

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
    bool previousWasRejected = false;
    bool previousWasCorrection = false;
    String? existingInvoiceNo; // 🚀 CHECK EXISTING INVOICE

    if (existingId != null) {
      try {
        DocumentSnapshot oldDoc = await orderRef.get();
        if (oldDoc.exists) {
          final oldData = oldDoc.data() as Map<String, dynamic>;

          existingInvoiceNo =
              oldData['invoiceNo']; // 🚀 Fetch it so we don't overwrite!
          previousWasRejected = oldData['wasEverRejected'] == true;
          previousWasCorrection = oldData['isCorrectionMode'] == true;

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

    // ==========================================================
    // 🧠 THE SMART INVOICE ENGINE (As per your exact flow)
    // ==========================================================
    if (existingInvoiceNo == null || existingInvoiceNo.isEmpty) {
      String prefix = "INV/"; // Default Fallback

      // 1️⃣ Check Admin's Custom Rules (From Tenants Collection)
      if (UserSession.tenantId.isNotEmpty &&
          UserSession.tenantId != 'ALL' &&
          UserSession.tenantId != 'GLOBAL') {
        try {
          var tSnap =
              await _db.collection('tenants').doc(UserSession.tenantId).get();
          if (tSnap.exists) {
            var config =
                tSnap.data()?['invoiceConfig'] as Map<String, dynamic>? ?? {};
            String adminPrefix =
                config['invoicePrefix']?.toString().trim() ?? '';

            // 🧹 THE ULTIMATE SHIELD: Force remove any year pattern (like 26-27/) from Admin's setting
            adminPrefix =
                adminPrefix.replaceAll(RegExp(r'\d{2}-\d{2}[/-]?'), '');

            if (adminPrefix.isNotEmpty) {
              prefix = adminPrefix;
              if (!prefix.endsWith('/') && !prefix.endsWith('-')) prefix += '/';
            } else {
              prefix = "INV/"; // Fallback if prefix became empty after cleaning
            }
          }
        } catch (_) {}
      }

      // 2️⃣ Date & Year Formatting
      final now = DateTime.now();
      int startYear = now.month >= 4 ? now.year : now.year - 1;
      String fyStr =
          "${(startYear % 100).toString().padLeft(2, '0')}-${((startYear + 1) % 100).toString().padLeft(2, '0')}";
      String dateStr =
          "${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      String todayKey =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // 3️⃣ Atomic Sequence Counter
      DocumentReference counterRef = _db
          .collection('daily_invoice_counters')
          .doc("${UserSession.branchCode}_$todayKey");
      int seq = await _db.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(counterRef);
        if (!snapshot.exists) {
          transaction.set(counterRef, {'count': 1});
          return 1;
        } else {
          int newCount = (snapshot.data() as Map<String, dynamic>)['count'] + 1;
          transaction.update(counterRef, {'count': newCount});
          return newCount;
        }
      });

      // 4️⃣ Final Construction (e.g., MART/26-27/04-23-01)
      existingInvoiceNo =
          "$prefix$fyStr/$dateStr-${seq.toString().padLeft(2, '0')}";
    }

    // 🧠 1-TIME MASTER CALCULATION (For Database)
    double dbTotalSavings = 0.0;
    double dbTaxableValue = 0.0;

    for (var item in items) {
      int qty = int.tryParse(
              item['quantity']?.toString() ?? item['qty']?.toString() ?? '1') ??
          1;
      double price = double.tryParse(item['price']?.toString() ??
              item['unitPrice']?.toString() ??
              item['discountedPrice']?.toString() ??
              '0') ??
          0.0;
      double originalPrice = double.tryParse(
              item['originalPrice']?.toString() ??
                  item['mrp']?.toString() ??
                  '0') ??
          price;

      if (originalPrice > price)
        dbTotalSavings += (originalPrice - price) * qty;

      double itemTotal = price * qty;
      double gstRate = 0.0;
      if (item['gst'] != null) {
        gstRate = double.tryParse(
                item['gst'].toString().replaceAll(RegExp(r'[^0-9.]'), '')) ??
            0.0;
      }
      dbTaxableValue += itemTotal / (1 + (gstRate / 100));
    }

    WriteBatch batch = _db.batch();

    Map<String, dynamic> orderData = {
      'taxableValue': dbTaxableValue,
      'totalSavings': dbTotalSavings,
      'invoiceNo': existingInvoiceNo,
      'userId': user.uid,
      'userEmail': realEmail,
      'customerName': realName,
      'customerPhone': realPhone,
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
      'wasEverRejected':
          isGuardCorrection ? true : previousWasRejected, // 🚀 BUG 3 FIX
      'isCorrectionMode':
          isGuardCorrection ? true : previousWasCorrection, // 🚀 BUG 3 FIX
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

        // 🚀 BUG 1 FIX: Changed 'storeId' to 'branchCode' to match Product Master schema!
        final pSnap = await _db
            .collection('products')
            .where('barcode', isEqualTo: barcode)
            .where('tenantId', isEqualTo: UserSession.tenantId)
            .where('branchCode', isEqualTo: UserSession.branchCode)
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
