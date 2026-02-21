import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum SupportedUpiApp { gpay, phonepe, paytm, generic }

class UpiService {
  static Future<void> initiatePayment({
    required String upiId,
    required String merchantName,
    required double amount,
    required String orderId,
    SupportedUpiApp app = SupportedUpiApp.generic,
  }) async {
    // 📱 UX: Premium Haptic Feedback (Swiggy/Zomato style)
    HapticFeedback.mediumImpact();

    if (upiId.isEmpty) {
      throw 'UPI ID is not configured by the merchant.';
    }

    // Standard NPCI UPI URI Format
    final String urlParams =
        '?pa=$upiId&pn=${Uri.encodeComponent(merchantName)}&am=${amount.toStringAsFixed(2)}&tr=$orderId&cu=INR&mode=00';

    String urlString;

    // 🌐 PLATFORM DETECTION MAGIC
    if (kIsWeb) {
      // Browser (Mobile Web): Standard intent triggers device's default UPI chooser
      urlString = 'upi://pay$urlParams';
    } else {
      // Native Android: Target specific apps for frictionless experience
      switch (app) {
        case SupportedUpiApp.gpay:
          urlString = 'gpay://upi/pay$urlParams'; // Android specific GPay
          break;
        case SupportedUpiApp.phonepe:
          urlString = 'phonepe://pay$urlParams'; // Android specific PhonePe
          break;
        case SupportedUpiApp.paytm:
          urlString = 'paytmmp://pay$urlParams'; // Android specific Paytm
          break;
        case SupportedUpiApp.generic:
          urlString = 'upi://pay$urlParams';
          break;
      }
    }

    final Uri targetUri = Uri.parse(urlString);
    final Uri genericUri = Uri.parse('upi://pay$urlParams'); // Fallback

    try {
      // Attempt targeted app launch first
      if (!kIsWeb && await canLaunchUrl(targetUri)) {
        await launchUrl(targetUri, mode: LaunchMode.externalApplication);
      }
      // Fallback to generic UPI chooser (Web & Native Android)
      else if (await canLaunchUrl(genericUri)) {
        await launchUrl(genericUri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No UPI App found. Please install GPay, PhonePe or Paytm.';
      }
    } catch (e) {
      throw 'Payment gateway failed to launch: $e';
    }
  }
}
