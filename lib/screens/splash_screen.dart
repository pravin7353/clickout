import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_options.dart';
import '../services/system/store_entry_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../utils/user_session.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = "Starting ClickOut...";

  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);

  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    try {
      await Future.delayed(const Duration(seconds: 1));

      if (Firebase.apps.isEmpty) {
        setState(() => _status = "Connecting to Server...");
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      setState(() => _status = "Checking User...");
      final user = FirebaseAuth.instance.currentUser;

      // 🚀 THE FIX: Purana session wapas laao!
      await UserSession.restoreSession();

      if (!mounted) return;

      if (user != null) {
        // 🚀 THE MAGIC: Check if entering via Web QR Link
        StoreEntryService.checkWebEntryUrl();
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    } catch (e) {
      setState(() => _status = "Error: $e");
      debugPrint("Splash Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cherryRedLight, cherryRedDark],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart_rounded,
                  size: 50, color: cherryRedDark),
            ),
            const SizedBox(height: 20),
            const Text(
              "ClickOut",
              style: TextStyle(
                fontFamily: 'DejaVuSansMono',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 50),
            Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
