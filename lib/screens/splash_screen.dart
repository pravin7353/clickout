import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🚀 Added for Firebase Session
import '../utils/user_session.dart'; // 🚀 Added to restore Store ID
import 'home_screen.dart'; // update this based on your auth flow

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // 🎨 BRAND COLORS FROM DESIGN SYSTEM & NEW THEME
  final Color darkBaseColor =
      const Color(0xFF101010); // 🚀 Near-black for new theme
  final Color deepGreen =
      const Color(0xFF052E16); // 🚀 Design System deep green
  final Color brandGreen =
      const Color(0xFF16A34A); // 🚀 Design System vibrant green

  // ANIMATION CONTROLLERS
  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;

  late AnimationController _scannerController;
  late Animation<double> _scannerPosition;

  late AnimationController _verifiedController;
  late Animation<double> _verifiedScale;

  @override
  void initState() {
    super.initState();

    // 1. LOGO ANIMATION (0.6 to 1.0 Spring Effect)
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // 2. SCANNER LASER ANIMATION (Sweeps top to bottom)
    _scannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scannerPosition = Tween<double>(begin: -50, end: 150).animate(
      CurvedAnimation(parent: _scannerController, curve: Curves.easeInOut),
    );

    // 3. VERIFIED CHECKMARK ANIMATION (Pops up at the end)
    _verifiedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _verifiedScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _verifiedController, curve: Curves.elasticOut),
    );

    _runAnimationSequence();
  }

  void _runAnimationSequence() async {
    // Step 1: Pop the logo
    await _logoController.forward();

    // Step 2: Run the scanner laser over the logo
    await _scannerController.forward();

    // Step 3: Pop the verified checkmark
    await _verifiedController.forward();

    // Hold for a moment so user registers the premium feel
    await Future.delayed(const Duration(milliseconds: 600));

    // 🚀 THE FIX: Force App to wait until Firebase fully restores the saved Login Session!
    try {
      // 1. Wait for Firebase to verify token from memory
      await FirebaseAuth.instance.authStateChanges().first;
      // 2. Restore Old Store ID / Tenant ID so cart works instantly
      await UserSession.restoreSession();
    } catch (e) {
      debugPrint("Session restore warning: $e");
    }

    // Navigate to next screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _scannerController.dispose();
    _verifiedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBaseColor, // 🚀 NEW THEME: Near-black background
      body: Stack(
        children: [
          // 🌟 1. BACKGROUND TEXTURE (Once assets are ready, place image here)
          // Center(
          //   child: Image.asset(
          //     'assets/background_texture.png', // textured circuit board background asset
          //     opacity: const AlwaysStoppedAnimation(0.2), // keep it subtle
          //     fit: BoxFit.cover,
          //   ),
          // ),

          // 🌟 2. SUBTLE BACKGROUND BLOOM (Premium deepGreen glow from Design System)
          Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:
                        deepGreen.withOpacity(0.15), // subtle deep green glow
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          // 🎯 3. MAIN CONTENT
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // STEP 1 & 2: LOGO WITH SCANNER LASER
                SizedBox(
                  height: 120, // Bounding box for laser
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // LOGO TEXT
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScale.value,
                            child: Opacity(
                              opacity: _logoOpacity.value,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    "Click",
                                    style: TextStyle(
                                      fontFamily:
                                          'Plus Jakarta Sans', // 🚀 Naya Font (Headings)
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      color: Colors
                                          .white, // 🚀 Colors from new theme image
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  Text(
                                    "Out",
                                    style: TextStyle(
                                      fontFamily:
                                          'Plus Jakarta Sans', // 🚀 Naya Font (Headings)
                                      fontSize: 48,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          brandGreen, // 🚀 Brand GreenAccent from Design System
                                      letterSpacing: -1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      // LASER SWEEP (The Cyber/Scan vibe from your image)
                      AnimatedBuilder(
                        animation: _scannerController,
                        builder: (context, child) {
                          if (!_scannerController.isAnimating &&
                              _scannerController.isDismissed) {
                            return const SizedBox.shrink();
                          }
                          return Positioned(
                            top: _scannerPosition.value,
                            child: Opacity(
                              opacity:
                                  _scannerController.value > 0.9 ? 0.0 : 1.0,
                              child: Container(
                                width: 200,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: brandGreen,
                                  boxShadow: [
                                    BoxShadow(
                                      color: brandGreen.withOpacity(0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // STEP 3: VERIFIED CHECKMARK
                AnimatedBuilder(
                  animation: _verifiedController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _verifiedScale.value,
                      child: Opacity(
                        opacity: _verifiedScale.value.clamp(0.0, 1.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: brandGreen
                                .withOpacity(0.15), // subtle green background
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: brandGreen.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: brandGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check,
                                    color: Colors.black,
                                    size: 14), // clean checkmark
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "SYSTEM SECURE",
                                style: TextStyle(
                                  fontFamily:
                                      'DM Sans', // 🚀 Font for body text
                                  color: brandGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
