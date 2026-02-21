import 'package:firebase_auth/firebase_auth.dart';

class UserSession {
  // ✅ Safe Getter: Agar user null hai, toh empty string return karega (Crash nahi karega)
  static String get uid {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }
}
