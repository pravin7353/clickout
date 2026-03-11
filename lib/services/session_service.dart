// lib/services/session_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'auth/auth_service.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  Timer? _inactivityTimer;
  final int _timeoutMinutes = 10;
  final AuthService _authService = AuthService();

  // 🏁 START SESSION (Call this after successful login)
  void startSession(BuildContext context) {
    _resetTimer(context);
  }

  // 🔄 RECORD ACTIVITY (Call this on screen taps/scrolls using a GestureDetector wrapping the app)
  void recordActivity(BuildContext context) {
    _resetTimer(context);
  }

  void _resetTimer(BuildContext context) {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(minutes: _timeoutMinutes), () {
      _logoutUser(context);
    });
  }

  Future<void> _logoutUser(BuildContext context) async {
    debugPrint("⏳ Session Expired due to inactivity.");
    _inactivityTimer?.cancel();

    await _authService.signOut();

    // Yahan aap apne login screen ka route dalenge
    // Navigator.of(context).pushAndRemoveUntil(..., (route) => false);
  }

  // 🛑 STOP SESSION (Call this on manual logout)
  void stopSession() {
    _inactivityTimer?.cancel();
  }
}
