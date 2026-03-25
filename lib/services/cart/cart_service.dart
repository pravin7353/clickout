// lib/services/cart/cart_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/cart_item.dart';
import '../orders/order_service.dart';
import 'cart_validator_service.dart';
import '../../utils/user_session.dart'; // 🚀 SAAS INJECTION IMPORT

class CartService extends ChangeNotifier {
  Map<String, CartItem> _items = {};
  Map<String, CartItem> get items => _items;

  SharedPreferences? _prefs;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final CartValidatorService _validatorService = CartValidatorService();

  bool _isCorrectionMode = false;
  String? _correctionOrderId;
  Map<String, int> _correctionOriginalQty = {};

  bool get isCorrectionMode => _isCorrectionMode;
  String? get correctionOrderId => _correctionOrderId;

  CartService() {
    _initService();
  }

  Future<void> _initService() async {
    _prefs = await SharedPreferences.getInstance();
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _checkMidnightReset(user.uid);
        await _loadCart(user.uid);
      } else {
        _items = {};
        _clearCorrectionState();
        notifyListeners();
      }
    });
  }

  Future<void> add(
      {required String barcode,
      required String name,
      required double price,
      required double gst,
      required double weight}) async {
    if (_isCorrectionMode) throw "Cart locked due to gate pass.";

    final snap = await _db
        .collection('products')
        .where('barcode', isEqualTo: barcode)
        .where('tenantId', isEqualTo: UserSession.tenantId) // 🚀 SAAS INJECTION
        .where('storeId', isEqualTo: UserSession.storeId) // 🚀 SAAS INJECTION
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (snap.docs.isEmpty) throw "Item not found in database!";
    final pData = snap.docs.first.data();

    if (pData['isBlocked'] == true) {
      throw "🚫 DEAD STOCK: Item is currently blocked and cannot be sold.";
    }
    if (pData['expiryDate'] != null) {
      final expiryDate = (pData['expiryDate'] as Timestamp).toDate();
      if (expiryDate.isBefore(DateTime.now())) {
        throw "🚫 EXPIRED ITEM: This item is past its expiry date.";
      }
    }

    int liveStock = pData['physicalStock'] ?? pData['stock'] ?? 0;
    if (liveStock <= 0) throw "Item Out of Stock!";

    bool cActive = pData['clearanceActive'] == true;
    String cType = cActive ? (pData['clearanceType'] ?? '') : '';
    int bQty = 1;
    int fQty = 0;
    double cVal = 0.0;
    String fId = '';
    String fName = '';
    double cPrice = 0.0;

    if (cActive) {
      bQty = pData['buyQty'] ?? 1;
      fQty = pData['freeQty'] ?? 0;
      cVal = double.tryParse(pData['clearanceValue']?.toString() ??
              pData['flatDiscount']?.toString() ??
              '0') ??
          0.0;

      if (cType == 'BUY_X_GET_Y') {
        fId = pData['freeProductId'] ?? '';
        fName = pData['freeProductName'] ?? '';

        if (fId.isNotEmpty) {
          final ySnap = await _db
              .collection('products')
              .where('barcode', isEqualTo: fId)
              .where('tenantId',
                  isEqualTo: UserSession.tenantId) // 🚀 SAAS INJECTION
              .where('storeId',
                  isEqualTo: UserSession.storeId) // 🚀 SAAS INJECTION
              .limit(1)
              .get(const GetOptions(source: Source.server));
          if (ySnap.docs.isEmpty ||
              ySnap.docs.first.data()['isBlocked'] == true ||
              (ySnap.docs.first.data()['physicalStock'] ?? 0) <= 0 ||
              (ySnap.docs.first.data()['expiryDate'] != null &&
                  (ySnap.docs.first.data()['expiryDate'] as Timestamp)
                      .toDate()
                      .isBefore(DateTime.now()))) {
            cActive = false;
            cType = 'DEAD_OFFER';
          }
        }
      }
      if (cType == 'COMBO') {
        cPrice = double.tryParse(pData['comboPrice']?.toString() ?? '0') ?? 0.0;
      }
    }

    if (_items.containsKey(barcode)) {
      CartItem existing = _items[barcode]!;
      if (existing.quantity >= liveStock) {
        throw "Only $liveStock units available in store inventory!";
      }

      _items[barcode] = CartItem(
          barcode: barcode,
          name: pData['name'] ?? name,
          originalPrice:
              double.tryParse(pData['price']?.toString() ?? price.toString()) ??
                  0.0,
          gst: double.tryParse(pData['gst']?.toString() ?? gst.toString()) ??
              0.0,
          weight: double.tryParse(
                  pData['weight']?.toString() ?? weight.toString()) ??
              0.0,
          quantity: existing.quantity + 1,
          clearanceActive: cActive,
          clearanceType: cType,
          buyQty: bQty,
          freeQty: fQty,
          clearanceValue: cVal,
          freeProductId: fId,
          freeProductName: fName,
          comboPrice: cPrice);
    } else {
      _items[barcode] = CartItem(
          barcode: barcode,
          name: pData['name'] ?? name,
          originalPrice:
              double.tryParse(pData['price']?.toString() ?? price.toString()) ??
                  0.0,
          gst: double.tryParse(pData['gst']?.toString() ?? gst.toString()) ??
              0.0,
          weight: double.tryParse(
                  pData['weight']?.toString() ?? weight.toString()) ??
              0.0,
          quantity: 1,
          clearanceActive: cActive,
          clearanceType: cType,
          buyQty: bQty,
          freeQty: fQty,
          clearanceValue: cVal,
          freeProductId: fId,
          freeProductName: fName,
          comboPrice: cPrice);
    }
    notifyListeners();
    _saveCart();
  }

  Future<void> increment(String barcode) async {
    if (_isCorrectionMode) throw "Cart locked.";
    if (!_items.containsKey(barcode)) return;

    final snap = await _db
        .collection('products')
        .where('barcode', isEqualTo: barcode)
        .where('tenantId', isEqualTo: UserSession.tenantId) // 🚀 SAAS INJECTION
        .where('storeId', isEqualTo: UserSession.storeId) // 🚀 SAAS INJECTION
        .limit(1)
        .get(const GetOptions(source: Source.server));
    if (snap.docs.isEmpty) return;
    final pData = snap.docs.first.data();

    if (pData['isBlocked'] == true) {
      deleteItem(barcode);
      throw "Item was just blocked/removed by Admin!";
    }

    int liveStock = pData['physicalStock'] ?? pData['stock'] ?? 0;
    if (_items[barcode]!.quantity >= liveStock) {
      throw "Stock limit reached! Only $liveStock available.";
    }

    _items.update(barcode,
        (existing) => existing.copyWith(quantity: existing.quantity + 1));
    notifyListeners();
    _saveCart();
  }

  void decrement(String barcode) {
    if (_isCorrectionMode) throw "Cart locked.";
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
    if (_isCorrectionMode) throw "Cart locked.";
    _items.remove(barcode);
    notifyListeners();
    _saveCart();
  }

  void clear() {
    if (_isCorrectionMode) throw "Cart locked.";
    _items = {};
    _clearCorrectionState();
    notifyListeners();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _clearStorage(user.uid);
  }

  Future<void> clearCart() async {
    _items.clear();
    _clearCorrectionState();
    notifyListeners();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _clearStorage(user.uid);
    }
  }

  Future<void> _clearStorage(String uid) async {
    if (_prefs != null) await _prefs!.remove('cart_$uid');
    await _db.collection('carts').doc(uid).delete();
  }

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
      total += gstAmount * item.quantity;
    });
    return total;
  }

  Future<List<String>> validateCart() async {
    final validationResult =
        await _validatorService.validate(_items, _isCorrectionMode);
    List<String> warnings = validationResult['warnings'];
    List<String> itemsToRemove = validationResult['itemsToRemove'];
    Map<String, CartItem> updates = validationResult['updates'];

    bool hasChanges = itemsToRemove.isNotEmpty || updates.isNotEmpty;
    for (String code in itemsToRemove) {
      _items.remove(code);
    }
    updates.forEach((barcode, updatedItem) => _items[barcode] = updatedItem);

    if (hasChanges) {
      _saveCart();
      notifyListeners();
    }
    return warnings;
  }

  Future<void> loadOrderForCorrection(
      String orderId, List<dynamic> previousItems) async {
    _items = {};
    _correctionOriginalQty = {};
    _isCorrectionMode = true;
    _correctionOrderId = orderId;
    for (var item in previousItems) {
      String barcode = item['barcode'] ?? 'UNKNOWN';
      int qty = int.tryParse(
              item['qty']?.toString() ?? item['quantity']?.toString() ?? '1') ??
          1;
      double price = double.tryParse(item['originalPrice']?.toString() ??
              item['price']?.toString() ??
              '0') ??
          0.0;
      _items[barcode] = CartItem(
          barcode: barcode,
          name: item['name'] ?? 'Item',
          originalPrice: price,
          gst: 0.0,
          weight: 0.0,
          quantity: qty);
      _correctionOriginalQty[barcode] = qty;
    }
    notifyListeners();
    await _saveCart();
  }

  void exitCorrectionMode() {
    _clearCorrectionState();
    clear();
  }

  void _clearCorrectionState() {
    _isCorrectionMode = false;
    _correctionOrderId = null;
    _correctionOriginalQty = {};
  }

  Future<void> _checkMidnightReset(String uid) async {
    if (_prefs == null) return;
    final lastDateKey = 'last_active_date_$uid';
    String? lastDate = _prefs!.getString(lastDateKey);
    String todayDate = DateTime.now().toString().split(' ')[0];

    if (lastDate != null && lastDate != todayDate) {
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

        if (_isCorrectionMode && _correctionOrderId != null) {
          var oSnap =
              await _db.collection('orders').doc(_correctionOrderId).get();
          if (oSnap.exists) {
            var oData = oSnap.data() as Map<String, dynamic>;
            if (oData['qrConsumed'] == true ||
                oData['exitStatus'] == 'EXITED' ||
                oData['exitStatus'] == 'APPROVED') {
              debugPrint("🔓 Trapped Order Detected! Auto-unlocking Cart...");
              _isCorrectionMode = false;
              _correctionOrderId = null;
              _correctionOriginalQty = {};
              cloudItems = [];
              _items = {};
              await _clearStorage(uid);
            }
          }
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
      debugPrint("Cart Ignore Error: $e");
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
        'tenantId': UserSession.tenantId, // 🚀 SAAS INJECTION
        'storeId': UserSession.storeId, // 🚀 SAAS INJECTION
        'branchCode': UserSession.branchCode, // 🚀 SAAS INJECTION
      });
    } catch (e) {
      debugPrint("Cart Ignore Error: $e");
    }
  }
}
