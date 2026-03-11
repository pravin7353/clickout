// lib/services/cart/cart_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/cart_item.dart';
import '../orders/order_service.dart'; // Make sure this path is correct based on your folder structure
import '../inventory/inventory_service.dart';
import 'cart_validator_service.dart';

class CartService extends ChangeNotifier {
  Map<String, CartItem> _items = {};
  Map<String, CartItem> get items => _items;

  SharedPreferences? _prefs;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 💉 INJECTED NEW SERVICES
  final InventoryService _inventoryService = InventoryService();
  final CartValidatorService _validatorService = CartValidatorService();

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

  // 🛡️ --- CORRECTION MODE LOGIC (Unchanged) --- 🛡️
  Future<void> loadOrderForCorrection(
      String orderId, List<dynamic> previousItems) async {
    debugPrint("🚨 ENTERING CORRECTION MODE FOR ORDER: $orderId");
    _items = {};
    _correctionOriginalQty = {};
    _isCorrectionMode = true;
    _correctionOrderId = orderId;

    for (var item in previousItems) {
      String barcode = item['barcode'] ?? 'UNKNOWN';
      int qty = int.tryParse(
              item['qty']?.toString() ?? item['quantity']?.toString() ?? '1') ??
          1;
      double itemWeight = double.tryParse(item['weight']?.toString() ?? '') ??
          double.tryParse(item['weight_per_unit']?.toString() ?? '') ??
          0.0;
      double price = double.tryParse(item['originalPrice']?.toString() ??
              item['price']?.toString() ??
              item['finalUnitPrice']?.toString() ??
              '0') ??
          0.0;
      double gstAmount = double.tryParse(item['gst']?.toString() ?? '0') ?? 0.0;

      _items[barcode] = CartItem(
          barcode: barcode,
          name: item['name'] ?? 'Item',
          originalPrice: price,
          gst: gstAmount,
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

  // 🌙 --- SYNC & STORAGE LOGIC (Unchanged) --- 🌙
  Future<void> _checkMidnightReset(String uid) async {
    if (_prefs == null) return;
    final lastDateKey = 'last_active_date_$uid';
    String? lastDate = _prefs!.getString(lastDateKey);
    String todayDate = DateTime.now().toString().split(' ')[0];

    if (lastDate != null && lastDate != todayDate) {
      debugPrint("🌙 Midnight Detected! Checking for stale cart cleanup...");
      String? pendingOrderId = await OrderService().getActiveOrderId(uid);

      if (pendingOrderId == null) {
        _items = {};
        _clearCorrectionState();
        await _clearStorage(uid);
      }
    }
    await _prefs!.setString(lastDateKey, todayDate);
  }

  Future<void> _loadCart(String uid) async {
    if (_prefs == null) return;
    final key = 'cart_$uid';
    final String? localJson = _prefs!.getString(key);

    if (localJson != null) {
      _processCartJson(localJson);
    }

    try {
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
    } catch (e) {
      debugPrint("❌ Sync Failed: $e");
    }
  }

  // 🛒 --- CORE CART ACTIONS (Now using InventoryService) --- 🛒
  Future<void> add({
    required String barcode,
    required String name,
    required double price,
    required double gst,
    required double weight,
  }) async {
    if (_isCorrectionMode) {
      throw "Cart locked due to rejected gate pass. Contact cashier.";
    }

    // ✨ CLEANER: Using Inventory Service
    final productData = await _inventoryService.getProductLiveDetails(barcode);
    if (productData == null) throw "Item not found in database!";

    int liveStock = _inventoryService.getLiveStock(productData);
    if (liveStock <= 0) throw "Item Out of Stock!";

    if (_items.containsKey(barcode)) {
      CartItem existing = _items[barcode]!;
      if (existing.quantity >= liveStock) {
        throw "Only $liveStock units available in store!";
      }
      _items.update(barcode,
          (existing) => existing.copyWith(quantity: existing.quantity + 1));
    } else {
      _items.putIfAbsent(
          barcode,
          () => CartItem(
              barcode: barcode,
              name: name,
              originalPrice: price,
              gst: gst,
              weight: weight,
              quantity: 1));
    }
    notifyListeners();
    _saveCart();
  }

  Future<void> increment(String barcode) async {
    if (_isCorrectionMode) {
      throw "Cart locked due to rejected gate pass. Contact cashier.";
    }

    if (_items.containsKey(barcode)) {
      // ✨ CLEANER: Using Inventory Service
      final productData =
          await _inventoryService.getProductLiveDetails(barcode);
      if (productData != null) {
        int liveStock = _inventoryService.getLiveStock(productData);
        if (_items[barcode]!.quantity >= liveStock) {
          throw "Stock limit reached! Only $liveStock available.";
        }
      }

      _items.update(barcode,
          (existing) => existing.copyWith(quantity: existing.quantity + 1));
      notifyListeners();
      _saveCart();
    }
  }

  void decrement(String barcode) {
    if (_isCorrectionMode) {
      throw "Cart locked due to rejected gate pass. Contact cashier.";
    }
    if (!_items.containsKey(barcode)) return;

    if (_items[barcode]!.quantity > 1) {
      _items.update(barcode,
          (existing) => existing.copyWith(quantity: existing.quantity - 1));
    } else {
      _items.remove(barcode);
    }
    notifyListeners();
    _saveCart();
  }

  void deleteItem(String barcode) {
    if (_isCorrectionMode) {
      throw "Cart locked due to rejected gate pass. Contact cashier.";
    }
    _items.remove(barcode);
    notifyListeners();
    _saveCart();
  }

  void clear() {
    if (_isCorrectionMode) {
      throw "Cart locked due to rejected gate pass. Contact cashier.";
    }
    _items = {};
    _clearCorrectionState();
    notifyListeners();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _clearStorage(user.uid);
  }

  Future<void> _clearStorage(String uid) async {
    if (_prefs != null) await _prefs!.remove('cart_$uid');
    await _db.collection('carts').doc(uid).delete();
  }

  // 🧮 --- MATHEMATICS --- 🧮
  int get totalItems => _items.length;
  double get grandTotal {
    double total = 0.0;
    _items.forEach((key, item) => total += item.totalPrice);
    return total;
  }

  double get totalGST {
    double total = 0.0;
    _items.forEach((key, item) {
      double gstAmount = (item.finalUnitPrice * item.gst) / 100;
      total += gstAmount * item.payableQty;
    });
    return total;
  }

  double get totalWeight {
    double total = 0.0;
    _items.forEach((key, item) => total += item.totalWeight);
    return total;
  }

  // ✅ --- THE NEW CLEAN VALIDATOR --- ✅
  Future<List<String>> validateCart() async {
    // Calling the newly separated validator service
    final validationResult =
        await _validatorService.validate(_items, _isCorrectionMode);

    List<String> warnings = validationResult['warnings'];
    List<String> itemsToRemove = validationResult['itemsToRemove'];
    Map<String, CartItem> updates = validationResult['updates'];

    bool hasChanges = itemsToRemove.isNotEmpty || updates.isNotEmpty;

    // Apply Deletions
    for (String code in itemsToRemove) {
      _items.remove(code);
    }

    // Apply Updates
    updates.forEach((barcode, updatedItem) {
      _items[barcode] = updatedItem;
    });

    if (hasChanges) {
      _saveCart();
      notifyListeners();
    }

    return warnings;
  }
}
