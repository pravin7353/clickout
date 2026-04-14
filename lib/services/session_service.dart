import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 🚀 NAYA IMPORT
import 'auth/auth_service.dart';
import '../utils/user_session.dart'; // 🚀 Added to manage static context

class SessionService extends ChangeNotifier {
  // 🚀 Upgraded to Provider
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;

  SessionService._internal() {
    _restoreStoreSession(); // 🚀 App khulte hi memory check karega
  }

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

  // ===========================================================================
  // 🚀 SMART QR CHECK-IN ENGINE (Orange to Red Scanner Toggle)
  // ===========================================================================

  bool get isInsideStore => UserSession.storeId.isNotEmpty; // Reactive state

  // 🚀 NAYA FUNCTION: Memory se session wapas nikalne ke liye
  Future<void> _restoreStoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryStr = prefs.getString('store_session_expiry');

      if (expiryStr != null) {
        final expiryDate = DateTime.parse(expiryStr);
        if (DateTime.now().isBefore(expiryDate)) {
          // Agar 3 ghante nahi hue hain, toh UserSession wapas set kar do
          UserSession.tenantId = prefs.getString('saved_tenantId') ?? '';
          UserSession.storeId = prefs.getString('saved_storeId') ?? '';
          UserSession.branchCode = prefs.getString('saved_storeId') ?? '';

          notifyListeners(); // 🚀 UI ko wapas RED kar dega!
          debugPrint("🔄 Restored Active Store Session from Memory!");
        } else {
          // 3 ghante ho gaye, memory saaf kar do
          await exitStore();
        }
      }
    } catch (e) {
      debugPrint("🚨 Session Restore Error: $e");
    }
  }

  Future<void> checkInStore(String scannedQrData) async {
    try {
      final uri = Uri.parse(scannedQrData);

      // 🚀 BUG FIX: Bridge passes 't' and 'b'/'s', while older logic expects 'tId' and 'bCode'.
      // Humne isko flexible bana diya taki dono support karein!
      final tId = uri.queryParameters['tId'] ?? uri.queryParameters['t'];
      final bCode = uri.queryParameters['bCode'] ??
          uri.queryParameters['b'] ??
          uri.queryParameters['s'];

      if (tId != null && bCode != null && tId.isNotEmpty && bCode.isNotEmpty) {
        // 🚀 Lock user into the store session directly via static variables
        UserSession.tenantId = tId;
        UserSession.storeId = bCode;
        UserSession.branchCode = bCode;

        // 🚀 FIX: Save to Local Storage with 3-Hour Expiry
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_tenantId', tId);
        await prefs.setString('saved_storeId', bCode);
        await prefs.setString('store_session_expiry',
            DateTime.now().add(const Duration(hours: 3)).toIso8601String());

        notifyListeners(); // 🚀 MAGIC: UI WILL INSTANTLY TURN RED!
        debugPrint("✅ Checked into Store: $bCode (Tenant: $tId)");
      } else {
        throw Exception("Invalid ClickOut QR Code Format");
      }
    } catch (e) {
      debugPrint("🚨 QR Parse Error: $e");
      throw Exception("Could not check in. Please scan a valid store QR.");
    }
  }

  // 🚪 EXIT STORE
  Future<void> exitStore() async {
    await UserSession.clearSession(); // Wipes tenant/store context

    // 🚀 FIX: Clear Local Storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_tenantId');
      await prefs.remove('saved_storeId');
      await prefs.remove('store_session_expiry');
    } catch (e) {
      debugPrint("🚨 Error clearing session prefs: $e");
    }

    notifyListeners(); // 🚀 MAGIC: UI WILL INSTANTLY TURN ORANGE!
    debugPrint("🚪 Exited Store Session safely.");
  }
}
