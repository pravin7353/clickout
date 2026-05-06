import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart'; // 🚀 NAYA IMPORT ADDED

class RazorpayService {
  late Razorpay _razorpay;

  // 🧑‍🏫 1. INITIALIZATION
  void initializeRazorpay({
    required Function(PaymentSuccessResponse) onSuccess,
    required Function(PaymentFailureResponse) onFailure,
  }) {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, onFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET,
        (ExternalWalletResponse response) {
      debugPrint("External Wallet Selected: ${response.walletName}");
    });
  }

  // 🧑‍🏫 2. CHECKOUT POPUP: Ab backend se secure ID mangwayega
  Future<void> openCheckout({
    required double amount,
    required String orderId,
    required String storeName,
    required String contactNumber,
  }) async {
    try {
      // 🧠 Ask Node.js Backend to generate secure Razorpay Order ID
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('generatePaymentPayload');

      final response = await callable.call({
        'orderId': orderId,
        'amount': amount,
        'gateway': 'RAZORPAY',
      });

      final String rzpKey = response.data['key'];
      final String rzpOrderId = response.data['razorpayOrderId'];

      var options = {
        'key': rzpKey, // Backend se aayi hui public key
        'amount': (amount * 100).toInt(),
        'name': storeName,
        'order_id': rzpOrderId, // 🔒 NAYA ADD: Server generated Secure Order ID
        'description': 'Order: $orderId',
        'prefill': {'contact': contactNumber, 'email': 'customer@clickout.in'},
        'theme': {'color': '#C62828'}
      };

      _razorpay.open(options);
    } on FirebaseFunctionsException catch (e) {
      debugPrint("Server Error: ${e.code} - ${e.message}");
      // TODO: Handle Error UI for user (e.g. ScaffoldMessenger)
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // 🧑‍🏫 3. CLEANUP
  void dispose() {
    _razorpay.clear();
  }
}
