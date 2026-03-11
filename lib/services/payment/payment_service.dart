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
    await _db.collection('orders').doc(orderId).set({
      'paymentStatus': paymentStatus,
      'status': paymentStatus,
      'exitStatus': exitStatus,
      'paymentCompletedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
