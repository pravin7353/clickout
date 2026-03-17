// lib/services/system/auto_heal_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AutoHealService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🩺 THE SYSTEM DOCTOR: Scans and fixes corrupted database states
  Future<void> healCorruptedOrders(String userId) async {
    try {
      debugPrint("🩺 AutoHeal: Scanning for corrupted orders...");
      final snapshot = await _db
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();

      WriteBatch batch = _db.batch();
      bool needsHealing = false;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        String exitStatus = (data['exitStatus'] ?? '').toString().toUpperCase();
        String payStatus =
            (data['paymentStatus'] ?? '').toString().toUpperCase();
        bool isQrConsumed = data['qrConsumed'] == true;
        bool wasEverRejected = data['wasEverRejected'] == true;

        Map<String, dynamic> updates = {};

        // 🐛 GLITCH 1: The "Gate Pass Used" Bug
        // Guard scanned the QR (qrConsumed = true), but app glitched and kept status as READY_FOR_EXIT
        if (isQrConsumed &&
            (exitStatus == 'READY_FOR_EXIT' || exitStatus == 'PENDING') &&
            payStatus == 'PAID') {
          updates['exitStatus'] = wasEverRejected ? 'EXITED' : 'APPROVED';
          updates['systemNote'] =
              'Auto-healed: Force synced exitStatus with consumed QR.';
          needsHealing = true;
        }

        // 🐛 GLITCH 2: The "Ghost Expired" Bug
        // 8 hours passed, but the order is still showing as READY_FOR_EXIT
        DateTime? expiresAt = (data['qrExpiresAt'] as Timestamp?)?.toDate();
        if (expiresAt != null &&
            DateTime.now().isAfter(expiresAt) &&
            exitStatus == 'READY_FOR_EXIT' &&
            !isQrConsumed) {
          updates['exitStatus'] = 'EXPIRED';
          updates['qrConsumed'] = true; // Lock it down
          updates['systemNote'] =
              'Auto-healed: Order expired while waiting for guard.';
          needsHealing = true;
        }

        // Add updates to batch if glitch found
        if (updates.isNotEmpty) {
          debugPrint("🔧 AutoHeal: Fixing glitch in order ${doc.id}");
          batch.update(doc.reference, updates);
        }
      }

      // Execute all fixes at once
      if (needsHealing) {
        await batch.commit();
        debugPrint(
            "✅ AutoHeal: Corrupted database entries fixed successfully!");
      } else {
        debugPrint("✅ AutoHeal: Database is healthy. No glitches found.");
      }
    } catch (e) {
      debugPrint("❌ AutoHeal Error: $e");
    }
  }
}
