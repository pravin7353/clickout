import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../services/cart_service.dart';
import '../widgets/product_search_delegate.dart';
import 'scan_product_screen.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final User? user = FirebaseAuth.instance.currentUser;

  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);

  // 🎞️ SLIDESHOW VARIABLES
  int _currentSlideIndex = 0;
  Timer? _slideTimer;
  final List<Map<String, dynamic>> _slides = [
    {
      "title": "Start Shopping",
      "subtitle": "Scan items to add to cart.",
      "icon": Icons.qr_code_scanner
    },
    {
      "title": "Skip the Queue",
      "subtitle": "Pay online & generate Gate Pass.",
      "icon": Icons.run_circle_outlined
    },
    {
      "title": "Easy Payment",
      "subtitle": "UPI, Cards & Net Banking supported.",
      "icon": Icons.payment
    },
    {
      "title": "Family Mode",
      "subtitle": "Best offers applied automatically.",
      "icon": Icons.family_restroom
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      setState(() {
        _currentSlideIndex = (_currentSlideIndex + 1) % _slides.length;
      });
    });

    _checkLocationPermission();
  }

  Future<void> _checkLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideTimer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildCherryHomeBody(),
      const CartScreen(),
      const ProfileScreen()
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: pages[_selectedIndex],

      // 🦶 BOTTOM BAR
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: cherryRedDark,
          unselectedItemColor: Colors.grey[400],
          selectedLabelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded, size: 28), label: 'Home'),
            BottomNavigationBarItem(
              icon: Consumer<CartService>(
                builder: (context, cart, child) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.shopping_cart_rounded, size: 28),
                      if (cart.totalItems > 0)
                        Positioned(
                          right: -5,
                          top: -5,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              '${cart.totalItems}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded, size: 28), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  // 🍒 HOME UI
  Widget _buildCherryHomeBody() {
    return Stack(
      children: [
        Container(
          height: 250,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cherryRedLight, cherryRedDark],
            ),
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40)),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // NAME SECTION
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(user?.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String displayName = 'User';
                        if (snapshot.hasData &&
                            snapshot.data != null &&
                            snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;
                          if (data['name'] != null &&
                              data['name'].toString().isNotEmpty) {
                            displayName = data['name'].toString().split(' ')[0];
                          }
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('ClickOut',
                                style: TextStyle(
                                    fontFamily: 'DejaVuSansMono',
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Text('Hi, ',
                                    style: TextStyle(
                                        fontFamily: 'DejaVuSansMono',
                                        color: Colors.white,
                                        fontSize: 28)),
                                Text(displayName,
                                    style: const TextStyle(
                                        fontFamily: 'DejaVuSansMono',
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        );
                      },
                    ),

                    // 🔍 SEARCH BUTTON WITH MESSAGE
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _glassButton(Icons.search, () {
                          showSearch(
                              context: context,
                              delegate: ProductSearchDelegate());
                        }),
                        const SizedBox(height: 5),
                        // ✨ YEH HAI WO MESSAGE
                        GestureDetector(
                          onTap: () {
                            showSearch(
                                context: context,
                                delegate: ProductSearchDelegate());
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8)),
                            child: const Text(
                              "Scan failed? Search ↗",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // SLIDESHOW
              Container(
                height: 80,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Row(
                    key: ValueKey<int>(_currentSlideIndex),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: cherryRedLight.withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: Icon(_slides[_currentSlideIndex]['icon'],
                            color: cherryRedDark, size: 24),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_slides[_currentSlideIndex]['title'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(_slides[_currentSlideIndex]['subtitle'],
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // SCAN BUTTON
              Column(
                children: [
                  const Text("Ready to Checkout?",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87)),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ScanProductScreen()));
                    },
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        height: 180,
                        width: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                                color: cherryRedDark.withOpacity(0.25),
                                blurRadius: 30,
                                spreadRadius: 10,
                                offset: const Offset(0, 10))
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [cherryRedLight, cherryRedDark]),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.qr_code_scanner_rounded,
                                  size: 60, color: Colors.white),
                              SizedBox(height: 8),
                              Text('SCAN',
                                  style: TextStyle(
                                      fontFamily: 'DejaVuSansMono',
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // HISTORY BUTTON
              Container(
                width: double.infinity,
                margin:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OrderHistoryScreen()));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 5,
                    shadowColor: Colors.black12,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: Icon(Icons.receipt_long, color: cherryRedDark),
                  label: const Text(" View Gate Pass & History",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _glassButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white30),
        ),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
