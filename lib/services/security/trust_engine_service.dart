// lib/services/security/trust_engine_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class TrustEngineService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🎯 THE CHANAKYA TRUST SCORE ENGINE
  Future<void> updateTrustScore(String userId, double delta,
      {required bool isReward}) async {
    try {
      final userRef = _db.collection('users').doc(userId);

      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);

        // Default to 80.0 (Innocent until proven guilty)
        double currentScore = 80.0;
        if (snapshot.exists && snapshot.data()?['trustScore'] != null) {
          currentScore = (snapshot.data()?['trustScore'] as num).toDouble();
        }

        double newScore = currentScore;

        if (isReward) {
          // 🛡️ DIMINISHING RECOVERY (Anti-Gaming Shield)
          double appliedReward = delta; // default +2
          if (currentScore < 40) {
            appliedReward = 0.25; // Brutal redemption path
          } else if (currentScore < 60) {
            appliedReward = 0.5;
          } else if (currentScore < 80) {
            appliedReward = 1.0;
          }
          newScore = currentScore + appliedReward;
          if (newScore > 100) newScore = 100.0;
        } else {
          // ⚔️ SURGICAL STRIKE PENALTY
          newScore = currentScore - delta;
          if (newScore < 0) newScore = 0.0;
        }

        // 🧠 Update the user's permanent record
        transaction.set(
            userRef,
            {
              'trustScore': double.parse(newScore.toStringAsFixed(2)),
              'lastActivityAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });
    } catch (e) {
      debugPrint("Trust Score Engine Error: $e");
    }
  }
}
