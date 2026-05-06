import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:phonepe_payment_sdk/phonepe_payment_sdk.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhonePeService {
  final String environment = "SANDBOX";
  final String appId = "";
  final String merchantId =
      "PGTESTPAYUAT86"; // ℹ️ Public Merchant ID safe hai. Salt key backend pe hai!

  // 1. INITIALIZE PHONEPE
  Future<void> initPhonePe() async {
    bool result = await PhonePePaymentSdk.init(
        environment, appId, merchantId, true); // true = enable logging
    debugPrint("PhonePe SDK Initialized: $result");
  }

  // 2. FETCH SECURE PAYLOAD & FIRE PAYMENT
  Future<void> startPayment({
    required BuildContext context,
    required double amount,
    required String orderId,
    required String tenantId, // 🔒 ADDED
    required String storeId, // 🔒 ADDED
    required Function(String status, String message) onCompletion,
  }) async {
    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('generatePaymentPayload');

      final payloadResponse = await callable.call({
        'orderId': orderId,
        'amount': amount,
        'gateway': 'PHONEPE',
        'tenantId': tenantId, // 🔒 ADDED
        'storeId': storeId, // 🔒 ADDED
      });

      final String base64Body = payloadResponse.data['base64Body'];
      final String checksum = payloadResponse.data['checksum'];

      var response = await PhonePePaymentSdk.startTransaction(
        base64Body,
        "https://webhook.site/callback",
        checksum,
        "",
      );

      if (response != null) {
        String status = response['status'].toString();
        String error = response['error'].toString();

        if (status == 'SUCCESS') {
          onCompletion('SUCCESS', "Payment successful! Syncing with server...");
        } else {
          onCompletion('FAILED', "Payment failed: $error");
        }
      } else {
        onCompletion('CANCELLED', "User cancelled the payment.");
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint("Server Error: ${e.code} - ${e.message}");
      onCompletion('ERROR', "Secure connection failed: ${e.message}");
    } catch (e) {
      debugPrint("PhonePe Error: $e");
      onCompletion('ERROR', e.toString());
    }
  }

  // 🚀 SECURE VERIFICATION: Ab app PhonePe se nahi, apne Firebase server se puchegi!
  // Webhook ne order ko PAID mark kiya ya nahi, bas wo check karna hai.
  Future<bool> checkPaymentStatus(String orderId) async {
    try {
      debugPrint("Checking real status from FIRESTORE for Order: $orderId");

      var doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        // 🔒 CHECK: Kya humare Webhook ne isko PAID mark kar diya hai?
        if (data['paymentStatus'] == 'PAID') {
          return true; // 🟢 Server Confirmed Payment Success!
        }
      }
      return false; // 🔴 Still Pending or Failed
    } catch (e) {
      debugPrint("Status Check Error: $e");
      return false;
    }
  }
}
