// lib/services/payment/payment_service.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'upi_service.dart';

class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Handles routing based on payment mode
  Future<void> processPayment({
    required String orderId,
    required double amount,
    required String paymentMode,
    required String upiId,
    required String merchantName,
    VoidCallback? onSuccess,
    Function(String)? onError,
  }) async {
    try {
      if (paymentMode == 'CASH') {
        // For cash, just update the order status directly
        await _updateOrderStatus(orderId, 'PAID', 'READY_FOR_EXIT');
        if (onSuccess != null) onSuccess();
      } else if (paymentMode == 'UPI') {
        // Trigger UPI App
        bool launched = await UpiService.initiatePayment(
          upiId: upiId,
          merchantName: merchantName,
          amount: amount,
          orderId: orderId,
        );

        if (launched) {
          // Note: Real UPI verification requires a backend webhook.
          // Assuming successful intent means we mark it paid for now.
          await _updateOrderStatus(orderId, 'PAID', 'READY_FOR_EXIT');
          if (onSuccess != null) onSuccess();
        } else {
          if (onError != null) onError("Could not launch UPI App.");
        }
      } else {
        if (onError != null) onError("Unsupported payment mode.");
      }
    } catch (e) {
      if (onError != null) onError(e.toString());
    }
  }

  // Centralized method to update order status after payment
  Future<void> _updateOrderStatus(
      String orderId, String paymentStatus, String exitStatus) async {
    // 1. Fetch Order Context (Taki store aur tenant ka pata chale)
    DocumentSnapshot orderSnap =
        await _db.collection('orders').doc(orderId).get();
    if (!orderSnap.exists) return;

    Map<String, dynamic> orderData = orderSnap.data() as Map<String, dynamic>;
    String storeId = orderData['storeId']?.toString() ??
        orderData['branchCode']?.toString() ??
        'STORE';
    String tenantId = orderData['tenantId']?.toString() ?? '';

    // 2. Fetch Admin Prefix from Tenants Collection
    String adminPrefix = "";
    if (tenantId.isNotEmpty && tenantId != 'ALL') {
      try {
        var tSnap = await _db.collection('tenants').doc(tenantId).get();
        if (tSnap.exists) {
          var config =
              tSnap.data()?['invoiceConfig'] as Map<String, dynamic>? ?? {};
          adminPrefix = config['invoicePrefix']?.toString() ??
              config['prefix']?.toString() ??
              "";
        }
      } catch (_) {}
    }

    // 3. Generate Smart Sequential Invoice Number
    String invoiceNo = await _generateSmartInvoiceNumber(storeId, adminPrefix);

    // 4. Update the Order Database
    await _db.collection('orders').doc(orderId).set({
      'paymentStatus': paymentStatus,
      'status': paymentStatus,
      'exitStatus': exitStatus,
      'paymentCompletedAt': FieldValue.serverTimestamp(),
      'invoiceNo': invoiceNo, // 🚀 NAYA INVOICE NUMBER SAVE HOGA
    }, SetOptions(merge: true));
  }

  // 🧠 THE MASTER ENGINE: Generates INV/YY-YY/MM-DD-01
  Future<String> _generateSmartInvoiceNumber(
      String storeId, String adminPrefix) async {
    final now = DateTime.now();

    // 📅 Financial Year Calculation (April se March)
    int startYear = now.month >= 4 ? now.year : now.year - 1;
    int endYear = startYear + 1;
    String fyStr =
        "${(startYear % 100).toString().padLeft(2, '0')}-${(endYear % 100).toString().padLeft(2, '0')}";

    // 📆 MM-DD String
    String dateStr =
        "${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    // 📝 Daily Counter Document (Roz raat 12 baje ke baad naya document use hoga)
    String todayKey =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    String counterDocId = "${storeId}_$todayKey";

    DocumentReference counterRef =
        _db.collection('daily_invoice_counters').doc(counterDocId);

    // ⚡ Atomic Transaction (Race Condition Proof - Agar 2 log sath me pay kare toh clash na ho)
    int sequenceNumber = await _db.runTransaction((transaction) async {
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

    // 🎯 Format Sequence (e.g., 1 becomes 01, 2 becomes 02)
    String seqStr = sequenceNumber.toString().padLeft(2, '0');

    // Return the final formatted string
    return "$adminPrefix$fyStr/$dateStr-$seqStr";
  }
}
