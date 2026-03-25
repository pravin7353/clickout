// lib/services/security/blackbox_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../utils/user_session.dart'; // 🚀 SAAS INJECTION IMPORT

class BlackBoxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 📝 LOG CRITICAL SECURITY EVENTS
  Future<void> logEvent({
    required String
        eventType, // e.g., 'QR_REUSE_ATTEMPT', 'GATE_REJECTION', 'INVENTORY_MISMATCH'
    required String description,
    String? orderId,
    String? guardId,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // 'blackbox_logs' should ideally be an append-only collection in Firestore rules
      await _db.collection('blackbox_logs').add({
        'eventType': eventType,
        'description': description,
        'orderId': orderId,
        'guardId': guardId,
        'userId': user?.uid,
        'userEmail': user?.email,
        'extraData': extraData ?? {},
        'timestamp': FieldValue.serverTimestamp(),
        'tenantId': UserSession.tenantId, // 🚀 SAAS INJECTION
        'storeId': UserSession.storeId, // 🚀 SAAS INJECTION
      });

      debugPrint("⬛ BLACKBOX LOGGED: $eventType");
    } catch (e) {
      debugPrint("BlackBox Error: $e");
    }
  }
}
