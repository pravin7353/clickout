import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // 🚀 FCM IMPORT ADDED

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Send OTP (Unchanged)
  Future<void> sendOTP({
    required String phone,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
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

  // 2. Verify OTP (Injected Session & FCM Logic)
  Future<void> verifyOTP({
    required String verificationId,
    required String otp,
    required VoidCallback onSuccess,
    required Function(String) onError,
  }) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      UserCredential userCred = await _auth.signInWithCredential(credential);

      // 🔒 SECURITY PATCH: Generate & Save Session
      if (userCred.user != null) {
        String sessionId = DateTime.now().millisecondsSinceEpoch.toString();

        // Save to Local Device
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('localSessionId', sessionId);

        // 🧠 FCM TOKEN HARVESTING (Chanakya Niti: Keep the intelligence network active)
        String? fcmToken;
        try {
          fcmToken = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          debugPrint("FCM Token fetch error: $e");
        }

        // Save to Cloud (Firestore)
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCred.user!.uid)
            .set({
          'phone': userCred.user!.phoneNumber,
          'activeSessionId': sessionId,
          'lastLoginAt': FieldValue.serverTimestamp(),
          'lastDeviceId': 'MobileApp',
          // 👉 Save the token in an array so multiple devices can receive alerts
          'fcmTokens':
              fcmToken != null ? FieldValue.arrayUnion([fcmToken]) : [],
        }, SetOptions(merge: true));
      }

      onSuccess();
    } catch (e) {
      onError("Invalid OTP. Please try again.");
    }
  }

  // 3. Sign Out
  Future<void> signOut() async {
    // Optional Pro-Tip: Yahan logout hone par fcmTokens array se token remove bhi kar sakte hain future me.
    await _auth.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('localSessionId');
  }
}
