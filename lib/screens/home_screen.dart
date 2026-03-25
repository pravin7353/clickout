import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../services/cart/cart_service.dart';
import '../widgets/product_search_delegate.dart';
import 'scan_product_screen.dart';
import 'profile_screen.dart';
import 'cart_screen.dart';
import 'order_history_screen.dart';
import '/utils/user_session.dart';

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

  int _currentSlideIndex = 0;
  Timer? _slideTimer;
  StreamSubscription<QuerySnapshot>? _offerSubscription;

  final List<Map<String, dynamic>> _staticSlides = [
    {
      "title": "Start Shopping",
      "subtitle": "Scan items to add to cart.",
      "icon": Icons.qr_code_scanner,
      "isOffer": false,
    },
    {
      "title": "Skip the Queue",
      "subtitle": "Pay online & generate Gate Pass.",
      "icon": Icons.run_circle_outlined,
      "isOffer": false,
    },
    {
      "title": "Easy Payment",
      "subtitle": "UPI, Cards & Net Banking supported.",
      "icon": Icons.payment,
      "isOffer": false,
    },
    {
      "title": "Family Mode",
      "subtitle": "Best offers applied automatically.",
      "icon": Icons.family_restroom,
      "isOffer": false,
    },
  ];

  List<Map<String, dynamic>> _activeSlides = [];

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

    _activeSlides = List.from(_staticSlides);
    _setupOfferStream();

    _slideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        if (_activeSlides.isNotEmpty) {
          _currentSlideIndex = (_currentSlideIndex + 1) % _activeSlides.length;
        }
      });
    });

    _checkLocationPermission();
  }

  void _setupOfferStream() {
    _offerSubscription = FirebaseFirestore.instance
        .collection('products')
        .where('tenantId', isEqualTo: UserSession.tenantId) // 🚀 SAAS INJECTION
        .where('storeId', isEqualTo: UserSession.storeId) // 🚀 SAAS INJECTION
        .where('clearanceActive', isEqualTo: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      List<Map<String, dynamic>> offerSlides = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        offerSlides.add({
          "title": data['name'] ?? "Special Offer",
          "subtitle": data['clearanceTag'] ?? "Great discount inside!",
          "icon": Icons.local_fire_department,
          "isOffer": true,
        });
      }

      List<Map<String, dynamic>> mergedSlides = [];
      int offerIndex = 0;
      for (int i = 0; i < _staticSlides.length; i++) {
        mergedSlides.add(_staticSlides[i]);
        if (offerIndex < offerSlides.length) {
          mergedSlides.add(offerSlides[offerIndex]);
          offerIndex++;
        }
      }
      while (offerIndex < offerSlides.length) {
        mergedSlides.add(offerSlides[offerIndex]);
        offerIndex++;
      }

      setState(() {
        _activeSlides = mergedSlides;
        _currentSlideIndex = 0;
      });
    });
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
    _offerSubscription?.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool?> _showExitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: cherryRedDark),
            const SizedBox(width: 10),
            const Text("Leaving so soon?",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
            "Are you sure you want to exit the ClickOut app? Tremendous deals are waiting!"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("STAY",
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: cherryRedDark,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("EXIT",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showSmartStoreExitDialog(int cartItemsCount) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            const Text("Exit Store?",
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cartItemsCount > 0) ...[
              const Text("ARE YOU SURE YOU WANT TO EXIT?",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200)),
                child: Text(
                    "If you exit now, all $cartItemsCount items in your cart WILL BE WIPED OUT.",
                    style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              const Text("Are you sure you want to exit this store session?",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200)),
                child: const Text(
                    "Note: Your paid Gate Passes are safe and can be accessed from the History section.",
                    style: TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("CANCEL",
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("YES, EXIT",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildCherryHomeBody(),
      const CartScreen(),
      const ProfileScreen()
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;

        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0;
          });
          return;
        }

        final bool shouldPop = await _showExitDialog() ?? false;
        if (shouldPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        body: pages[_selectedIndex],
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
      ),
    );
  }

  Widget _buildCherryHomeBody() {
    Map<String, dynamic> currentSlideData = _activeSlides.isNotEmpty
        ? _activeSlides[_currentSlideIndex]
        : _staticSlides[0];

    bool isOffer = currentSlideData['isOffer'] == true;

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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _glassButton(Icons.search, () {
                          showSearch(
                              context: context,
                              delegate: ProductSearchDelegate());
                        }),
                        const SizedBox(height: 5),
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
              Container(
                height: 90,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  gradient: isOffer
                      ? LinearGradient(colors: [
                          Colors.orange.shade100,
                          Colors.amber.shade50
                        ], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : const LinearGradient(
                          colors: [Colors.white, Colors.white]),
                  borderRadius: BorderRadius.circular(25),
                  border: isOffer
                      ? Border.all(color: Colors.orange.shade400, width: 2)
                      : Border.all(color: Colors.white, width: 0),
                  boxShadow: [
                    BoxShadow(
                        color: isOffer
                            ? Colors.orange.withOpacity(0.4)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: isOffer ? 25 : 15,
                        spreadRadius: isOffer ? 2 : 0,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return ScaleTransition(
                        scale: animation,
                        child:
                            FadeTransition(opacity: animation, child: child));
                  },
                  child: Row(
                    key: ValueKey<int>(_currentSlideIndex),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: isOffer
                                ? Colors.white
                                : cherryRedLight.withOpacity(0.1),
                            shape: BoxShape.circle,
                            boxShadow: isOffer
                                ? [
                                    BoxShadow(
                                        color: Colors.orange.withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4))
                                  ]
                                : null),
                        child: Icon(currentSlideData['icon'],
                            color: isOffer
                                ? Colors.orange.shade800
                                : cherryRedDark,
                            size: 28),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(currentSlideData['title'],
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: isOffer
                                        ? Colors.brown.shade800
                                        : Colors.black87,
                                    letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(currentSlideData['subtitle'],
                                style: TextStyle(
                                    color: isOffer
                                        ? Colors.brown.shade600
                                        : Colors.grey[600],
                                    fontWeight: isOffer
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    fontSize: 13),
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
              Column(
                children: [
                  if (UserSession.storeId.isEmpty)
                    const Text("Welcome!",
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87))
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront,
                              color: cherryRedDark, size: 22),
                          const SizedBox(width: 8),
                          Text(UserSession.branchCode,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () async {
                              int currentCartItems =
                                  context.read<CartService>().totalItems;

                              bool? confirmExit =
                                  await _showSmartStoreExitDialog(
                                      currentCartItems);

                              if (confirmExit == true) {
                                await UserSession.clearSession();
                                if (context.mounted) {
                                  context.read<CartService>().clearCart();
                                }
                                setState(() {});
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.red.shade200)),
                              child: const Icon(Icons.logout_rounded,
                                  color: Colors.red, size: 18),
                            ),
                          )
                        ],
                      ),
                    ),
                  const SizedBox(height: 30),
                  GestureDetector(
                    onTap: () {
                      if (UserSession.storeId.isEmpty) {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ScanProductScreen(
                                    isEntryMode: true)));
                      } else {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ScanProductScreen(
                                    isEntryMode: false)));
                      }
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
                                color: UserSession.storeId.isEmpty
                                    ? Colors.orange.withOpacity(0.25)
                                    : cherryRedDark.withOpacity(0.25),
                                blurRadius: 30,
                                spreadRadius: 10,
                                offset: const Offset(0, 10))
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: UserSession.storeId.isEmpty
                                ? LinearGradient(colors: [
                                    Colors.orange.shade400,
                                    Colors.deepOrange
                                  ])
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [cherryRedLight, cherryRedDark]),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  UserSession.storeId.isEmpty
                                      ? Icons.storefront
                                      : Icons.qr_code_scanner_rounded,
                                  size: 60,
                                  color: Colors.white),
                              const SizedBox(height: 8),
                              Text(
                                  UserSession.storeId.isEmpty
                                      ? 'CHECK-IN'
                                      : 'SCAN',
                                  style: const TextStyle(
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
