// lib/services/payment/cash_payment_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class CashPaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 💵 INITIATE CASH CHECKOUT (Customer App -> Cashier Counter)
  Future<void> requestCashCheckout({
    required String orderId,
    required double amount,
    required String
        counterNumber, // Optional: if you have specific cash counters
  }) async {
    try {
      // Update order to notify cashier
      await _db.collection('orders').doc(orderId).set({
        'paymentMode': 'CASH',
        'status':
            'payment_pending_cash', // Cashier dashboard will listen to this status
        'paymentStatus': 'PENDING',
        'cashCounterAllocation': counterNumber,
        'cashRequestTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
          "Cash payment requested for Order: $orderId at Counter: $counterNumber");
    } catch (e) {
      debugPrint("Cash Payment Request Error: $e");
      throw "Failed to request cash checkout. Please try again.";
    }
  }

  // ✅ APPROVE CASH PAYMENT (Cashier App Only)
  Future<void> approveCashPaymentByCashier({
    required String orderId,
    required String cashierId,
  }) async {
    try {
      await _db.collection('orders').doc(orderId).set({
        'status': 'PAID',
        'paymentStatus': 'PAID',
        'exitStatus': 'READY_FOR_EXIT', // Unlocks the Gate Pass
        'cashReceivedBy': cashierId,
        'paymentCompletedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
          "Cash payment approved for Order: $orderId by Cashier: $cashierId");
    } catch (e) {
      debugPrint("Cash Approval Error: $e");
      throw "Failed to approve cash payment.";
    }
  }
}
