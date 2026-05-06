import '../widgets/shared_cart_item_card.dart';
import 'dart:convert'; // 🚀 CRITICAL FOR BASE64 DECODING
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
//import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firestore/firestore_service.dart';
import '../services/cart/cart_service.dart';
import '../services/session_service.dart'; // 🚀 SAAS SESSION ENGINE
import 'dart:ui'; // 🚀 Added for ImageFilter.blur
import 'cart_screen.dart'; // 🚀 NAYA: Cart Screen par bhejne ke liye
//import '../services/system/store_entry_service.dart';
import '../models/cart_item.dart';

class ScanProductScreen extends StatefulWidget {
  final bool isEntryMode; // 🚀 NAYA VARIABLE
  // Default false (Product Scan)
  const ScanProductScreen({super.key, this.isEntryMode = false});

  @override
  State<ScanProductScreen> createState() => _ScanProductScreenState();
}

enum ScanStatus { idle, success, error, blocked }

class _ScanProductScreenState extends State<ScanProductScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
    torchEnabled: false,
  );

  final FirestoreService _firestoreService = FirestoreService();
  final AudioPlayer _player = AudioPlayer();
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  bool _isFlashOn = false;
  ScanStatus _scanStatus = ScanStatus.idle;
  DateTime? _lastScanTime;

  bool _isBlocked = false;
  final List<DateTime> _scanAttempts = [];

  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);

  // 🚀 Added Animation Controller for Brackets
  late AnimationController _bracketController;

  @override
  void initState() {
    super.initState();
    // Brackets ki dhadkan (pulse) ke liye
    _bracketController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bracketController.dispose();
    scannerController.dispose();
    _player.dispose();
    super.dispose();
  }

  void _toggleFlash() {
    setState(() => _isFlashOn = !_isFlashOn);
    scannerController.toggleTorch();
  }

  // 🛡️ ULTRA-SMART NUMBER EXTRACTOR (Works for GST%, Weights like 200g, Prices like ₹50)
  double _safeDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();

    // Remove everything except numbers and decimals (Automatically handles "12% GST" -> 12.0)
    String cleanString = value.toString().replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleanString) ?? 0.0;
  }

  int _safeInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? 0;
  }

  void _triggerSpamBlock() async {
    if (_isBlocked) return;

    setState(() {
      _isBlocked = true;
      _scanStatus = ScanStatus.blocked;
      _isProcessing = false;
    });

    // 🚀 FIX: Puraane saare SnackBars turant clear karega taaki messages overlap na hon
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }

    await HapticFeedback.heavyImpact();
    await HapticFeedback.heavyImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              // 🚀 EXACT SINGLE MESSAGE
              Text("Scanning too fast! Blocked for 10s",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }

    // 🚀 EXACT 10 SECONDS PENALTY
    await Future.delayed(const Duration(seconds: 10));
    if (mounted) {
      setState(() {
        _isBlocked = false;
        _scanStatus = ScanStatus.idle;
        _scanAttempts.clear();
      });
    }
  }

  Future<void> _handleScan(String code, CartService cart) async {
    final now = DateTime.now();
    if (_isBlocked) return;

    // 🚀 FIX: Ignore extra frames immediately to prevent fake spam blocks
    if (_isProcessing ||
        (_lastScanTime != null &&
            now.difference(_lastScanTime!) < const Duration(seconds: 3))) {
      return;
    }

    _scanAttempts.add(now);
    _scanAttempts
        .removeWhere((t) => now.difference(t) > const Duration(seconds: 2));

    if (_scanAttempts.length >= 4) {
      _triggerSpamBlock();
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScanTime = now;
      _scanStatus = ScanStatus.success;
    });

    try {
      await HapticFeedback.mediumImpact();
      // await _player.play(AssetSource('sounds/beep.mp3'));
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 500));

// 🚀 THE NEW ENTRY MODE LOGIC (SMART ROUTER)
    if (widget.isEntryMode ||
        code.startsWith('clickout://store') ||
        code.startsWith('CLICKOUT::')) {
      try {
        String safePayload = code.trim();

        // 🛡️ BRIDGE LOGIC: Session Engine expects a URI.
        // We decode Base64 and feed it the exact format it wants!
        if (safePayload.startsWith('CLICKOUT::')) {
          String base64Data = safePayload.substring("CLICKOUT::".length).trim();

          // 🚀 Auto-Fix Padding if Scanner cuts it off
          while (base64Data.length % 4 != 0) {
            base64Data += '=';
          }

          String rawJson = utf8.decode(base64Decode(base64Data));
          Map<String, dynamic> data = jsonDecode(rawJson);

          String tId = data['tenantId'] ?? '';
          String bCode = data['branchCode'] ?? '';

          // 🤫 Secretly convert back to URI format to prevent SessionService Crash
          safePayload = 'clickout://store?t=$tId&s=$bCode&b=$bCode';
        }

        // Feed the SAFE URL to the Session Engine
        await context.read<SessionService>().checkInStore(safePayload);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("✅ Check-In Successful!"),
                backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Return to Home
        }
      } catch (e) {
        if (mounted) {
          // 🚀 FIX: Ab exact error dikhega agar decoding me issue aayi, "Invalid Store QR" hardcode nahi.
          _showErrorDialog("Entry Failed: $e");
        }
      }
      return; // Stop here, don't look for products
    }

    try {
      final productData = await _firestoreService.getProductByBarcode(code);

      if (!mounted) return;

      if (productData != null) {
        bool isUpdate = cart.items.containsKey(code);

        double price = _safeDouble(productData['price']);
        double gst = _safeDouble(productData['gst']);
        double weight = _safeDouble(productData['weight']);

        try {
          // 🚀 FIX IS HERE: ADDED 'await' SO ERRORS ARE CAUGHT PROPERLY
          await cart.add(
            barcode: code,
            name: productData['name'] ?? 'Unknown Item',
            price: price,
            gst: gst,
            weight: weight,
          );

          if (isUpdate) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Quantity updated +1"),
                duration: Duration(milliseconds: 800),
                backgroundColor: Colors.blue,
              ),
            );
            setState(() {
              _isProcessing = false;
              _scanStatus = ScanStatus.idle;
            });
          } else {
            _showProductFoundDialog(productData, price);
          }
        } catch (e) {
          // 🛑 THIS WILL NOW CATCH "DEAD STOCK" PROPERLY
          setState(() => _scanStatus = ScanStatus.error);
          await HapticFeedback.heavyImpact();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("⚠️ $e"), // Shows "DEAD STOCK" or "Out of Stock"
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }

          await Future.delayed(const Duration(seconds: 1));
          if (mounted && !_isBlocked) {
            setState(() {
              _isProcessing = false;
              _scanStatus = ScanStatus.idle;
            });
          }
        }
      } else {
        setState(() => _scanStatus = ScanStatus.error);
        await HapticFeedback.heavyImpact();
        _showErrorDialog(code);
      }
    } catch (e) {
      debugPrint("Scan Error: $e");
      if (mounted && !_isBlocked) {
        setState(() {
          _isProcessing = false;
          _scanStatus = ScanStatus.idle;
        });
      }
    }
  }

  Future<void> _pickFromGallery(CartService cart) async {
    if (kIsWeb) return;
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        await scannerController.analyzeImage(image.path);
      }
    } catch (e) {
      debugPrint("Gallery Scan Error: $e");
    }
  }

  Color _getBorderColor() {
    switch (_scanStatus) {
      case ScanStatus.success:
        return Colors.greenAccent;
      case ScanStatus.error:
        return Colors.redAccent;
      case ScanStatus.blocked:
        return Colors.red;
      case ScanStatus.idle:
        return cherryRedLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final topCameraHeight = MediaQuery.of(context).size.height * 0.40;

    // 🚀 1. Group items using Shared Widget Logic
    final List<CartGroup> groupedList = buildCartGroups(cart.items);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4), // Light grey background
      body: Stack(
        children: [
          // 🟩 LAYER 1: THE SMART LIST (Scrolls behind the camera)
          Column(
            children: [
              // This acts as a spacer so the list starts *below* the camera normally,
              // but can scroll *up* behind it.
              SizedBox(height: topCameraHeight),

              // Cart Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Scanned Items (${cart.totalItems})",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w900)),
                    Text("₹${cart.grandTotal.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFC53030))),
                  ],
                ),
              ),

              // The Actual List
              Expanded(
                child: groupedList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_scanner,
                                size: 50, color: Colors.grey.withOpacity(0.3)),
                            const SizedBox(height: 10),
                            const Text("Scan a product to start",
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                            16, 0, 16, 100), // Extra padding for bottom button
                        physics: const BouncingScrollPhysics(),
                        itemCount: groupedList.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: SharedCartItemCard(
                                group: groupedList[index], cart: cart),
                          );
                        },
                      ),
              ),
            ],
          ),

          // 🟩 LAYER 2: THE FLOATING CAMERA (Top 40%)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topCameraHeight,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(30)),
              child: Stack(
                children: [
                  MobileScanner(
                    controller: scannerController,
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      for (final barcode in barcodes) {
                        if (barcode.rawValue != null) {
                          _handleScan(barcode.rawValue!, cart);
                          break;
                        }
                      }
                    },
                  ),

                  // 🚀 CLEAN & MINIMAL SCANNER BOX (No annoying animations)
                  ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                        Colors.black54, BlendMode.srcOut),
                    child: Stack(
                      children: [
                        Container(
                            decoration: const BoxDecoration(
                                color: Colors.transparent,
                                backgroundBlendMode: BlendMode.dstOut)),
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            height: 200,
                            width: 260,
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Simple Static Border to highlight the cutout (Optional but looks clean)
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      height: 200,
                      width: 260,
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white.withOpacity(0.5), width: 2),
                          borderRadius: BorderRadius.circular(24)),
                    ),
                  ),

                  // Simple Static Indicators
                  if (_isProcessing ||
                      _scanStatus == ScanStatus.success ||
                      _isBlocked)
                    Center(
                      child: _isBlocked
                          ? const Icon(Icons.block, color: Colors.red, size: 80)
                          : _scanStatus == ScanStatus.success
                              ? const Icon(Icons.check_circle,
                                  color: Colors.greenAccent, size: 80)
                              : const CircularProgressIndicator(
                                  color: Colors.redAccent),
                    ),

                  // Top Action Buttons
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _glassButton(
                              icon: Icons.arrow_back_ios_new,
                              onTap: () => Navigator.pop(context)),
                          _glassButton(
                            icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                            color: _isFlashOn ? Colors.yellow : Colors.white,
                            onTap: _toggleFlash,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🟩 LAYER 3: FIXED BOTTOM BUTTON
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4))
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC53030), // Brand Red
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: cart.items.isEmpty
                      ? null
                      : () {
                          // 🚀 NAYA: Seedha Cart Screen par bhejo aur scanner ko hata do
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CartScreen()),
                          );
                        },
                  icon: const Icon(Icons.shopping_cart_checkout),
                  label: const Text("VIEW FULL CART",
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          letterSpacing: 1)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🚀 THE SMART GROUP CARD (Exact copy of cart_screen logic but compact)
  Widget _buildSmartGroupCard(CartGroup group, CartService cart) {
    final base = group.baseItem;
    final free = group.freeItem;
    final overflow = group.overflowItem;

    if (base == null && free == null && overflow == null)
      return const SizedBox.shrink();

    final display = base ?? overflow ?? free!;
    final int paidQty = (base?.quantity ?? 0) + (overflow?.quantity ?? 0);
    final int freeQty = free?.quantity ?? 0;
    final int totalQty = paidQty + freeQty;
    // 🚀 FIX: 0 ko 0.0 kiya taaki 'int is not a subtype of double' crash na ho
    final double paidTotal =
        (base?.totalPrice ?? 0.0) + (overflow?.totalPrice ?? 0.0);
    final double mrp = display.originalPrice;
    final bool hasOffer = (base?.clearanceActive ?? false) || freeQty > 0;
    final String offerType =
        base?.clearanceType ?? (freeQty > 0 ? 'FREE_ITEM' : '');

    // 🚀 THE MAGIC: SWIPE TO DELETE WRAPPER
    return Dismissible(
        key: ValueKey(group.baseKey),
        confirmDismiss: (direction) async {
          if (cart.isCorrectionMode) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Locked during correction"),
                backgroundColor: Colors.red));
            return false;
          }
          return true;
        },
        direction: cart.isCorrectionMode
            ? DismissDirection.none
            : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
              color: const Color(0xFFE53E3E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFE53E3E), size: 28),
        ),
        onDismissed: (direction) {
          final name = display.name;
          cart.deleteItem(group.baseKey);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("$name removed"),
            backgroundColor: const Color(0xFF111111),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.yellow,
              onPressed: () async {
                try {
                  await cart.add(
                      barcode: display.barcode,
                      name: display.name,
                      price: display.originalPrice,
                      gst: display.gst,
                      weight: display.weight);
                  for (int i = 1; i < totalQty; i++)
                    await cart.increment(display.barcode);
                } catch (_) {}
              },
            ),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: hasOffer
                ? Border.all(color: const Color(0xFF16A34A).withOpacity(0.25))
                : Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasOffer
                          ? const Color(0xFF16A34A).withOpacity(0.08)
                          : const Color(0xFFE53E3E).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.shopping_bag_outlined,
                        color: hasOffer
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFE53E3E),
                        size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(display.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF111111))),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (hasOffer &&
                                base != null &&
                                base.clearanceType != 'BOGO' &&
                                base.clearanceType != 'BUY_X_GET_Y' &&
                                base.clearanceType != 'FREE_ITEM')
                              Text("₹${mrp.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough)),
                            if (hasOffer &&
                                base != null &&
                                base.clearanceType != 'BOGO' &&
                                base.clearanceType != 'BUY_X_GET_Y' &&
                                base.clearanceType != 'FREE_ITEM')
                              const SizedBox(width: 4),
                            Text(
                              hasOffer &&
                                      base != null &&
                                      base.clearanceType != 'BOGO' &&
                                      base.clearanceType != 'BUY_X_GET_Y'
                                  ? "₹${base.finalUnitPrice.toStringAsFixed(0)}/item"
                                  : "₹${mrp.toStringAsFixed(0)}/item",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: hasOffer
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text("₹${paidTotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111))),
                ],
              ),

              // FREE ITEM / BOGO TAG
              if (freeQty > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF16A34A).withOpacity(0.2))),
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard_rounded,
                          color: Color(0xFF16A34A), size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(
                              _offerLabel(offerType, base?.buyQty ?? 1,
                                  base?.freeQty ?? freeQty),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w600))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(100)),
                        child: Text("+$freeQty FREE",
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      freeQty > 0
                          ? "$paidQty paid · $freeQty free"
                          : "$totalQty items",
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280))),
                  Row(
                    children: [
                      _miniStepBtn(Icons.remove, () {
                        if (cart.isCorrectionMode) return;
                        try {
                          cart.decrement(group.baseKey);
                        } catch (_) {}
                      }, enabled: !cart.isCorrectionMode && totalQty > 1),
                      SizedBox(
                          width: 32,
                          child: Text("$totalQty",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14))),
                      _miniStepBtn(Icons.add, () async {
                        if (cart.isCorrectionMode) return;
                        try {
                          await cart.increment(group.baseKey);
                        } catch (_) {}
                      }, enabled: !cart.isCorrectionMode, isAdd: true),
                    ],
                  )
                ],
              )
            ],
          ),
        ));
  }

  String _offerLabel(String type, int buyQty, int freeQty) {
    if (type == 'BOGO') return "Buy 1 Get 1 Free";
    if (type == 'BUY_X_GET_Y') return "Buy $buyQty Get $freeQty Free";
    if (type == 'BUY_X_GET_Y_CROSS') return "Cross-Product: $freeQty free";
    return "Free item applied";
  }

  // 🚀 HELPER WIDGETS
  Widget _miniStepBtn(IconData icon, VoidCallback onTap,
      {bool enabled = true, bool isAdd = false}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? (isAdd ? const Color(0xFFFFEBEB) : const Color(0xFFF6F6F4))
              : const Color(0xFFF6F6F4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: enabled
                  ? (isAdd
                      ? const Color(0xFFE53E3E).withOpacity(0.3)
                      : const Color(0xFFE5E7EB))
                  : const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon,
            size: 14,
            color: enabled
                ? (isAdd ? const Color(0xFFE53E3E) : const Color(0xFF111111))
                : const Color(0xFF9CA3AF)),
      ),
    );
  }

  Widget _glassButton(
      {required IconData icon,
      required VoidCallback onTap,
      Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24)),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // 🚀 HELPER FOR PREMIUM SCANNER CORNERS
  Widget _buildScannerCorner(
      {bool isTopLeft = false,
      bool isTopRight = false,
      bool isBottomLeft = false,
      bool isBottomRight = false}) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color:
                  (isTopLeft || isTopRight) ? Colors.white : Colors.transparent,
              width: 4),
          bottom: BorderSide(
              color: (isBottomLeft || isBottomRight)
                  ? Colors.white
                  : Colors.transparent,
              width: 4),
          left: BorderSide(
              color: (isTopLeft || isBottomLeft)
                  ? Colors.white
                  : Colors.transparent,
              width: 4),
          right: BorderSide(
              color: (isTopRight || isBottomRight)
                  ? Colors.white
                  : Colors.transparent,
              width: 4),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isTopLeft ? 24 : 0),
          topRight: Radius.circular(isTopRight ? 24 : 0),
          bottomLeft: Radius.circular(isBottomLeft ? 24 : 0),
          bottomRight: Radius.circular(isBottomRight ? 24 : 0),
        ),
      ),
    );
  }

  // 🚀 KEEP YOUR DIALOG FUNCTIONS UNTOUCHED
  void _showProductFoundDialog(Map<String, dynamic> data, double price) {
    // 🚀 ENGINE: EXTRACT DYNAMIC OFFERS DIRECTLY FROM RAW DB DATA
    bool hasOffer = data['clearanceActive'] == true;
    String offerType = (data['clearanceType'] ?? '').toString().toUpperCase();

    // 🚀 NEW: Use explicit keys from Admin!
    double discountPercent =
        double.tryParse(data['discountPercent']?.toString() ?? '0') ?? 0;
    double discountAmount =
        double.tryParse(data['discountAmount']?.toString() ?? '0') ?? 0;
    int bQty = int.tryParse(data['buyQty']?.toString() ?? '1') ?? 1;
    int fQty = int.tryParse(data['freeQty']?.toString() ?? '1') ?? 1;

    String offerText = '';
    Color offerColor = Colors.orange;

    if (hasOffer) {
      if (offerType == 'BOGO') {
        offerText = "🎁 Congratulations! Buy 1 Get 1 Free active!";
      } else if (offerType == 'BUY_X_GET_Y') {
        offerText = "🎁 Awesome! Buy $bQty Get $fQty Free applied!";
      } else if (offerType == 'PERCENTAGE' || offerType == 'TIERED_QTY') {
        offerText =
            "🔥 Congratulations! ${discountPercent.toInt()}% OFF Applicable!";
        offerColor = Colors.green;
      } else if (offerType == 'FLAT_AMOUNT') {
        offerText = "💸 You just saved ₹${discountAmount.toInt()} on this!";
        offerColor = Colors.green;
      } else if (offerType == 'COMBO') {
        offerText = "🍔 Combo Deal Applicable!";
        offerColor = Colors.blueAccent;
      } else if (offerType == 'CROSS_PRODUCT' ||
          offerType == 'BUY_X_GET_Y_CROSS') {
        offerText = "🔗 Special Cross-Product Offer unlocked!";
        offerColor = Colors.purpleAccent;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: hasOffer ? offerColor : cherryRedDark, width: 2.5)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 55)),
              const SizedBox(height: 15),
              const Text("Product Added!",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const SizedBox(height: 8),
              Text(data['name'] ?? 'Unknown',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'DejaVuSansMono',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 8),

              // 🚀 SMART PRICE STRIKETHROUGH
              if (hasOffer && offerType == 'FLAT_AMOUNT') ...[
                Text("Rs ${price.toStringAsFixed(0)}",
                    style: const TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                        fontSize: 16)),
                Text("Rs ${(price - discountAmount).toStringAsFixed(0)}",
                    style: TextStyle(
                        fontFamily: 'DejaVuSansMono',
                        color: offerColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w900)),
              ] else ...[
                Text("Rs ${price.toStringAsFixed(0)}",
                    style: TextStyle(
                        fontFamily: 'DejaVuSansMono',
                        color: cherryRedDark,
                        fontSize: 26,
                        fontWeight: FontWeight.w900)),
              ],

              // 🚀 THE MAGICAL DYNAMIC OFFER CHIP
              if (hasOffer && offerText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: offerColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: offerColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    offerText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: offerColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              hasOffer ? offerColor : cherryRedDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _isProcessing = false;
                          _scanStatus = ScanStatus.idle;
                        });
                      },
                      child: const Text("Scan Next",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              letterSpacing: 0.5)))),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String code) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.orange, size: 50),
              const SizedBox(height: 15),
              const Text("Item Not Found",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 5),
              Text("Barcode: $code",
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black87,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _isProcessing = false;
                          _scanStatus = ScanStatus.idle;
                        });
                      },
                      child: const Text("Try Again"))),
            ],
          ),
        ),
      ),
    );
  }
}
