// lib/services/gate/guard_verification_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class GuardVerificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🔎 SCAN & VERIFY QR
  Future<Map<String, dynamic>> verifyGatePass(String base64QrData) async {
    try {
      // 1. Decode QR
      final String decodedStr = utf8.decode(base64Decode(base64QrData));
      final Map<String, dynamic> qrData = jsonDecode(decodedStr);

      final String orderId = qrData['oid'];
      final int qrVersion = qrData['v'] ?? 1;

      // 2. Fetch Live Order from Cloud
      DocumentSnapshot doc = await _db.collection('orders').doc(orderId).get();
      if (!doc.exists) {
        return {'isValid': false, 'msg': 'Order not found in system.'};
      }

      final data = doc.data() as Map<String, dynamic>;

      // 3. Security Checks
      if (data['paymentStatus'] != 'PAID') {
        return {
          'isValid': false,
          'msg': 'Payment not completed for this order.'
        };
      }

      if (data['exitStatus'] == 'EXITED') {
        return {
          'isValid': false,
          'msg': 'ALERT: This Gate Pass has already been used!'
        };
      }

      if ((data['gatePassVersion'] ?? 1) > qrVersion) {
        return {
          'isValid': false,
          'msg':
              'Invalid QR. Customer has updated the cart. Scan the latest QR.'
        };
      }

      // If all good, show order details to guard for physical check
      return {
        'isValid': true,
        'orderId': orderId,
        'items': data['items'],
        'totalWeight': data['totalWeight'],
        'riskLevel': data['riskLevel'],
        'guardRecommendation': data['guardRecommendation'],
      };
    } catch (e) {
      debugPrint("QR Decode Error: $e");
      return {'isValid': false, 'msg': 'Corrupted or Invalid QR Code.'};
    }
  }

  // ✅ GUARD APPROVES EXIT
  Future<void> approveExit(String orderId, String guardId) async {
    await _db.collection('orders').doc(orderId).update({
      'exitStatus': 'EXITED',
      'exitApprovedBy': guardId,
      'exitTime': FieldValue.serverTimestamp(),
    });
  }

  // ❌ GUARD REJECTS EXIT (Triggers "Fix & Resubmit" for Customer)
  Future<void> rejectExit(String orderId, String guardId, String reason) async {
    await _db.collection('orders').doc(orderId).update({
      'exitStatus': 'REJECTED',
      'exitRejectedBy': guardId,
      'rejectionReason': reason,
      'rejectionTime': FieldValue.serverTimestamp(),
    });
  }
}
