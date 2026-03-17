import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class UnifiedAuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🧠 HELPER: Create Session ID (Ye ab Auto-login mein bhi chalega)
  static Future<void> _setupUserSession(UserCredential userCred) async {
    String sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('localSessionId', sessionId);

    String? fcmToken;
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint("FCM error: $e");
    }

    await _db.collection('users').doc(userCred.user!.uid).set({
      'phone': userCred.user!.phoneNumber,
      'activeSessionId': sessionId,
      'lastLoginAt': FieldValue.serverTimestamp(),
      'lastDeviceId': 'MobileApp',
      'fcmTokens': fcmToken != null ? FieldValue.arrayUnion([fcmToken]) : [],
    }, SetOptions(merge: true));
  }

  // ==========================================================
  // 📱 1. PHONE OTP ENGINE (Smart Rate Limiting + Auto Verify Fix)
  // ==========================================================
  static Future<void> sendPhoneOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required VoidCallback onAutoLoginSuccess, // 🔥 Naya Hatiyar
  }) async {
    try {
      // 🛑 SMART RATE LIMITER (3 OTPs -> 5 Min Block)
      final prefs = await SharedPreferences.getInstance();
      int attempts = prefs.getInt('otp_attempts_$phone') ?? 0;
      int blockUntil = prefs.getInt('otp_block_$phone') ?? 0;
      int now = DateTime.now().millisecondsSinceEpoch;

      if (now < blockUntil) {
        int remainingMin = ((blockUntil - now) / 60000).ceil();
        onError("Too many attempts. Blocked for $remainingMin minutes.");
        return;
      }

      if (attempts >= 3) {
        await prefs.setInt(
            'otp_block_$phone', now + (5 * 60 * 1000)); // 5 min block
        await prefs.setInt('otp_attempts_$phone', 0);
        onError("Limit reached. System blocked for 5 minutes.");
        return;
      }

      await prefs.setInt('otp_attempts_$phone', attempts + 1);

      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        // 🔥 THE AUTO-VERIFY FIX (Login Loop Yahan Khatam Hoga)
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            UserCredential userCred =
                await _auth.signInWithCredential(credential);
            await _setupUserSession(userCred); // 🚨 Guard ko ID card de diya!

            // Reset Limits on Success
            await prefs.remove('otp_attempts_$phone');
            await prefs.remove('otp_block_$phone');

            onAutoLoginSuccess();
          } catch (e) {
            onError("Auto-login failed: $e");
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? "Verification Failed");
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      onError(e.toString());
    }
  }

// 📝 2. MANUAL OTP VERIFICATION
  static Future<void> verifyManualOTP({
    required String verificationId,
    required String otp,
    required VoidCallback onSuccess,
    required Function(String error) onError,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      UserCredential userCred = await _auth.signInWithCredential(credential);

      await _setupUserSession(userCred); // 🚨 User details save to Firestore

      // Reset limits
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('otp_attempts_${userCred.user?.phoneNumber}');
      await prefs.remove('otp_block_${userCred.user?.phoneNumber}');

      onSuccess();

      // 🚀 THE FIX: Asli error screen par dikhao!
    } on FirebaseAuthException catch (e) {
      onError("Firebase Blocked: ${e.code}");
    } catch (e) {
      onError("System Error: $e");
    }
  }

  // 🚪 3. GLOBAL LOGOUT
  static Future<void> logout(String roleCollection) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _db.collection(roleCollection).doc(user.uid).update({
        'activeSessionId': FieldValue.delete(),
      });
    }
    await _auth.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('localSessionId');
  }
}
