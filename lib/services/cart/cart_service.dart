import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/cart_item.dart';
import '../orders/order_service.dart';
import 'cart_validator_service.dart';
import '../../utils/user_session.dart';
import '../offers/offer_engine_service.dart';

class CartService extends ChangeNotifier {
  Map<String, CartItem> _rawItems = {};
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

  List<Map<String, dynamic>> _activeOffers = [];
  List<Map<String, dynamic>> get activeOffers => _activeOffers;

  String? _appliedPromoCode;
  double _promoDiscountPercent = 0.0;
  bool _isWinbackApplied = false;
  String? get appliedPromoCode => _appliedPromoCode;
  double get promoDiscountPercent => _promoDiscountPercent;

  CartService() {
    _initService();
  }

  Future<void> _initService() async {
    _prefs = await SharedPreferences.getInstance();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final String? localJson = _prefs!.getString('cart_${user.uid}');
      if (localJson != null) {
        _processCartJson(localJson);
        notifyListeners();
      }
    }

    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        await _checkMidnightReset(user.uid);
        await _loadCart(user.uid);
      } else {
        _rawItems = {};
        _items = {};
        _clearCorrectionState();
        notifyListeners();
      }
    });
  }

  // ─── Offer Apply ─────────────────────────────────────────────────────────
  Future<void> fetchAndApplyOffers() async {
    try {
      final snap = await _db
          .collection('products')
          .where('clearanceActive', isEqualTo: true)
          .where('tenantId', isEqualTo: UserSession.tenantId)
          .get();
      _activeOffers = snap.docs.map((doc) => doc.data()).toList();
      _applyOffersLocally();
    } catch (e) {
      debugPrint("Offer Fetch Error: $e");
    }
  }

  void _applyOffersLocally() {
    if (_rawItems.isEmpty) return;
    Map<String, int> stock = {};
    for (var o in _activeOffers) {
      String bc =
          o['barcode']?.toString().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '') ??
              '';
      if (bc.isNotEmpty) stock[bc] = o['physicalStock'] ?? o['stock'] ?? 999;
    }
    final r = OfferEngineService.applyAllOffers(
      cartItems: _rawItems,
      activeOffers: _activeOffers,
      liveStockLogs: stock,
    );
    _items = r.updatedCartItems;
  }

  // ─── Computed getters ─────────────────────────────────────────────────────
  int get totalItems => _rawItems.length;

  double get grandTotal {
    double t = 0.0;
    _items.forEach((_, i) => t += i.totalPrice);
    if (_promoDiscountPercent > 0) t *= (1 - _promoDiscountPercent / 100);
    return t;
  }

  double get promoDiscountAmount {
    double base = 0.0;
    _items.forEach((_, i) => base += i.totalPrice);
    return base * (_promoDiscountPercent / 100);
  }

  double get totalGST {
    double t = 0.0;
    _items.forEach(
        (_, i) => t += (i.finalUnitPrice * i.gst / 100) * i.payableQty);
    return t;
  }

  int _totalQtyFor(String base) => _rawItems[base]?.quantity ?? 0;

  // ─── Live product fetch ───────────────────────────────────────────────────
  final Map<String, Map<String, dynamic>> _productCache = {};

  Future<Map<String, dynamic>?> _getSafeProduct(String barcode,
      {bool forceServer = false}) async {
    try {
      String target = barcode.replaceAll(RegExp(r'[^0-9a-zA-Z\-_]'), '');

      // 🚀 FIX: Memory Fallback (RAM clean hone par local storage use hoga)
      String tId = UserSession.tenantId.isNotEmpty
          ? UserSession.tenantId
          : (_prefs?.getString('saved_tenantId') ?? '');
      String sId = UserSession.storeId.isNotEmpty
          ? UserSession.storeId
          : (_prefs?.getString('saved_storeId') ?? '');
      if (tId.isEmpty || sId.isEmpty) {
        throw "Session empty. Please re-scan store QR.";
      }

      String docId = '${tId}_${sId}_$target';

      if (!forceServer && _productCache.containsKey(docId)) {
        return _productCache[docId];
      }

      // 🚀 FIX: Phantom Stock - Force live read on add/increment
      GetOptions options = forceServer
          ? const GetOptions(source: Source.server)
          : const GetOptions(source: Source.cache);
      var doc = await _db.collection('products').doc(docId).get(options);

      if (!doc.exists && !forceServer) {
        doc = await _db
            .collection('products')
            .doc(docId)
            .get(const GetOptions(source: Source.server));
      }

      if (doc.exists) {
        _productCache[docId] = doc.data()!;
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint("Product Fetch Error: $e");
      return null;
    }
  }

  // ─── ADD ─────────────────────────────────────────────────────────────────
  Future<void> add({
    required String barcode,
    required String name,
    required double price,
    required double gst,
    required double weight,
  }) async {
    if (_isCorrectionMode) throw "Cart locked due to gate pass.";

    // 🚀 FIX: Bypass cache to check true live stock (No Phantom Stock)
    final pData = await _getSafeProduct(barcode, forceServer: true);
    if (pData == null) throw "Item not found in database!";
    if (pData['isBlocked'] == true) {
      throw "🚫 DEAD STOCK: Item is currently blocked.";
    }
    if (pData['expiryDate'] != null &&
        (pData['expiryDate'] as Timestamp).toDate().isBefore(DateTime.now())) {
      throw "🚫 EXPIRED ITEM: This item is past its expiry date.";
    }

    // 🚀 SAAS LOGIC: Check if it's a Virtual Service (No stock limit)
    bool isService = pData['itemType'] == 'SERVICE';

    // 🚀 OPTIMISTIC CHECKOUT: Only check Physical Stock for Products
    int physicalStock = pData['physicalStock'] ?? 0;

    if (!isService && physicalStock <= 0) throw "Item Out of Stock!";

    int newQty = _totalQtyFor(barcode) + 1;
    if (!isService && newQty > physicalStock) {
      throw "Only $physicalStock units available in store inventory!";
    }

    double cleanGst = double.tryParse(
            pData['gst']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ??
                gst.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;
    double cleanWeight = double.tryParse(
            pData['weight']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ??
                weight.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;

    _rawItems[barcode] = CartItem(
      barcode: barcode,
      name: pData['name'] ?? name,
      originalPrice:
          double.tryParse(pData['price']?.toString() ?? price.toString()) ??
              0.0,
      gst: cleanGst,
      weight: cleanWeight,
      quantity: newQty,
    );

    await fetchAndApplyOffers();
    notifyListeners();
    _saveCart();
  }

  // ─── INCREMENT ────────────────────────────────────────────────────────────
  Future<void> increment(String barcode) async {
    if (_isCorrectionMode) throw "Cart locked.";
    if (barcode.endsWith('_FREE')) {
      throw "Free promotional item. Modify the main product to adjust quantities.";
    }
    final String base =
        barcode.replaceAll('_OVERFLOW', '').replaceAll('_FREE', '');

    // 🚀 FIX: Bypass cache to check true live stock
    final pData = await _getSafeProduct(base, forceServer: true);
    if (pData == null) {
      _removeBase(base);
      throw "Item removed from store database.";
    }
    if (pData['isBlocked'] == true) {
      _removeBase(base);
      throw "Item was just blocked/removed by Admin!";
    }

    // 🚀 SAAS LOGIC: Check if it's a Virtual Service (No stock limit)
    bool isService = pData['itemType'] == 'SERVICE';

    // 🚀 OPTIMISTIC CHECKOUT: Only check Physical Stock for Products
    int physicalStock = pData['physicalStock'] ?? 0;
    int newQty = _totalQtyFor(base) + 1;
    if (!isService && newQty > physicalStock) {
      throw "Stock limit reached! Only $physicalStock available.";
    }

    final existing = _rawItems[base];
    if (existing != null) _rawItems[base] = existing.copyWith(quantity: newQty);

    await fetchAndApplyOffers();
    notifyListeners();
    _saveCart();
  }

  // ─── DECREMENT ────────────────────────────────────────────────────────────
  void decrement(String barcode) {
    if (_isCorrectionMode) throw "Cart locked.";
    if (barcode.endsWith('_FREE')) throw "Modify the main product.";

    final String base =
        barcode.replaceAll('_OVERFLOW', '').replaceAll('_FREE', '');
    int currentQty = _totalQtyFor(base);

    if (currentQty <= 1) return;

    int newQty = currentQty - 1;
    final existing = _rawItems[base];
    if (existing != null) {
      _rawItems[base] = existing.copyWith(quantity: newQty);
      _applyOffersLocally();
      notifyListeners();
      _saveCart();
    }
  }

  // ─── DELETE ───────────────────────────────────────────────────────────────
  void deleteItem(String barcode) {
    if (_isCorrectionMode) throw "Cart locked.";
    final String base =
        barcode.replaceAll('_OVERFLOW', '').replaceAll('_FREE', '');

    _removeBase(base);
    _applyOffersLocally();
    notifyListeners();
    _saveCart();
  }

  void _removeBase(String base) {
    _rawItems.remove(base);
    _items.remove(base);
    _items.remove('${base}_FREE');
    _items.remove('${base}_OVERFLOW');
  }

  // ─── CLEAR ────────────────────────────────────────────────────────────────
  void clear() {
    if (_isCorrectionMode) throw "Cart locked.";
    _rawItems = {};
    _items = {};
    _clearCorrectionState();
    notifyListeners();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _clearStorage(user.uid);
  }

  Future<void> clearCart() async {
    _rawItems = {};
    _items = {};
    _clearCorrectionState();
    notifyListeners();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) await _clearStorage(user.uid);
  }

  Future<void> _clearStorage(String uid) async {
    if (_prefs != null) await _prefs!.remove('cart_$uid');
    await _db.collection('carts').doc(uid).delete();
  }

  // ─── PROMO CODE ───────────────────────────────────────────────────────────
  Future<void> applyPromoCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw "Please login to apply offers.";

    // 1. OLD HARDCODED FALLBACK (For older users compatibility)
    if (code == "COMEBACK20") {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()?['winbackActive'] == true) {
        _appliedPromoCode = "COMEBACK20";
        _promoDiscountPercent = 20.0;
        _isWinbackApplied = true;
        notifyListeners();
        return;
      }
    }

    // 🚀 2. DYNAMIC COUPON ENGINE (Targeted & Multi-Tenant Validations)
    try {
      // Coupon Document ID Admin panel se aise save hota hai: tenantId_CODE
      String couponDocId = '${UserSession.tenantId}_$code';
      DocumentSnapshot couponDoc =
          await _db.collection('coupons').doc(couponDocId).get();

      if (!couponDoc.exists) {
        throw "Invalid Promo Code.";
      }

      final data = couponDoc.data() as Map<String, dynamic>;

      // 🛑 Rule A: Check if Active
      if (data['isActive'] == false) {
        throw "This coupon is currently deactivated.";
      }

      // 🛑 Rule B: Check Expiry Date
      if (data['expiryDate'] != null) {
        DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
        if (expiry.isBefore(DateTime.now())) {
          throw "This coupon has expired.";
        }
      }

      // 🛑 Rule C: Target User Validation (Crucial for Smart Notifications)
      if (data['validForUsers'] != null && data['validForUsers'] is List) {
        List<dynamic> validUsers = data['validForUsers'];
        if (validUsers.isNotEmpty && !validUsers.contains(user.uid)) {
          throw "This special offer is locked to a different customer.";
        }
      }

      // 🛑 Rule D: Branch Restrictions
      if (data['branchCode'] != null &&
          data['branchCode'] != 'UNKNOWN' &&
          data['branchCode'] != 'ALL') {
        if (data['branchCode'] != UserSession.storeId) {
          throw "This coupon is only valid for a different branch.";
        }
      }

      // ✅ SUCCESS: Apply dynamic discount to Cart
      _appliedPromoCode = code;
      _promoDiscountPercent =
          double.tryParse(data['discountPercent']?.toString() ?? '0') ?? 0.0;
      _isWinbackApplied = false;
      notifyListeners();
    } catch (e) {
      if (e is String) rethrow;
      throw "Failed to validate promo code. Please try again.";
    }
  }

  void removePromoCode() {
    _appliedPromoCode = null;
    _promoDiscountPercent = 0.0;
    _isWinbackApplied = false;
    notifyListeners();
  }

  // ─── VALIDATE ─────────────────────────────────────────────────────────────
  Future<List<String>> validateCart() async {
    // 🚀 FIX: Memory Drop recovery before validation fails
    if (UserSession.tenantId.isEmpty || UserSession.storeId.isEmpty) {
      String savedTid = _prefs?.getString('saved_tenantId') ?? '';
      String savedSid = _prefs?.getString('saved_storeId') ?? '';

      if (savedTid.isNotEmpty && savedSid.isNotEmpty) {
        UserSession.tenantId = savedTid;
        UserSession.storeId = savedSid;
        UserSession.branchCode = savedSid; // Ensure branch code syncs too
      } else {
        debugPrint("🚨 Validation Bypassed: Session completely empty.");
        return [];
      }
    }

    final r = await _validatorService.validate(_rawItems, _isCorrectionMode);
    List<String> warnings = r['warnings'];
    List<String> toRemove = r['itemsToRemove'];
    Map<String, CartItem> updates = r['updates'];
    bool changed = toRemove.isNotEmpty || updates.isNotEmpty;
    for (String c in toRemove) {
      _rawItems.remove(c);
    }
    updates.forEach((bc, u) => _rawItems[bc] = u);
    await fetchAndApplyOffers();
    warnings.removeWhere((w) => w.contains("Rate/Offer updated"));
    if (changed) _saveCart();
    notifyListeners();
    return warnings;
  }

  // ─── CORRECTION MODE ──────────────────────────────────────────────────────
  Future<void> loadOrderForCorrection(
      String orderId, List<dynamic> previousItems) async {
    _rawItems = {};
    _items = {};
    _correctionOriginalQty = {};
    _isCorrectionMode = true;
    _correctionOrderId = orderId;
    for (var item in previousItems) {
      String bc = item['barcode'] ?? 'UNKNOWN';
      int qty = int.tryParse(
              item['qty']?.toString() ?? item['quantity']?.toString() ?? '1') ??
          1;
      double price = double.tryParse(item['originalPrice']?.toString() ??
              item['price']?.toString() ??
              '0') ??
          0.0;
      _rawItems[bc] = CartItem(
          barcode: bc,
          name: item['name'] ?? 'Item',
          originalPrice: price,
          gst: 0.0,
          weight: 0.0,
          quantity: qty);
      _items[bc] = _rawItems[bc]!;
      _correctionOriginalQty[bc] = qty;
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

  // ─── PERSISTENCE ──────────────────────────────────────────────────────────
  Future<void> _checkMidnightReset(String uid) async {
    if (_prefs == null) return;
    int? lastUpdate = _prefs!.getInt('cart_last_update_$uid');
    int now = DateTime.now().millisecondsSinceEpoch;

    // 3 hours TTL check
    if (lastUpdate != null && (now - lastUpdate) > 3 * 60 * 60 * 1000) {
      String? pending = await OrderService().getActiveOrderId(uid);
      if (pending == null) {
        await clearCart();
      }
    }
  }

  Future<void> _loadCart(String uid) async {
    if (_prefs == null) return;
    final key = 'cart_$uid';
    final String? localJson = _prefs!.getString(key);
    if (localJson != null) _processCartJson(localJson);
    try {
      DocumentSnapshot snap = await _db.collection('carts').doc(uid).get();
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>;
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
              _isCorrectionMode = false;
              _correctionOrderId = null;
              _correctionOriginalQty = {};
              cloudItems = [];
              _rawItems = {};
              _items = {};
              await _clearStorage(uid);
            }
          }
        }
        if (cloudItems.isNotEmpty) {
          String cj = jsonEncode(cloudItems);
          _processCartJson(cj);
          await _prefs!.setString(key, cj);
        }
      }
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
    }
    notifyListeners();
  }

  void _processCartJson(String rawJson) {
    try {
      List<dynamic> decodedList = jsonDecode(rawJson);
      _rawItems = {};

      for (var itemJson in decodedList) {
        String bc = itemJson['barcode'] ?? '';
        if (bc.isEmpty || bc.contains('_FREE') || bc.contains('_OVERFLOW')) {
          continue;
        }

        CartItem item = CartItem.fromJson(itemJson);
        _rawItems[item.barcode] = item;
      }

      _items = Map.from(_rawItems);
    } catch (e) {
      debugPrint("Cart Parse Error: $e");
    }
  }

  Future<void> _saveCart() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _prefs == null) return;

    List<Map<String, dynamic>> saveableList =
        _rawItems.values.map((i) => i.toJson()).toList();

    String rawJson = jsonEncode(saveableList);
    await _prefs!.setString('cart_${user.uid}', rawJson);
    await _prefs!.setInt(
        'cart_last_update_${user.uid}', DateTime.now().millisecondsSinceEpoch);

    try {
      _db.collection('carts').doc(user.uid).set({
        'items': saveableList,
        'isCorrectionMode': _isCorrectionMode,
        'correctionOrderId': _correctionOrderId,
        'correctionOriginalQty': _correctionOriginalQty,
        'lastUpdated': FieldValue.serverTimestamp(),
        // 🚀 FIX: Save safely even if static memory drops in background
        'tenantId': UserSession.tenantId.isNotEmpty
            ? UserSession.tenantId
            : (_prefs?.getString('saved_tenantId') ?? ''),
        'branchCode': UserSession.storeId.isNotEmpty
            ? UserSession.storeId
            : (_prefs?.getString('saved_storeId') ?? ''),
      });
    } catch (e) {
      debugPrint("Cart Save Error: $e");
    }
  }
}
