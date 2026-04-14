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
import '/utils/user_session.dart';
// import '../widgets/store_offers_sheet.dart'; // 🚀 TEMPORARY DISABLED

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

  // Pulse animation for SCAN button
  late AnimationController _pulseController;
  late AnimationController _pulse2Controller;

  // 🚀 FIX: Removed unused _scanPressed variable to clear yellow warning

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _pulse2Controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    // Offset second pulse
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
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _launchAppStore() async {
    final Uri url = Uri.parse('https://apps.apple.com/in/app/your-app-id');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _launchPlayStore() async {
    final Uri url = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.your.package');
    if (await canLaunchUrl(url)) await launchUrl(url);
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
    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(cart),
    );
  }

  // ─── BOTTOM NAV ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav(CartService cart) {
    return Container(
      decoration: const BoxDecoration(
        color: _cardBg,
        border: Border(top: BorderSide(color: _divider, width: 1)),
      ),
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              children: [
                // ── State A: Web, not in store ────────────────────────────
                if (kIsWeb && !isInsideStore) ...[
                  _buildOffersCarousel(),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 10, child: _buildDynamicEngagementTile()),
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
                  const SizedBox(height: 20),
                  _buildGatePassTile(),
                ],

                // ── State B: Web, inside store ────────────────────────────
                if (kIsWeb && isInsideStore) ...[
                  _buildInStoreOffersTile(),
                  const SizedBox(height: 24),
                  _buildHeroScanButton(isInsideStore),
                  const SizedBox(height: 20),
                  _buildGatePassTile(),
                ],

                // ── State C: Native, not in store ─────────────────────────
                if (!kIsWeb && !isInsideStore) ...[
                  _buildOffersCarousel(),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 10, child: _buildTasksTile()),
                      const SizedBox(width: 14),
                      Expanded(flex: 9, child: _buildEnterStoreTile()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildGatePassTile(),
                ],

                // ── State D: Native, inside store ─────────────────────────
                if (!kIsWeb && isInsideStore) ...[
                  _buildInStoreOffersTile(),
                  const SizedBox(height: 24),
                  _buildHeroScanButton(isInsideStore),
                  const SizedBox(height: 20),
                  _buildGatePassTile(),
                ],
              ],
            ),
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
              // Location / Store row
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
              // Search button
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
            "Hi, there 👋",
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
        // Dot indicators
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

// 🚀 Backend Mapper: Firestore data -> UI Label
  String? _mapOfferLabel(Map<String, dynamic> data) {
    final type = data['clearanceType']?.toString().toUpperCase();
    final discount = data['discount'];

    if (type == 'BOGO') return "Buy 1 Get 1";
    if (type == 'FLAT_PERCENT') return "${discount ?? 0}% OFF";
    if (type == 'FLAT_AMOUNT') return "₹${discount ?? 0} OFF";
    if (type == 'FLASH') return "Flash Sale";
    return null;
  }

  // ─── LIVE DYNAMIC OFFERS CAROUSEL (States B & D) ────────────────────────────
  Widget _buildInStoreOffersTile() {
    return const DynamicLiveOffersBanner();
  }

  // ─── HERO SCAN BUTTON (States B & D) ────────────────────────────────────────
  Widget _buildHeroScanButton(bool isInsideStore) {
    bool scanPressed = false;

    return StatefulBuilder(builder: (context, setState) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 320, // 🚀 HUGE Container to push bottom items down
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse 1
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, __) => Transform.scale(
                      scale:
                          1.0 + (0.4 * _pulseController.value), // Bigger pulse
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
                  // Pulse 2
                  AnimatedBuilder(
                    animation: _pulse2Controller,
                    builder: (_, __) => Transform.scale(
                      scale: 1.0 +
                          (0.25 * _pulse2Controller.value), // Bigger pulse
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
                  // Static Ring
                  Container(
                      width: 210,
                      height: 210,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _brandRedLight)),
                  // 🚀 GIANT MAIN BUTTON
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
                        width: 175, // 🚀 Monster Size (150 -> 175)
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
                                color: Colors.white, size: 64), // Huge Icon
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

  // ─── ENTER STORE TILE (States A & C — right column top) ─────────────────────
  Widget _buildEnterStoreTile() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ScanProductScreen(isEntryMode: true),
        ),
      ),
      child: Container(
        height: 150,
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

  // ─── HOW IT WORKS TILE (State A — web, right column bottom) ─────────────────
  Widget _buildHowItWorksTile() {
    return GestureDetector(
      onTap: _launchYouTube,
      child: Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardBg,
          border: Border.all(color: _divider),
          borderRadius: BorderRadius.circular(14),
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
            const Icon(Icons.play_circle_fill_rounded,
                color: _brandRed, size: 28),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("How it works",
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary)),
                Text("Watch 60 sec video",
                    style: GoogleFonts.dmSans(fontSize: 10, color: _textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── DYNAMIC ENGAGEMENT TILE (Replaces Install App) ─────────────────────────
  Widget _buildDynamicEngagementTile() {
    return StreamBuilder<QuerySnapshot>(
      // 🚀 OPTIMIZATION: limit(1) avoids full collection scan. Index on isActive required.
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
        // 🚀 FIX: Access specific keys from the map, no null-aware operator on 'data' itself
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
          onTap: () {
            // Future implementation: Open Campaign BottomSheet
          },
          child: Container(
            height: 344,
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 36),
                ),
                const SizedBox(height: 20),
                Text(title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.syne(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary)),
                const SizedBox(height: 8),
                Text(sub,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(
                        fontSize: 12, color: _textSecondary)),
                const SizedBox(height: 24),
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
      height: 344,
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
            child: const Icon(Icons.star_rounded, color: _brandRed, size: 32),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          Text("Complete tasks to win!",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(fontSize: 11, color: _textSecondary)),
        ],
      ),
    );
  }

  // ─── TASKS TILE (State C — native, not in store, left column) ───────────────
  Widget _buildTasksTile() {
    return Container(
      height: 244,
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
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Your Tasks",
              style: GoogleFonts.syne(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 12),
          _buildTaskRow("Daily Check-in", Icons.check_circle_outline_rounded,
              _activeGreen),
          _buildTaskRow("Scratch & Win", Icons.card_giftcard_rounded, _amber),
          _buildTaskRow("Spin Wheel", Icons.rotate_right_rounded, _brandRed),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _brandRedLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text("Stay tuned for more!",
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: _brandRed,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 40,
      decoration: BoxDecoration(
        color: _cardSubtle,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: GoogleFonts.dmSans(fontSize: 12, color: _textSecondary)),
        ],
      ),
    );
  }

  // ─── GATE PASS TILE (all states) ─────────────────────────────────────────────
  Widget _buildGatePassTile() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
      child: Container(
        height: 72,
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
          children: [
            const SizedBox(width: 16),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: _amber, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Gate Pass & History",
                      style: GoogleFonts.syne(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textPrimary)),
                  Text("View all your orders",
                      style:
                          GoogleFonts.dmSans(fontSize: 11, color: _textMuted)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: _textMuted, size: 14),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

// ─── ZEPTO-LEVEL LIVE OFFERS AUTO-SLIDER ──────────────────────────────────────
class DynamicLiveOffersBanner extends StatefulWidget {
  const DynamicLiveOffersBanner({super.key});

  @override
  State<DynamicLiveOffersBanner> createState() =>
      _DynamicLiveOffersBannerState();
}

class _DynamicLiveOffersBannerState extends State<DynamicLiveOffersBanner> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _itemCount = 0;
  int _currentIndex = 0;
  bool _isPressed = false;

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _updateTimer(int count) {
    if (_itemCount == count) return;
    _itemCount = count;
    _timer?.cancel();

    if (count > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (_pageController.hasClients) {
          int next = (_pageController.page?.round() ?? 0) + 1;
          if (next >= count) {
            _pageController.jumpToPage(0);
          } else {
            _pageController.animateToPage(next,
                duration: const Duration(milliseconds: 800),
                curve: Curves.fastOutSlowIn);
          }
        }
      });
    }
  }

  // 🚀 MAPPING FUNCTION (Type -> UI Text)
  Map<String, dynamic> _mapProductToUI(Map<String, dynamic> data) {
    final type = data['clearanceType']?.toString().toUpperCase() ?? '';
    final val = data['clearanceValue']?.toString() ??
        data['discount']?.toString() ??
        '';
    final name = data['name']?.toString() ?? 'Selected Item';

    String title = "Special Deal";
    IconData icon = Icons.local_offer_rounded;

    if (type == 'BOGO') {
      title = "Buy 1 Get 1 Free";
      icon = Icons.card_giftcard_rounded;
    } else if (type == 'PERCENT' || type == 'FLAT_PERCENT') {
      title = "$val% OFF";
      icon = Icons.discount_rounded;
    } else if (type == 'FLAT' || type == 'FLAT_AMOUNT') {
      title = "₹$val OFF";
      icon = Icons.savings_rounded;
    } else if (type == 'COMBO') {
      title = "Combo Deal";
      icon = Icons.fastfood_rounded;
    } else if (type == 'BUY_X_GET_Y') {
      title = "Buy X Get Y";
      icon = Icons.shopping_bag_rounded;
    } else if (type == 'FLASH') {
      title = "Flash Sale";
      icon = Icons.flash_on_rounded;
    }

    return {"title": title, "sub": "on $name", "icon": icon};
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('clearanceActive', isEqualTo: true)
          .where('tenantId', isEqualTo: UserSession.tenantId)
          .limit(7) // Top 7 live products
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox(); // No clutter if empty
        }

        final docs = snapshot.data!.docs;
        _updateTimer(docs.length);

        return GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapCancel: () => setState(() => _isPressed = false),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            // 🚀 TEMPORARY DISABLED (File deleted by AI)
            /*
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => StoreOffersSheet(),
            );
            */
          },
          child: AnimatedScale(
            scale: _isPressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: Container(
              width: double.infinity,
              height: 125, // Premium Height
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFD32F2F),
                    Color(0xFFB71C1C)
                  ], // Zepto-like Deep Red
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD32F2F).withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // 🚀 AUTO-SLIDER PAGE VIEW
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: docs.length,
                      onPageChanged: (index) =>
                          setState(() => _currentIndex = index),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final uiData = _mapProductToUI(data);

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20.0, vertical: 24.0),
                          child: Row(
                            children: [
                              Icon(uiData['icon'],
                                  color: Colors.white, size: 40),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(uiData['title'],
                                        style: GoogleFonts.syne(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white)),
                                    const SizedBox(height: 4),
                                    Text(uiData['sub'],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.dmSans(
                                            fontSize: 13,
                                            color:
                                                Colors.white.withOpacity(0.9))),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white, size: 28),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // 🚀 DOT INDICATORS
                  if (docs.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(docs.length, (index) {
                          bool isActive = _currentIndex == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            height: 5,
                            width: isActive ? 16 : 5,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
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
