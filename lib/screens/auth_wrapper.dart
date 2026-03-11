import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../widgets/custom_loader.dart';
import '../services/auth/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CustomLoader();
        }

        if (snapshot.hasData && snapshot.data != null) {
          // 🛡️ User is logged in, pass them through the Session Guard
          return SessionGuard(user: snapshot.data!, child: const HomeScreen());
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

// 🛡️ AGGRESSIVE SECURITY WIDGET: Protects from multiple logins
class SessionGuard extends StatefulWidget {
  final User user;
  final Widget child;
  const SessionGuard({super.key, required this.user, required this.child});

  @override
  State<SessionGuard> createState() => _SessionGuardState();
}

class _SessionGuardState extends State<SessionGuard> {
  String? localSessionId;
  bool isChecking = true;

  @override
  void initState() {
    super.initState();
    _loadLocalSession();
  }

  Future<void> _loadLocalSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      localSessionId = prefs.getString('localSessionId');
      isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Wait for local memory to read
    if (isChecking) return const CustomLoader();

    // 2. 🚨 FORCED KICK-OUT: If local session is missing (e.g., cleared on Web Refresh)
    if (localSessionId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await AuthService().signOut();
        if (mounted) {
          // Forcefully clear all screens and go to Login
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        }
      });
      return const CustomLoader();
    }

    // 3. 📡 Live listen to Firestore User Document
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return widget.child;

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data != null) {
          final serverSessionId = data['activeSessionId'];

          // 🚨 CLOUD KICK-OUT: Mismatch detected! (Device B logged in)
          if (serverSessionId != null && serverSessionId != localSessionId) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await AuthService().signOut();

              if (mounted) {
                // 🔥 CRITICAL FIX: Faad do saari navigation history!
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        "Session Expired! You logged in on another device.",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    backgroundColor: Colors.redAccent,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            });
            return const CustomLoader(); // Prevent rendering anything else
          }
        }

        // ✅ All good, load the actual app screen
        return widget.child;
      },
    );
  }
}
