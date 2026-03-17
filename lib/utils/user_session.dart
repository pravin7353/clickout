import 'package:firebase_auth/firebase_auth.dart';

class UserSession {
  // 👤 User Identity
  static String get uid {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  // 🏪 THE SAAS ROUTING IDs (Customer kis dukan me hai)
  static String tenantId = 'tnt_clickout'; // Default for testing
  static String storeId = 'str_mumbai_01'; // Default for testing
  static String branchCode = 'MART01'; // Legacy fallback

  // 🚀 Jab customer Dukan ka QR scan karega tab ye function call hoga
  static void setStoreContext({
    required String tId,
    required String sId,
    required String bCode,
  }) {
    tenantId = tId;
    storeId = sId;
    branchCode = bCode;
  }
}
