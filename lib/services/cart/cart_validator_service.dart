import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cart_item.dart';
import '../../utils/user_session.dart';

class CartValidatorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> _getSafeProduct(String baseBarcode) async {
    try {
      // 🚀 FIX: Match Admin Panel Exactly. No aggressive regex stripping!
      String cleanTarget = baseBarcode.trim();
      String docId =
          '${UserSession.tenantId}_${UserSession.storeId}_$cleanTarget';

      final doc = await _db.collection('products').doc(docId).get();
      if (doc.exists && doc.data() != null) return doc.data();
      return null;
    } catch (e) {
      return {'_error': true}; // Never delete on network error
    }
  }

  Future<Map<String, dynamic>> validate(
      Map<String, CartItem> currentItems, bool isCorrectionMode) async {
    List<String> warnings = [];
    List<String> itemsToRemove = [];
    Map<String, CartItem> updates = {};

    if (isCorrectionMode) {
      return {
        'warnings': warnings,
        'itemsToRemove': itemsToRemove,
        'updates': updates
      };
    }

    // 🚀 FIX: Ghost Delete Bug - Do not delete items if session is not loaded yet
    if (UserSession.tenantId.isEmpty || UserSession.storeId.isEmpty) {
      return {
        'warnings': warnings,
        'itemsToRemove': itemsToRemove,
        'updates': updates
      };
    }

    Map<String, int> baseQtyMap = {};
    for (var key in currentItems.keys) {
      String baseBarcode =
          key.replaceAll('_OVERFLOW', '').replaceAll('_FREE', '');
      baseQtyMap[baseBarcode] =
          (baseQtyMap[baseBarcode] ?? 0) + currentItems[key]!.quantity;
    }

    for (String barcodeKey in currentItems.keys) {
      final item = currentItems[barcodeKey]!;
      String baseBarcode =
          barcodeKey.replaceAll('_OVERFLOW', '').replaceAll('_FREE', '');

      try {
        final pData = await _getSafeProduct(baseBarcode);

        // 🚀 FIX: Agar Web Refresh ke delay ki wajah se error aaya hai, toh item skip karo, udao mat!
        if (pData != null && pData['_error'] == true) {
          continue;
        }

        if (pData == null) {
          itemsToRemove.add(barcodeKey);
          warnings.add("🗑️ ${item.name} is no longer available.");
          continue;
        }

        if (pData['isBlocked'] == true) {
          itemsToRemove.add(barcodeKey);
          warnings.add("🚫 ${item.name} removed (Out of Stock / Blocked).");
          continue;
        }

        if (pData['expiryDate'] != null) {
          final expiryDate = (pData['expiryDate'] as Timestamp).toDate();
          if (expiryDate.isBefore(DateTime.now())) {
            itemsToRemove.add(barcodeKey);
            warnings.add("🚫 ${item.name} removed (Expired).");
            continue;
          }
        }

        // 🚀 SAAS LOGIC: Service items bypass inventory limits
        bool isService =
            pData['itemType']?.toString().toUpperCase() == 'SERVICE';

        // 🚀 OPTIMISTIC CHECKOUT: Only check Physical Stock, Ignore Reserved
        int liveStock = pData['physicalStock'] ?? 0;

        // Prevent Negative Quantities
        if (liveStock < 0) liveStock = 0;

        int totalRequested = baseQtyMap[baseBarcode] ?? 0;

        // Only enforce limits if it is NOT a service
        if (!isService && totalRequested > liveStock) {
          if (barcodeKey != baseBarcode) {
            itemsToRemove.add(barcodeKey);
            continue;
          } else {
            updates[baseBarcode] = item.copyWith(quantity: liveStock);
            warnings.add(
                "⚠️ ${item.name} quantity reduced to $liveStock due to store limits.");
            continue;
          }
        }

        double liveOriginalPrice =
            double.tryParse(pData['price']?.toString() ?? '0') ??
                item.originalPrice;

        updates[barcodeKey] = item.copyWith(
          name: pData['name'] ?? item.name,
          originalPrice: liveOriginalPrice,
          gst: double.tryParse(
                  pData['gst']?.toString().replaceAll(RegExp(r'[^0-9.]'), '') ??
                      '0') ??
              item.gst,
          weight: double.tryParse(pData['weight']
                      ?.toString()
                      .replaceAll(RegExp(r'[^0-9.]'), '') ??
                  '0') ??
              item.weight,
        );
      } catch (e) {
        // Suppress print
      }
    }

    return {
      'warnings': warnings,
      'itemsToRemove': itemsToRemove,
      'updates': updates,
    };
  }
}
