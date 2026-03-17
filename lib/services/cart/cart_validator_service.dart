import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/cart_item.dart';

class CartValidatorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

    for (String barcode in currentItems.keys) {
      final item = currentItems[barcode]!;
      try {
        final snap = await _db
            .collection('products')
            .where('barcode', isEqualTo: barcode)
            .limit(1)
            .get();

        // 1. ITEM DELETED FROM DB
        if (snap.docs.isEmpty) {
          itemsToRemove.add(barcode);
          warnings.add("🗑️ ${item.name} is no longer available.");
          continue;
        }

        final pData = snap.docs.first.data();

        // 🛑 2. DEAD STOCK DETECTED
        if (pData['isBlocked'] == true) {
          itemsToRemove.add(barcode);
          warnings.add("🚫 ${item.name} removed (Out of Stock / Blocked).");
          continue;
        }

        // 🛑 2.1 EXPIRED ITEM DETECTED
        if (pData['expiryDate'] != null) {
          final expiryDate = (pData['expiryDate'] as Timestamp).toDate();
          if (expiryDate.isBefore(DateTime.now())) {
            itemsToRemove.add(barcode);
            warnings.add("🚫 ${item.name} removed (Expired).");
            continue;
          }
        }

        // 🎁 3. LIVE OFFER EXTRACTION
        bool cActive = pData['clearanceActive'] == true;
        String cType = pData['clearanceType'] ?? '';
        int bQty = pData['buyQty'] ?? 1;
        int fQty = pData['freeQty'] ?? 0;
        double cVal = double.tryParse(pData['clearanceValue']?.toString() ??
                pData['flatDiscount']?.toString() ??
                '0') ??
            0.0;
        String fId = pData['freeProductId'] ?? '';
        String fName = pData['freeProductName'] ?? '';
        double cPrice =
            double.tryParse(pData['comboPrice']?.toString() ?? '0') ?? 0.0;

        double liveOriginalPrice =
            double.tryParse(pData['price']?.toString() ?? '0') ??
                item.originalPrice;
        int liveStock = pData['physicalStock'] ?? pData['stock'] ?? 0;

        // 🧮 4. STOCK LIMIT MATHEMATICS
        int finalQty = item.quantity;
        if (finalQty > liveStock) {
          finalQty = liveStock;
          if (finalQty <= 0) {
            itemsToRemove.add(barcode);
            warnings.add("📦 ${item.name} went out of stock!");
            continue;
          } else {
            warnings.add(
                "⚠️ ${item.name} quantity reduced to $finalQty due to store limits.");
          }
        }

        // 👻 5. CROSS-PRODUCT VALIDATION (THE GHOST KILLER)
        // Agar Tata Salt par offer hai, check karo Mushroom zinda hai ya nahi
        if (cActive && cType == 'BUY_X_GET_Y') {
          if (fId.isNotEmpty) {
            final ySnap = await _db
                .collection('products')
                .where('barcode', isEqualTo: fId)
                .limit(1)
                .get();

            if (ySnap.docs.isEmpty ||
                ySnap.docs.first.data()['isBlocked'] == true ||
                (ySnap.docs.first.data()['physicalStock'] ?? 0) <= 0 ||
                (ySnap.docs.first.data()['expiryDate'] != null &&
                    (ySnap.docs.first.data()['expiryDate'] as Timestamp)
                        .toDate()
                        .isBefore(DateTime.now()))) {
              cActive = false;
              cType =
                  'DEAD_OFFER'; // Ye engine ko signal dega offer cancel karne ka
              warnings.add(
                  "⚠️ Offer on ${item.name} removed because free item is unavailable.");
            }
          }
        }

        // 🔄 6. FORCE OVERWRITE CART WITH LIVE DATA
        updates[barcode] = CartItem(
          barcode: barcode,
          name: pData['name'] ?? item.name,
          originalPrice: liveOriginalPrice,
          gst: double.tryParse(pData['gst']?.toString() ?? '0') ?? item.gst,
          weight: double.tryParse(pData['weight']?.toString() ?? '0') ??
              item.weight,
          quantity: finalQty,
          clearanceActive: cActive,
          clearanceType: cType,
          buyQty: bQty,
          freeQty: fQty,
          clearanceValue: cVal,
          freeProductId: fId,
          freeProductName: fName,
          comboPrice: cPrice,
        );
      } catch (e) {
        print("🚨 Validation error for $barcode: $e");
      }
    }

    return {
      'warnings': warnings,
      'itemsToRemove': itemsToRemove,
      'updates': updates,
    };
  }
}
