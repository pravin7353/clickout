import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/session_service.dart';
import '../services/cart/cart_service.dart';
import '../widgets/product_search_delegate.dart';
import 'scan_product_screen.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import 'order_detail_screen.dart';
import '/utils/user_session.dart';
import '../widgets/store_offers_sheet.dart';
import '../widgets/gate_pass_tile.dart';

// ─── Design Tokens ────────────────────────────────────────────────────────────
const Color _scaffoldBg = Color(0xFFF6F6F4);
const Color _cardBg = Color(0xFFFFFFFF);
const Color _cardSubtle = Color(0xFFF2F2EF);
const Color _brandRed = Color(0xFFE53E3E);
const Color _brandRedDark = Color(0xFFC53030);
const Color _brandRedLight = Color(0xFFFFEBEB);
const Color _textPrimary = Color(0xFF111111);
const Color _textSecondary = Color(0xFF6B7280);
const Color _textMuted = Color(0xFF9CA3AF);
const Color _divider = Color(0xFFE5E7EB);
const Color _activeGreen = Color(0xFF22C55E);
const Color _amber = Color(0xFFF59E0B);
// ──────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();
  int _currentCarouselIndex = 0;
  Timer? _carouselTimer;

  late AnimationController _pulseController;
  late AnimationController _pulse2Controller;

  String _firstName = "there";

  DateTime? _lastPressedAt; // 🚀 Added for Double Tap Exit

  // 🧠 Fetch Name from Firestore
  Future<void> _fetchUserName() async {
    final String uid = UserSession.uid;
    if (uid.isEmpty) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        String fullName = doc.data()!['name']?.toString().trim() ?? '';
        if (fullName.isNotEmpty && fullName.toLowerCase() != 'deleted user') {
          setState(() {
            _firstName = fullName.split(' ')[0];
          });
        }
      }
    } catch (e) {
      debugPrint("Name fetch error: $e");
    }
  }

  final List<Map<String, dynamic>> _fomoOffers = [
    {
      "colors": [const Color(0xFF0F4C1E), const Color(0xFF06D99D)],
      "title": "WELCOME BONUS",
      "subtitle": "Extra 5% off on your First visit",
      "badge": "COMMUNITY",
      "icon": Icons.local_fire_department_rounded,
    },
    {
      "colors": [const Color(0xFFf59e0b), const Color(0xFFd97706)],
      "title": "VIP EXCLUSIVE",
      "subtitle": "Extra 15% off on your next visit",
      "badge": "VIP ONLY",
      "icon": Icons.workspace_premium_rounded,
    },
    {
      "colors": [const Color(0xFF7c3aed), const Color(0xFF6d28d9)],
      "title": "WE MISSED YOU!",
      "subtitle": "20% off — Comeback reward",
      "badge": "COMEBACK",
      "icon": Icons.card_giftcard_rounded,
    },
    {
      "colors": [const Color(0xFFED3A40), const Color(0xFF734EAE)],
      "title": "FLASH SALE",
      "subtitle": "25% off — First come, first served!",
      "badge": "FCFS",
      "icon": Icons.flash_on_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _pulse2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _pulse2Controller.forward(from: 0.35);
    });

    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        int next = (_currentCarouselIndex + 1) % _fomoOffers.length;
        _pageController.animateToPage(next,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      }
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
    _pulse2Controller.dispose();
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Future<void> _launchYouTube() async {
    final Uri url = Uri.parse('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error launching YouTube: $e");
    }
  }

  Future<void> _launchAppStore() async {
    final Uri url = Uri.parse('https://apps.apple.com/in/app/your-app-id');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _launchPlayStore() async {
    final Uri url = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.your.package');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _confirmExitStore() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _brandRed.withOpacity(0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: _brandRed),
            const SizedBox(width: 8),
            Text("Exit Store?",
                style: GoogleFonts.syne(
                    color: _textPrimary, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          "Are you sure you want to exit? Your cart will be saved for a limited time.",
          style: GoogleFonts.dmSans(color: _textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: GoogleFonts.dmSans(color: _textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brandRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text("Yes, Exit",
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<SessionService>().exitStore();
    }
  }

  // ─── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final List<Widget> pages = [
      _buildDashboard(),
      const CartScreen(),
      const ProfileScreen(),
    ];

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        if (_selectedIndex != 0) {
          setState(() => _selectedIndex = 0);
          return false;
        }

        // 🚀 FIX: Double Tap to Exit App Logic
        final now = DateTime.now();
        if (_lastPressedAt == null ||
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Press back again to exit"),
              duration: Duration(seconds: 2),
            ),
          );
          return false; // Don't exit yet
        }
        return true; // Exit app
      },
      child: Scaffold(
        backgroundColor: _scaffoldBg,
        body: pages[_selectedIndex],
        bottomNavigationBar: _buildBottomNav(cart),
      ),
    );
  }

  // ─── BOTTOM NAV ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav(CartService cart) {
    return Container(
      decoration: const BoxDecoration(
        color: _cardBg,
        border: Border(top: BorderSide(color: _divider, width: 1)),
      ),
      child: SafeArea(
        bottom: true,
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: _brandRed,
          unselectedItemColor: _textMuted,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle:
              GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 10),
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 24),
              activeIcon: Icon(Icons.home_rounded, size: 24),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 24),
                  if (cart.totalItems > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: _brandRed, shape: BoxShape.circle),
                        child: Text('${cart.totalItems}',
                            style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              activeIcon: const Icon(Icons.shopping_bag_rounded, size: 24),
              label: 'Cart',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded, size: 24),
              activeIcon: Icon(Icons.person_rounded, size: 24),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // ─── MAIN DASHBOARD ─────────────────────────────────────────────────────────
  Widget _buildDashboard() {
    final session = context.watch<SessionService>();
    final isInsideStore = session.isInsideStore;

    return Column(
      children: [
        _buildHeader(isInsideStore),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight - 44),
                  child: IntrinsicHeight(
                    child: Column(children: [
                      // ── State A: Web, not in store ────────────────────────────
                      if (kIsWeb && !isInsideStore) ...[
                        _buildOffersCarousel(),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 10, child: _buildInstallAppTile()),
                            const SizedBox(width: 14),
                            Expanded(
                              flex: 9,
                              child: Column(
                                children: [
                                  _buildEnterStoreTile(),
                                  const SizedBox(height: 10),
                                  _buildHowItWorksTile(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const SizedBox(height: 20),
                        const GatePassTile(),
                      ],

                      // ── State B: Web, inside store ────────────────────────────
                      if (kIsWeb && isInsideStore) ...[
                        _buildInStoreOffersTile(),
                        const Spacer(),
                        _buildHeroScanButton(isInsideStore),
                        const Spacer(),
                        const GatePassTile(),
                      ],

                      // ── State C: Native, not in store ─────────────────────────
                      if (!kIsWeb && !isInsideStore) ...[
                        _buildOffersCarousel(),
                        const SizedBox(height: 20),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  flex: 10,
                                  child: _buildDynamicEngagementTile()),
                              const SizedBox(width: 14),
                              Expanded(
                                flex: 9,
                                child: Column(
                                  children: [
                                    Expanded(child: _buildEnterStoreTile()),
                                    const SizedBox(height: 12),
                                    _buildHowItWorksTile(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const GatePassTile(),
                      ],

                      // ── State D: Native, inside store ─────────────────────────
                      if (!kIsWeb && isInsideStore) ...[
                        _buildInStoreOffersTile(),
                        const Spacer(),
                        _buildHeroScanButton(isInsideStore),
                        const Spacer(),
                        const GatePassTile(),
                      ],
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── HEADER ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isInsideStore) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (isInsideStore)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                            color: _activeGreen, shape: BoxShape.circle),
                      )
                    else
                      const Icon(Icons.location_on_rounded,
                          color: _brandRed, size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        isInsideStore
                            ? "Inside ${UserSession.branchCode}"
                            : "Navi Mumbai, Maharashtra",
                        style: GoogleFonts.dmSans(
                          color: isInsideStore ? _activeGreen : _textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isInsideStore) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _confirmExitStore,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _brandRed,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.logout_rounded,
                                  color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text("Exit",
                                  style: GoogleFonts.dmSans(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => showSearch(
                    context: context, delegate: ProductSearchDelegate()),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: _divider),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.search_rounded,
                      color: _textSecondary, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "Hi, $_firstName 👋",
            style: GoogleFonts.syne(
                color: _textPrimary, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            isInsideStore
                ? "You're inside the store — happy scanning!"
                : "Ready to shop smarter?",
            style: GoogleFonts.dmSans(color: _textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── OFFERS CAROUSEL (States A & C) ─────────────────────────────────────────
  Widget _buildOffersCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 116,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentCarouselIndex = idx),
            itemCount: _fomoOffers.length,
            itemBuilder: (ctx, i) {
              final offer = _fomoOffers[i];
              final List<Color> colors = offer['colors'] as List<Color>;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              offer['badge'] as String,
                              style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            offer['title'] as String,
                            style: GoogleFonts.syne(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white),
                          ),
                          Text(
                            offer['subtitle'] as String,
                            style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.85)),
                          ),
                        ],
                      ),
                    ),
                    Icon(offer['icon'] as IconData,
                        color: Colors.white.withOpacity(0.9), size: 44),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_fomoOffers.length, (i) {
            final bool active = i == _currentCarouselIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active ? _brandRed : _textMuted,
                borderRadius: BorderRadius.circular(100),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildInStoreOffersTile() {
    return const DynamicLiveOffersBanner();
  }

  Widget _buildHeroScanButton(bool isInsideStore) {
    bool scanPressed = false;

    return StatefulBuilder(builder: (context, setState) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 320,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Transform.scale(
                      scale: 1.0 + (0.4 * _pulseController.value),
                      child: Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _brandRed.withOpacity(
                                      0.15 * (1 - _pulseController.value)),
                                  width: 3))),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _pulse2Controller,
                    builder: (_, __) => Transform.scale(
                      scale: 1.0 + (0.25 * _pulse2Controller.value),
                      child: Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _brandRed.withOpacity(
                                      0.2 * (1 - _pulse2Controller.value)),
                                  width: 2.5))),
                    ),
                  ),
                  Container(
                      width: 210,
                      height: 210,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _brandRedLight)),
                  GestureDetector(
                    onTapDown: (_) => setState(() => scanPressed = true),
                    onTapUp: (_) {
                      setState(() => scanPressed = false);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ScanProductScreen(
                                  isEntryMode: !isInsideStore)));
                    },
                    onTapCancel: () => setState(() => scanPressed = false),
                    child: AnimatedScale(
                      scale: scanPressed ? 0.94 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      child: Container(
                        width: 175,
                        height: 175,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                              colors: [_brandRed, _brandRedDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight),
                          boxShadow: [
                            BoxShadow(
                                color: _brandRed.withOpacity(0.4),
                                blurRadius: 40,
                                spreadRadius: 6,
                                offset: const Offset(0, 12))
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_scanner_rounded,
                                color: Colors.white, size: 64),
                            const SizedBox(height: 10),
                            Text(isInsideStore ? "SCAN" : "ENTER",
                                style: GoogleFonts.syne(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 4.0)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
              isInsideStore
                  ? "Scan a Product BARCODE to add to cart"
                  : "Scan store QR to enter",
              style: GoogleFonts.dmSans(color: _textMuted, fontSize: 14),
              textAlign: TextAlign.center),
        ],
      );
    });
  }

  Widget _buildInstallAppTile() {
    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _brandRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_iphone_rounded,
                color: _brandRed, size: 36),
          ),
          const SizedBox(height: 16),
          Text("Get the App /n",
              style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary)),
          const SizedBox(height: 8),
          Text("For the best in-store scanning and live offers.",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 12, color: _textSecondary)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _launchPlayStore,
                child: const Icon(Icons.android_rounded,
                    color: _activeGreen, size: 32),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _launchAppStore,
                child: const Icon(Icons.apple_rounded,
                    color: Colors.black87, size: 32),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildEnterStoreTile() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ScanProductScreen(isEntryMode: true),
        ),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardBg,
          border: Border.all(color: _divider),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _brandRed,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.qr_code_scanner_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 10),
            Text("Enter The Store",
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksTile() {
    return GestureDetector(
      onTap: _launchYouTube,
      child: Container(
        height: 85,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardBg,
          border: Border.all(color: _divider),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _brandRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: _brandRed, size: 28),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("How it works",
                    style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary)),
                const SizedBox(height: 2),
                Text("Watch 60 sec video",
                    style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: _textMuted,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicEngagementTile() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('engagement_campaigns')
          .where('isActive', isEqualTo: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildDefaultTaskTile();
        }

        final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final type = data['type']?.toString() ?? 'DATA_COLLECTION';
        final reward = data['rewardValue']?.toString() ?? 'Reward';
        final sponsor = data['sponsorTenantId']?.toString() ?? 'Partner';

        String title = "Exclusive Offer";
        String sub = "Complete task to unlock";
        IconData icon = Icons.star_rounded;
        Color color = _amber;

        if (type == 'DATA_COLLECTION') {
          title = "Complete Profile";
          sub = "Get $reward from $sponsor";
          icon = Icons.card_giftcard_rounded;
          color = _brandRed;
        } else if (type == 'CROSS_SELL') {
          title = "Hot Nearby!";
          sub = "Claim $reward at $sponsor";
          icon = Icons.local_fire_department_rounded;
          color = _amber;
        } else if (type == 'SENSOR_GAME') {
          title = "Walk & Win";
          sub = "Unlock $reward today!";
          icon = Icons.directions_walk_rounded;
          color = _activeGreen;
        }

        return GestureDetector(
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border.all(color: _divider),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 30),
                ),
                const SizedBox(height: 12),
                Text(title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary)),
                const SizedBox(height: 4),
                Text(sub,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: _textSecondary)),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text("Unlock Now",
                      style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultTaskTile() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _divider),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: _brandRedLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.star_rounded, color: _brandRed, size: 28),
          ),
          const SizedBox(height: 12),
          Text("Daily",
              style: GoogleFonts.dmSans(fontSize: 12, color: _textMuted)),
          Text("Rewards &",
              style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary)),
          Text("Offers",
              style: GoogleFonts.syne(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _brandRed)),
          const SizedBox(height: 12),
          Text("Complete tasks to win!",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 11, color: _textSecondary)),
        ],
      ),
    );
  }
} // 🚀 THE FIX: Ye bracket _HomeScreenState class ko close karega!

class DynamicLiveOffersBanner extends StatefulWidget {
  const DynamicLiveOffersBanner({super.key});

  @override
  State<DynamicLiveOffersBanner> createState() =>
      _DynamicLiveOffersBannerState();
}

class _DynamicLiveOffersBannerState extends State<DynamicLiveOffersBanner> {
  int _currentIndex = 0;
  bool _isPressed = false;
  late PageController _pageController;
  Timer? _timer;
  int _currentOfferCount = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _timer = Timer.periodic(const Duration(milliseconds: 3500), (timer) {
      if (_pageController.hasClients && _currentOfferCount > 1) {
        int nextIndex = (_currentIndex + 1) % _currentOfferCount;
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // 🎨 SMART UI MAPPER
  Map<String, dynamic> _getThemeForOffer(
      String type, double price, double dPrice, int bq, int fq) {
    if (type == 'BOGO') {
      return {
        'tag': 'BOGO',
        'title': 'Buy 1 Get 1 Free 🔥',
        'icon': Icons.card_giftcard_rounded,
        'colors': [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)]
      };
    } else if (type == 'BUY_X_GET_Y' || type == 'COMBO') {
      return {
        'tag': 'BUY $bq GET $fq',
        'title': 'Store Combos 🎁',
        'icon': Icons.layers_rounded,
        'colors': [const Color(0xFFE65100), const Color(0xFFFF7043)]
      };
    } else if (type == 'FLASH') {
      return {
        'tag': 'FLASH SALE',
        'title': 'Limited Time ⚡',
        'icon': Icons.flash_on_rounded,
        'colors': [const Color(0xFFC62828), const Color(0xFFEF5350)]
      };
    } else if (type == 'CROSS') {
      return {
        'tag': 'CROSS OFFER',
        'title': 'Buy & Unlock 🚀',
        'icon': Icons.shuffle_rounded,
        'colors': [const Color(0xFF0277BD), const Color(0xFF29B6F6)]
      };
    }
    int off = price > 0 ? ((price - dPrice) / price * 100).toInt() : 0;
    return {
      'tag': '${off > 0 ? '$off% OFF' : 'SALE'}',
      'title': 'Special Discount 💥',
      'icon': Icons.local_offer_rounded,
      'colors': [const Color(0xFF00695C), const Color(0xFF26A69A)]
    };
  }

  // 🛡️ THE FALLBACK UI (Ab banner kabhi gayab nahi hoga!)
  Widget _buildFallbackBanner(
      {String tag = "OFFERS",
      String title = "Stay Tuned!",
      String sub = "Keep scanning for surprises",
      IconData icon = Icons.local_offer_rounded}) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF2B32B2), Color(0xFF1488CC)]),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(tag,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
                Text(title,
                    maxLines: 1,
                    style: GoogleFonts.syne(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(sub,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Icon(icon, color: Colors.white, size: 36),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // 🚀 100% LIVE DATA FROM FIREBASE (Corrected Query)
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('tenantId', isEqualTo: UserSession.tenantId)
          .where('clearanceActive', isEqualTo: true) // 👈 Sahi Field!
          .snapshots(),
      builder: (context, snapshot) {
        bool hasOffers = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

        if (hasOffers) {
          _currentOfferCount = snapshot.data!.docs.length;
        } else {
          _currentOfferCount = 0;
        }

        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const StoreOffersSheet(),
            );
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: Container(
              width: double.infinity,
              height:
                  MediaQuery.of(context).size.width * 0.35, // 🔒 HEIGHT LOCKED
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 6)),
                ],
              ),
              child: Stack(
                children: [
                  // 🚀 SHOW FALLBACK IF EMPTY, ELSE SHOW CAROUSEL
                  if (!hasOffers)
                    _buildFallbackBanner()
                  else
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _currentOfferCount,
                      onPageChanged: (index) =>
                          setState(() => _currentIndex = index),
                      itemBuilder: (context, index) {
                        final data = snapshot.data!.docs[index].data()
                            as Map<String, dynamic>;
                        final String name = data['name'] ?? 'Offer Item';
                        final double price =
                            double.tryParse(data['price']?.toString() ?? '0') ??
                                0.0;
                        final double dPrice = double.tryParse(
                                data['discountPrice']?.toString() ??
                                    price.toString()) ??
                            price;
                        final String type = data['clearanceType'] ?? 'DISCOUNT';
                        final int buyQty = data['buyQty'] ?? 1;
                        final int freeQty = data['freeQty'] ?? 1;

                        final theme = _getThemeForOffer(
                            type, price, dPrice, buyQty, freeQty);

                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: theme['colors'],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Text(theme['tag'],
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1)),
                                    ),
                                    Text(theme['title'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.syne(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                    const SizedBox(height: 2),
                                    Text(name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(theme['icon'],
                                  color: Colors.white, size: 36),
                            ],
                          ),
                        );
                      },
                    ),

                  // 🟡 DOT INDICATOR
                  if (hasOffers && _currentOfferCount > 1)
                    Positioned(
                      bottom: 8,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_currentOfferCount, (index) {
                          bool isActive = _currentIndex == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 4,
                            width: isActive ? 16 : 4,
                            decoration: BoxDecoration(
                                color: isActive
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(10)),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
