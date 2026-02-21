import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../theme/app_theme.dart';

class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              // 📍 BIG LOCATION ICON (Animation feel)
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 80,
                  color: AppTheme.primaryBlue,
                ),
              ),

              const SizedBox(height: 30),

              // 📝 TITLE
              const Text(
                'What\'s your Location?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),

              const SizedBox(height: 12),

              // 📄 SUBTITLE
              const Text(
                'We need your location to show available\nproducts & fast delivery options.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),

              const Spacer(),

              // 🔘 ENABLE LOCATION BUTTON (Primary)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange, // 🔥 Orange Pop
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  onPressed: loading ? null : _getCurrentLocation,
                  child: loading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.my_location),
                            SizedBox(width: 10),
                            Text(
                              'Use Current Location',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // 🔍 MANUAL SEARCH BUTTON (Secondary)
              TextButton(
                onPressed: () {
                  // Abhi directly Home bhej rahe hain, baad me Google Places lagayenge
                  _navigateToHome();
                },
                child: const Text(
                  'Search Manually',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 🛰️ LOCATION LOGIC (Simulation for now)
  Future<void> _getCurrentLocation() async {
    setState(() => loading = true);

    // 🛑 Note: Asli app me yahan 'geolocator' package use hoga.
    // Abhi hum 2 second ka fake delay dikha ke permission maan lenge
    // taaki tumhara flow na ruke.

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Permission granted (simulated) -> Go Home
    _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }
}
