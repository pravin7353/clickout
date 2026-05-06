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

  // 🚀 IDEMPOTENCY KEY: Tracks active pending order to prevent duplicates
  String? _currentOrderId;
  String? get currentOrderId => _currentOrderId;

  void setCurrentOrderId(String id) {
    _currentOrderId = id;
    _saveCart();
  }

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
      // 🚀 SAAS FIX: Memory Drop recovery for Tenant ID
      String tId = UserSession.tenantId.isNotEmpty
          ? UserSession.tenantId
          : (_prefs?.getString('saved_tenantId') ?? '');

      if (tId.isEmpty) return; // Session completely dead

      final snap = await _db
          .collection('products')
          .where('clearanceActive', isEqualTo: true)
          .where('tenantId', isEqualTo: tId)
          .get();

      _activeOffers = snap.docs.map((doc) => doc.data()).toList();
      _applyOffersLocally();
    } catch (e) {
      debugPrint("Offer Fetch Error: $e");
    }
  }

  void _applyOffersLocally() {
    if (_rawItems.isEmpty) {
      _items = {};
      notifyListeners(); // 🚀 FIX: Empty cart par bhi update trigger hoga
      return;
    }

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
    notifyListeners(); // 🚀 FIX: Offer calculate hote hi UI instantly notify hoga!
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
      // 🚀 FIX: Allow spaces and '+' for Service items like 'HAIR CUT + BEARD'
      String target = barcode.replaceAll(RegExp(r'[^0-9a-zA-Z\-_+ ]'), '');

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

    // 🚀 FIX: Turned off forceServer to make adding 10x faster.
    final pData = await _getSafeProduct(barcode, forceServer: false);
    if (pData == null) throw "Item not found in database!";
    if (pData['isBlocked'] == true) {
      throw "🚫 DEAD STOCK: Item is currently blocked.";
    }

    // 🚀 FIX: Smart Expiry Checker (Handles both Timestamp and "MM/YYYY" String)
    if (pData['expiryDate'] != null &&
        pData['expiryDate'].toString().isNotEmpty) {
      DateTime? expDate;
      var rawExp = pData['expiryDate'];

      if (rawExp is Timestamp) {
        expDate = rawExp.toDate();
      } else if (rawExp is String) {
        try {
          List<String> parts = rawExp.split('/');
          if (parts.length == 2) {
            int month = int.parse(parts[0]);
            int year = int.parse(parts[1]);
            if (year < 100) year += 2000; // Handle YY to YYYY
            // Set to the last day of the expiry month
            expDate = DateTime(year, month + 1, 0);
          }
        } catch (_) {}
      }

      if (expDate != null && expDate.isBefore(DateTime.now())) {
        throw "🚫 EXPIRED ITEM: This item is past its expiry date.";
      }
    }

    // 🚀 SAAS LOGIC: Check if it's a Virtual Service (No stock limit)
    bool isService = pData['itemType']?.toString().toUpperCase() == 'SERVICE';

    // 🚀 OPTIMISTIC CHECKOUT: Only check Physical Stock for Products
    int physicalStock = pData['physicalStock'] ?? 0;

    if (!isService && physicalStock <= 0) throw "Item Out of Stock!";

    // 🚀 MISSING VARIABLE FIXED HERE
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

    _applyOffersLocally(); // 🚀 FIX: Instant Add, No internet loading required!
    notifyListeners();
    _saveCart();
  }

  // ─── INCREMENT ────────────────────────────────────────────────────────────
  Future<void> increment(String barcode) async {
    if (_isCorrectionMode) throw "Cart locked.";
    if (barcode.endsWith('_FREE')) throw "Modify the main product.";

    final String base =
        barcode.replaceAll('_OVERFLOW', '').replaceAll('_FREE', '');
    final existing = _rawItems[base];
    if (existing == null) return;

    final pData = await _getSafeProduct(base, forceServer: false);

    // 🚀 FIX: Network delay ya Service string mismatch hone par item cart se nahi udega!
    if (pData == null) {
      _rawItems[base] = existing.copyWith(quantity: existing.quantity + 1);
      _applyOffersLocally(); // 🚀 FIX: Slowness Khatam! Only local math.
      notifyListeners();
      _saveCart();
      return;
    }

    if (pData['isBlocked'] == true) {
      throw "Item was just blocked/removed by Admin!";
    }

    bool isService = pData['itemType']?.toString().toUpperCase() == 'SERVICE';
    int physicalStock = pData['physicalStock'] ?? 0;
    int newQty = existing.quantity + 1;

    if (!isService && newQty > physicalStock) {
      throw "Stock limit reached! Only $physicalStock available.";
    }

    _rawItems[base] = existing.copyWith(quantity: newQty);
    _applyOffersLocally(); // 🚀 FIX: Slowness Khatam! Only local math.
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

    final existing = _rawItems[base];
    if (existing != null) {
      _rawItems[base] = existing.copyWith(quantity: currentQty - 1);
      _applyOffersLocally(); // ONLY LOCAL
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

  // 🚀 MISSING FUNCTION FIXED HERE (Ye galti se udd gaya tha)
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
    _currentOrderId = null; // 🚀 FIX: Reset Idempotency Key
    _clearCorrectionState();
    notifyListeners();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) _clearStorage(user.uid);
  }

  // 🔒 BACKEND LOCK: Added 'force' parameter
  Future<void> clearCart({bool force = false}) async {
    if (_isCorrectionMode && !force)
      return; // Silent block! User kuch nahi kar payega.

    _rawItems = {};
    _items = {};
    _currentOrderId = null; // 🚀 FIX: Reset Idempotency Key
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
  String? _vipOfferDocId;

  Future<void> applyPromoCode(String code) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw "Please login to apply offers.";

    final String upperCode = code.toUpperCase();

    // 1. OLD HARDCODED FALLBACK
    if (upperCode == "COMEBACK20") {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()?['winbackActive'] == true) {
        _appliedPromoCode = "COMEBACK20";
        _promoDiscountPercent = 20.0;
        _isWinbackApplied = true;
        _vipOfferDocId = null;
        notifyListeners();
        return;
      }
    }

    try {
      // 🚀 2. VIP GROWTH RADAR ENGINE (Security Check: Match user.uid strictly)
      final vipOfferSnap = await _db
          .collection('notifications')
          .where('targetUserId',
              isEqualTo: user.uid) // 🔒 Yaha Security Check Lag Gaya
          .where('status',
              isEqualTo: 'PENDING') // Sirf unused offers check karega
          .get();

      for (var doc in vipOfferSnap.docs) {
        final data = doc.data();
        String dbCode = (data['couponCode'] ?? '').toString().toUpperCase();

        if (dbCode == upperCode) {
          // Security Check: Expiry Date
          if (data['createdAt'] != null) {
            DateTime createdAt = (data['createdAt'] as Timestamp).toDate();
            int expiryDays = data['expiryDays'] ?? 3;
            if (DateTime.now()
                .isAfter(createdAt.add(Duration(days: expiryDays)))) {
              await _db
                  .collection('notifications')
                  .doc(doc.id)
                  .update({'status': 'EXPIRED'});
              throw "This VIP offer has expired.";
            }
          }

          // ✅ SUCCESS: Apply VIP Discount
          _appliedPromoCode = upperCode;
          _promoDiscountPercent =
              double.tryParse(data['discountPercent']?.toString() ?? '0') ??
                  0.0;
          _isWinbackApplied = false;
          _vipOfferDocId = doc.id;
          notifyListeners();
          return;
        }
      }

      // 🚀 3. DYNAMIC COUPON ENGINE FALLBACK (General Store Coupons)
      String couponDocId = '${UserSession.tenantId}_$upperCode';
      DocumentSnapshot couponDoc =
          await _db.collection('coupons').doc(couponDocId).get();

      if (!couponDoc.exists) {
        throw "Invalid Promo Code.";
      }

      final data = couponDoc.data() as Map<String, dynamic>;

      if (data['isActive'] == false)
        throw "This coupon is currently deactivated.";

      if (data['expiryDate'] != null) {
        DateTime expiry = (data['expiryDate'] as Timestamp).toDate();
        if (expiry.isBefore(DateTime.now())) throw "This coupon has expired.";
      }

      if (data['validForUsers'] != null && data['validForUsers'] is List) {
        List<dynamic> validUsers = data['validForUsers'];
        if (validUsers.isNotEmpty && !validUsers.contains(user.uid)) {
          throw "This special offer is locked to a different customer.";
        }
      }

      if (data['branchCode'] != null &&
          data['branchCode'] != 'UNKNOWN' &&
          data['branchCode'] != 'ALL') {
        if (data['branchCode'] != UserSession.storeId) {
          throw "This coupon is only valid for a different branch.";
        }
      }

      // ✅ SUCCESS: Apply Global Store Discount
      _appliedPromoCode = upperCode;
      _promoDiscountPercent =
          double.tryParse(data['discountPercent']?.toString() ?? '0') ?? 0.0;
      _isWinbackApplied = false;
      _vipOfferDocId = null;
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
    _vipOfferDocId = null;
    notifyListeners();
  }

  // 🚀 CALL THIS AFTER SUCCESSFUL PAYMENT (In order_service.dart) TO MARK CODE AS USED
  Future<void> redeemAppliedVIPOffer() async {
    if (_vipOfferDocId != null) {
      await _db.collection('notifications').doc(_vipOfferDocId).update({
        'status': 'USED',
        'usedAt': FieldValue.serverTimestamp(),
      });
      _vipOfferDocId = null;
    }
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
        _currentOrderId =
            data['currentOrderId']; // 🚀 FIX: Load Active Pending Order ID
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
          // Only trust Firestore if it has MORE items than local,
          // OR if local is empty. This protects against stale cloud data
          // overwriting a more recent local state after a fast refresh.
          int cloudCount = cloudItems.length;
          int localCount = _rawItems.length;

          if (cloudCount >= localCount) {
            String cj = jsonEncode(cloudItems);
            _processCartJson(cj);
            await _prefs!.setString(key, cj);
          }
          // else: local is newer/more complete — keep it, re-upload to cloud
          else {
            await _saveCart();
          }
        }
        // Cloud doc exists but items is empty — local data is the truth.
        // Re-upload local to recover from a failed/incomplete save.
        else if (_rawItems.isNotEmpty) {
          await _saveCart();
        }
      }
    } catch (e) {
      debugPrint("Cloud Sync Error: $e");
      // On any Firestore error, local data is our safety net — keep it.
    }

    // If Firestore had no document but local has items (e.g. first load
    // after a failed previous save), push local items to cloud now.
    final user2 = FirebaseAuth.instance.currentUser;
    if (user2 != null && _rawItems.isNotEmpty) {
      final snap2 = await _db
          .collection('carts')
          .doc(user2.uid)
          .get()
          .catchError((_) => null as DocumentSnapshot);
      if (!snap2.exists) {
        await _saveCart();
      }
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

    // 🚀 FIX: Agar cart empty hai, toh DB aur Local storage se poora uda do (No Ghost Items)
    if (_rawItems.isEmpty) {
      await _clearStorage(user.uid);
      return;
    }

    List<Map<String, dynamic>> saveableList =
        _rawItems.values.map((i) => i.toJson()).toList();

    String rawJson = jsonEncode(saveableList);
    await _prefs!.setString('cart_${user.uid}', rawJson);
    await _prefs!.setInt(
        'cart_last_update_${user.uid}', DateTime.now().millisecondsSinceEpoch);

    try {
      await _db.collection('carts').doc(user.uid).set({
        'items': saveableList,
        'isCorrectionMode': _isCorrectionMode,
        'correctionOrderId': _correctionOrderId,
        'currentOrderId':
            _currentOrderId, // 🚀 FIX: Save Active Pending Order ID
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
