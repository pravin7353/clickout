// lib/services/gate/gatepass_service.dart
import 'dart:convert';

class GatePassService {
  // 🔐 GENERATE SECURE QR DATA
  // Ye function payment success hone ke baad call hoga
  String generateSecureQRData({
    required String orderId,
    required String userId,
    required int gatePassVersion,
  }) {
    // Expiry time set to 30 mins from generation
    final expiryTime =
        DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch;

    final Map<String, dynamic> qrPayload = {
      'oid': orderId,
      'uid': userId,
      'v':
          gatePassVersion, // 🚀 Protects against old screenshots if order was modified
      'exp': expiryTime,
    };

    // Encode to base64 so it looks like a random string, not plain JSON
    return base64Encode(utf8.encode(jsonEncode(qrPayload)));
  }

  // ⏱️ CHECK EXPIRY LOCALLY
  bool isQRDataExpired(String base64QrData) {
    try {
      final String decodedStr = utf8.decode(base64Decode(base64QrData));
      final Map<String, dynamic> data = jsonDecode(decodedStr);

      final int expiry = data['exp'] ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      return currentTime > expiry;
    } catch (e) {
      return true; // If corrupted, treat as expired
    }
  }
}
