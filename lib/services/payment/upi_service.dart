// lib/services/payment/upi_service.dart
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum SupportedUpiApp { gpay, phonepe, paytm, generic }

class UpiService {
  static Future<bool> initiatePayment({
    required String upiId,
    required String merchantName,
    required double amount,
    required String orderId,
    SupportedUpiApp app = SupportedUpiApp.generic,
  }) async {
    HapticFeedback.mediumImpact();

    if (upiId.isEmpty) {
      throw 'UPI ID is not configured by the merchant.';
    }

    final String urlParams =
        '?pa=$upiId&pn=${Uri.encodeComponent(merchantName)}&am=${amount.toStringAsFixed(2)}&tr=$orderId&cu=INR&mode=00';

    String urlString;

    if (kIsWeb) {
      urlString = 'upi://pay$urlParams';
    } else {
      switch (app) {
        case SupportedUpiApp.gpay:
          urlString = 'gpay://upi/pay$urlParams';
          break;
        case SupportedUpiApp.phonepe:
          urlString = 'phonepe://pay$urlParams';
          break;
        case SupportedUpiApp.paytm:
          urlString = 'paytmmp://pay$urlParams';
          break;
        case SupportedUpiApp.generic:
          urlString = 'upi://pay$urlParams';
          break;
      }
    }

    final Uri targetUri = Uri.parse(urlString);
    final Uri genericUri = Uri.parse('upi://pay$urlParams');

    try {
      if (!kIsWeb && await canLaunchUrl(targetUri)) {
        return await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(genericUri)) {
        return await launchUrl(genericUri,
            mode: LaunchMode.externalApplication);
      } else {
        throw 'No UPI App found. Please install GPay, PhonePe or Paytm.';
      }
    } catch (e) {
      throw 'Payment gateway failed to launch: $e';
    }
  }
}
