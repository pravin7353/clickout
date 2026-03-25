import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  // 👤 User Identity
  static String get uid {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  // 🚀 DEFAULT EMPTY (RAM)
  static String tenantId = '';
  static String storeId = '';
  static String branchCode = '';

  // 🏪 1. SAVE TO RAM & DISK (Jab QR Scan ho)
  static Future<void> setStoreContext({
    required String tId,
    required String sId,
    required String bCode,
  }) async {
    // Save to RAM for instant UI update
    tenantId = tId;
    storeId = sId;
    branchCode = bCode;

    // Save to Disk for Crash/Offline protection
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tenantId', tId);
    await prefs.setString('storeId', sId);
    await prefs.setString('branchCode', bCode);
  }

  // 🔄 2. LOAD FROM DISK (Jab App Boot ho)
  static Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    tenantId = prefs.getString('tenantId') ?? '';
    storeId = prefs.getString('storeId') ?? '';
    branchCode = prefs.getString('branchCode') ?? '';
  }

  // 🚪 3. CLEAR SESSION (Jab Customer Store se bahar nikle)
  static Future<void> clearSession() async {
    tenantId = '';
    storeId = '';
    branchCode = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tenantId');
    await prefs.remove('storeId');
    await prefs.remove('branchCode');
  }
}
