import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart_item.dart';
import 'order_service.dart';

class CartService extends ChangeNotifier {
  Map<String, CartItem> _items = {};
  Map<String, CartItem> get items => _items;

  SharedPreferences? _prefs;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 🛡️ ANTI-FRAUD CORRECTION ENGINE VARIABLES
  bool _isCorrectionMode = false;
  String? _correctionOrderId;
  Map<String, int> _correctionOriginalQty = {};

  bool get isCorrectionMode => _isCorrectionMode;
  String? get correctionOrderId => _correctionOrderId;

  CartService() {
    debugPrint("🛒 CartService Started (Retail Grade)...");
    _initService();
  }

  Future<void> _initService() async {
    _prefs = await SharedPreferences.getInstance();

    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        debugPrint(
            "👤 User Found: ${user.uid} -> Running Sync & Midnight Checks...");
        await _checkMidnightReset(user.uid);
        await _loadCart(user.uid);
      } else {
        debugPrint("👋 User Logged Out -> Local Clear Only");
        _items = {};
        _clearCorrectionState();
        notifyListeners();
      }
    });
  }

  // 🛡️ --- CORRECTION MODE LOGIC --- 🛡️
  Future<void> loadOrderForCorrection(
      String orderId, List<dynamic> previousItems) async {
    debugPrint("🚨 ENTERING CORRECTION MODE FOR ORDER: $orderId");
    _items = {};
    _correctionOriginalQty = {};
    _isCorrectionMode = true;
    _correctionOrderId = orderId;

    for (var item in previousItems) {
      String barcode = item['barcode'];
      int qty = int.tryParse(
              item['qty']?.toString() ?? item['quantity']?.toString() ?? '1') ??
          1;

      // 🚀 THE FIX: Firebase se 'weight' aur 'weight_per_unit' dono check karo!
      double itemWeight = double.tryParse(item['weight']?.toString() ?? '') ??
          double.tryParse(item['weight_per_unit']?.toString() ?? '') ??
          0.0;

      _items[barcode] = CartItem(
          barcode: barcode,
          name: item['name'],
          originalPrice:
              double.tryParse(item['price'].toString()) ?? 0.0, // 🔥 FIXED
          gst: double.tryParse(item['gst'].toString()) ?? 0.0,
          weight: itemWeight,
          quantity: qty);

      _correctionOriginalQty[barcode] = qty;
    }

    notifyListeners();
    await _saveCart();
  }

  void exitCorrectionMode() {
    debugPrint("✅ EXITING CORRECTION MODE");
    _clearCorrectionState();
    clear();
  }

  void _clearCorrectionState() {
    _isCorrectionMode = false;
    _correctionOrderId = null;
    _correctionOriginalQty = {};
  }

  // --- 🌙 MIDNIGHT AUTO-RESET LOGIC ---
  Future<void> _checkMidnightReset(String uid) async {
    if (_prefs == null) return;
    final lastDateKey = 'last_active_date_$uid';
    String? lastDate = _prefs!.getString(lastDateKey);
    String todayDate = DateTime.now().toString().split(' ')[0];

    if (lastDate != null && lastDate != todayDate) {
      debugPrint("🌙 Midnight Detected! Checking for stale cart cleanup...");
      String? pendingOrderId = await OrderService().getActiveOrderId(uid);

      if (pendingOrderId == null) {
        debugPrint("🧹 No active pending orders. Wiping stale cart data.");
        _items = {};
        _clearCorrectionState();
        await _clearStorage(uid);
      } else {
        debugPrint(
            "⏳ Payment Pending found for Order: $pendingOrderId. Keeping cart.");
      }
    }
    await _prefs!.setString(lastDateKey, todayDate);
  }

  // --- 🛒 HYBRID LOAD LOGIC ---
  Future<void> _loadCart(String uid) async {
    if (_prefs == null) return;
    final key = 'cart_$uid';
    final String? localJson = _prefs!.getString(key);

    if (localJson != null) {
      _processCartJson(localJson);
      debugPrint("✅ LOADED: Local Cache");
    }

    try {
      debugPrint("☁️ Fetching from Cloud for UID: $uid...");
      DocumentSnapshot cloudSnap = await _db.collection('carts').doc(uid).get();

      if (cloudSnap.exists) {
        final data = cloudSnap.data() as Map<String, dynamic>;
        List<dynamic> cloudItems = data['items'] ?? [];

        _isCorrectionMode = data['isCorrectionMode'] ?? false;
        _correctionOrderId = data['correctionOrderId'];

        if (data['correctionOriginalQty'] != null) {
          _correctionOriginalQty =
              Map<String, int>.from(data['correctionOriginalQty']);
        }

        if (cloudItems.isNotEmpty) {
          String cloudJson = jsonEncode(cloudItems);
          _processCartJson(cloudJson);
          await _prefs!.setString(key, cloudJson);
          debugPrint("☁️ SUCCESS: Cloud Cart synced to this device!");
        }
      }
    } catch (e) {
      debugPrint("⚠️ Cloud Sync Error: $e");
    }
    notifyListeners();
  }

  void _processCartJson(String rawJson) {
    try {
      List<dynamic> decodedList = jsonDecode(rawJson);
      _items = {};
      for (var itemJson in decodedList) {
        CartItem item = CartItem.fromJson(itemJson);
        _items[item.barcode] = item;
      }
    } catch (e) {
      debugPrint("❌ Json Process Error: $e");
    }
  }

  // --- 💾 HYBRID SAVE LOGIC ---
  Future<void> _saveCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _prefs == null) return;

    final key = 'cart_${user.uid}';
    List<Map<String, dynamic>> saveableList =
        _items.values.map((i) => i.toJson()).toList();
    String rawJson = jsonEncode(saveableList);

    await _prefs!.setString(key, rawJson);

    try {
      await _db.collection('carts').doc(user.uid).set({
        'items': saveableList,
        'isCorrectionMode': _isCorrectionMode,
        'correctionOrderId': _correctionOrderId,
        'correctionOriginalQty': _correctionOriginalQty,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint("💾 SYNCED: Local + Cloud");
    } catch (e) {
      debugPrint("❌ Sync Failed: $e");
    }
  }

  // --- CRUD Operations ---
  void add(
      {required String barcode,
      required String name,
      required double price,
      required double gst,
      required double weight,
      int stock = 999,
      int maxQtyPerOrder = 99}) {
    if (_isCorrectionMode && !_items.containsKey(barcode)) {
      throw "Security Alert: You cannot add NEW items during Guard Correction Mode. Please remove/reduce items only.";
    }

    if (stock <= 0) throw "Item Out of Stock";

    if (_items.containsKey(barcode)) {
      CartItem existing = _items[barcode]!;
      if (existing.quantity >= maxQtyPerOrder) throw "Max limit reached";
      if (existing.quantity >= stock) throw "Stock limit reached";

      if (_isCorrectionMode) {
        int maxAllowed = _correctionOriginalQty[barcode] ?? 0;
        if (existing.quantity >= maxAllowed) {
          throw "Security Alert: You cannot increase quantity beyond the original order.";
        }
      }

      _items.update(
          barcode,
          (existing) => CartItem(
                barcode: existing.barcode,
                name: existing.name,
                originalPrice: existing.originalPrice, // 🔥 FIXED
                gst: existing.gst,
                weight: existing.weight,
                quantity: existing.quantity + 1,
                clearanceActive:
                    existing.clearanceActive, // 🔥 PRESERVED BOGO/OFFER
                clearanceType: existing.clearanceType,
                clearanceValue: existing.clearanceValue,
              ));
    } else {
      _items.putIfAbsent(
          barcode,
          () => CartItem(
              barcode: barcode,
              name: name,
              originalPrice: price, // 🔥 FIXED
              gst: gst,
              weight: weight,
              quantity: 1));
    }
    notifyListeners();
    _saveCart();
  }

  void increment(String barcode) {
    if (_items.containsKey(barcode)) {
      if (_isCorrectionMode) {
        int currentQty = _items[barcode]!.quantity;
        int maxAllowed = _correctionOriginalQty[barcode] ?? 0;
        if (currentQty >= maxAllowed) {
          debugPrint(
              "🛑 FRAUD PREVENTED: Blocked increment beyond original qty.");
          return;
        }
      }

      _items.update(
          barcode,
          (existing) => CartItem(
                barcode: existing.barcode,
                name: existing.name,
                originalPrice: existing.originalPrice, // 🔥 FIXED
                gst: existing.gst,
                weight: existing.weight,
                quantity: existing.quantity + 1,
                clearanceActive:
                    existing.clearanceActive, // 🔥 PRESERVED BOGO/OFFER
                clearanceType: existing.clearanceType,
                clearanceValue: existing.clearanceValue,
              ));
      notifyListeners();
      _saveCart();
    }
  }

  void decrement(String barcode) {
    if (!_items.containsKey(barcode)) return;
    if (_items[barcode]!.quantity > 1) {
      _items.update(
          barcode,
          (existing) => CartItem(
                barcode: existing.barcode,
                name: existing.name,
                originalPrice: existing.originalPrice, // 🔥 FIXED
                gst: existing.gst,
                weight: existing.weight,
                quantity: existing.quantity - 1,
                clearanceActive:
                    existing.clearanceActive, // 🔥 PRESERVED BOGO/OFFER
                clearanceType: existing.clearanceType,
                clearanceValue: existing.clearanceValue,
              ));
    } else {
      _items.remove(barcode);
    }
    notifyListeners();
    _saveCart();
  }

  void deleteItem(String barcode) {
    _items.remove(barcode);
    notifyListeners();
    _saveCart();
  }

  void clear() {
    _items = {};
    _clearCorrectionState();
    notifyListeners();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _clearStorage(user.uid);
    }
  }

  Future<void> _clearStorage(String uid) async {
    if (_prefs != null) await _prefs!.remove('cart_$uid');
    await _db.collection('carts').doc(uid).delete();
    debugPrint("🧹 Storage Cleared (Local & Cloud)");
  }

  // --- Getters ---
  int get totalItems => _items.length;

  // 🧠 SMART CALCULATION (Using Client Side Engine Math)
  double get grandTotal {
    double total = 0.0;
    _items.forEach(
        (key, item) => total += item.totalPrice); // 🔥 USING SMART TOTAL
    return total;
  }

  double get totalGST {
    double total = 0.0;
    _items.forEach((key, item) {
      // GST is calculated on Final Discounted Price, for the Payable Quantity!
      double gstAmount = (item.finalUnitPrice * item.gst) / 100;
      total += gstAmount * item.payableQty;
    });
    return total;
  }

  double get totalWeight {
    double total = 0.0;
    _items.forEach((key, item) =>
        total += item.totalWeight); // 🔥 Uses BOGO doubled weight
    return total;
  }

  // --- Validation Logic ---
  Future<List<String>> validateCart() async {
    List<String> warnings = [];
    List<String> itemsToRemove = [];
    bool hasChanges = false;
    if (_items.isEmpty) return [];

    try {
      for (String barcode in List<String>.from(_items.keys)) {
        DocumentSnapshot doc =
            await _db.collection('products').doc(barcode).get();
        if (!doc.exists) {
          warnings.add("Item removed from store.");
          itemsToRemove.add(barcode);
          hasChanges = true;
          continue;
        }

        final data = doc.data() as Map<String, dynamic>;
        final double freshPrice =
            double.tryParse(data['price'].toString()) ?? 0.0;
        final int liveStock = int.tryParse(data['stock']?.toString() ??
                data['physicalStock']?.toString() ??
                '0') ??
            0;
        CartItem currentItem = _items[barcode]!;

        if (liveStock == 0) {
          warnings.add("${data['name']} Out of Stock.");
          itemsToRemove.add(barcode);
          hasChanges = true;
        }

        if ((currentItem.originalPrice - freshPrice).abs() > 0.01) {
          // 🔥 FIXED
          warnings.add("Price updated for ${data['name']}.");
          _items.update(
              barcode,
              (existing) => CartItem(
                    barcode: existing.barcode,
                    name: existing.name,
                    originalPrice: freshPrice, // 🔥 FIXED
                    gst: existing.gst,
                    weight: existing.weight,
                    quantity: existing.quantity,
                    clearanceActive: existing.clearanceActive,
                    clearanceType: existing.clearanceType,
                    clearanceValue: existing.clearanceValue,
                  ));
          hasChanges = true;
        }
      }

      for (String code in itemsToRemove) {
        _items.remove(code);
      }
      if (hasChanges) {
        _saveCart();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Validation Error: $e");
    }
    return warnings;
  }
}
