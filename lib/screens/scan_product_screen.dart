import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import '../services/firestore/firestore_service.dart';
import '../services/cart/cart_service.dart';
import '../services/system/store_entry_service.dart';

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

  @override
  void dispose() {
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

    await HapticFeedback.heavyImpact();
    await HapticFeedback.heavyImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text("Scanning too fast! Blocked for 5s",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }

    await Future.delayed(const Duration(seconds: 5));
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

    _scanAttempts.add(now);
    _scanAttempts
        .removeWhere((t) => now.difference(t) > const Duration(seconds: 2));

    if (_scanAttempts.length >= 4) {
      _triggerSpamBlock();
      return;
    }

    if (_isProcessing ||
        (_lastScanTime != null &&
            now.difference(_lastScanTime!) < const Duration(seconds: 1))) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastScanTime = now;
      _scanStatus = ScanStatus.success;
    });

    try {
      await HapticFeedback.mediumImpact();
      await _player.play(AssetSource('sounds/beep.mp3'));
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 500));

    // 🚀 THE NEW ENTRY MODE LOGIC
    if (widget.isEntryMode) {
      // Import StoreEntryService upar
      bool success = StoreEntryService.parseScannedQR(code);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Check-In Successful!"),
                backgroundColor: Colors.green),
          );
          Navigator.pop(context); // Go back to Home
        }
      } else {
        _showErrorDialog("Invalid Store QR");
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
    final cart = context.read<CartService>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
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
          ColorFiltered(
            colorFilter:
                const ColorFilter.mode(Colors.black54, BlendMode.srcOut),
            child: Stack(
              children: [
                Container(
                    decoration: const BoxDecoration(
                        color: Colors.transparent,
                        backgroundBlendMode: BlendMode.dstOut)),
                Center(
                  child: Container(
                    height: 280,
                    width: 280,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 280,
              width: 280,
              decoration: BoxDecoration(
                border: Border.all(
                    color: _getBorderColor(), width: _isBlocked ? 8 : 4),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: _getBorderColor().withOpacity(0.5),
                      blurRadius: _isBlocked ? 40 : 20,
                      spreadRadius: 2)
                ],
              ),
              child: Stack(
                children: [
                  Align(
                      alignment: Alignment.topLeft,
                      child: _cornerWidget(_getBorderColor())),
                  Align(
                      alignment: Alignment.topRight,
                      child: RotatedBox(
                          quarterTurns: 1,
                          child: _cornerWidget(_getBorderColor()))),
                  Align(
                      alignment: Alignment.bottomLeft,
                      child: RotatedBox(
                          quarterTurns: 3,
                          child: _cornerWidget(_getBorderColor()))),
                  Align(
                      alignment: Alignment.bottomRight,
                      child: RotatedBox(
                          quarterTurns: 2,
                          child: _cornerWidget(_getBorderColor()))),
                  if (_isBlocked)
                    const Center(
                        child: Icon(Icons.block, color: Colors.red, size: 80))
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _glassButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => Navigator.pop(context)),
                  _glassButton(
                      icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: _isFlashOn ? Colors.yellow : Colors.white,
                      onTap: _toggleFlash),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                    _isBlocked
                        ? "SCANNER BLOCKED (Too Fast)"
                        : "Low light? Turn on Flash ⚡",
                    style: TextStyle(
                        color: _isBlocked ? Colors.redAccent : Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            _isBlocked ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (!kIsWeb)
                  GestureDetector(
                    onTap: () => _pickFromGallery(cart),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image, color: Colors.white),
                          SizedBox(width: 10),
                          Text("Scan from Gallery",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isProcessing && _scanStatus == ScanStatus.idle && !_isBlocked)
            Container(
                color: Colors.black54,
                child: Center(
                    child: CircularProgressIndicator(color: cherryRedLight))),
        ],
      ),
    );
  }

  Widget _cornerWidget(Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(color: color, width: 4),
            left: BorderSide(color: color, width: 4)),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20)),
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.black45,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24)),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  void _showProductFoundDialog(Map<String, dynamic> data, double price) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cherryRedDark, width: 2)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle,
                      color: Colors.green, size: 50)),
              const SizedBox(height: 15),
              const Text("Product Added!",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              Text(data['name'] ?? 'Unknown',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'DejaVuSansMono', fontSize: 16)),
              const SizedBox(height: 5),
              Text("Rs $price",
                  style: TextStyle(
                      fontFamily: 'DejaVuSansMono',
                      color: cherryRedDark,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: cherryRedDark,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _isProcessing = false;
                          _scanStatus = ScanStatus.idle;
                        });
                      },
                      child: const Text("Scan Next",
                          style: TextStyle(fontWeight: FontWeight.bold)))),
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
