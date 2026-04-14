import '../../models/cart_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfferCalculationResult {
  final Map<String, CartItem> updatedCartItems;
  final double totalAppliedDiscount;
  final double newGrandTotal;
  final int totalFreeItems;
  OfferCalculationResult({
    required this.updatedCartItems,
    required this.totalAppliedDiscount,
    required this.newGrandTotal,
    required this.totalFreeItems,
  });
}

class OfferEngineService {
  static double safeParse(dynamic v) {
    if (v == null) return 0;
    return double.tryParse(v.toString().replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0;
  }

  static String cleanBarcode(dynamic b) {
    if (b == null) return '';
    return b.toString().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
  }

  // Collapse _FREE/_OVERFLOW split keys → base items with total qty.
  // Called by CartService before every engine run and before saving.
  static Map<String, CartItem> collapseToBase(Map<String, CartItem> items) {
    final Map<String, CartItem> out = {};
    items.forEach((key, item) {
      final String base =
          key.replaceAll('_FREE', '').replaceAll('_OVERFLOW', '');
      if (out.containsKey(base)) {
        out[base] =
            out[base]!.copyWith(quantity: out[base]!.quantity + item.quantity);
      } else {
        out[base] = item.copyWith(
          quantity: item.quantity,
          isOverflow: false,
          clearanceActive: false,
          clearanceType: '',
          clearanceValue: 0,
          freeQtyGiven: 0,
        );
      }
    });
    return out;
  }

  static Map<String, dynamic> normalizeOffer(Map<String, dynamic> raw) {
    final String t = (raw['clearanceType'] ?? '').toString().toUpperCase();
    switch (t) {
      case 'BOGO':
        return {...raw, 'buyQty': 1, 'freeQty': 1};
      case 'BUY_X_GET_Y':
        int bq = safeParse(raw['buyQty']).toInt();
        int fq = safeParse(raw['freeQty']).toInt();
        return {...raw, 'buyQty': bq > 0 ? bq : 1, 'freeQty': fq > 0 ? fq : 1};
      case 'BUY_X_GET_Y_CROSS':
        int bq = safeParse(raw['buyQty']).toInt();
        int fq = safeParse(raw['freeQty']).toInt();
        return {
          ...raw,
          'buyQty': bq > 0 ? bq : 1,
          'freeQty': fq > 0 ? fq : 1,
          'targetProductId': cleanBarcode(raw['targetProductId']),
        };
      case 'PERCENTAGE':
        return {...raw, 'discount': safeParse(raw['discountPercent'])};
      case 'CROSS_PRODUCT':
        return {
          ...raw,
          'discount': safeParse(raw['discountPercent']),
          'targetProductId': cleanBarcode(raw['targetProductId'])
        };
      case 'FLAT_AMOUNT':
        return {...raw, 'discount': safeParse(raw['discountAmount'])};
      case 'TIERED_QTY':
        return {
          ...raw,
          'minQty': safeParse(raw['minQty']).toInt(),
          'discount': safeParse(raw['discountPercent'])
        };
      case 'BUNDLE_PRICE':
        return {
          ...raw,
          'bundleQty': safeParse(raw['bundleQty']).toInt(),
          'bundlePrice': safeParse(raw['bundlePrice'])
        };
      case 'FLASH_SALE':
        return {
          ...raw,
          'discount': safeParse(raw['discountPercent']),
          'expiresAt': raw['expiresAt']
        };
      default:
        return raw;
    }
  }

  static OfferCalculationResult applyAllOffers({
    required Map<String, CartItem> cartItems,
    required List<Map<String, dynamic>> activeOffers,
    required Map<String, int> liveStockLogs,
  }) {
    // DEFENSIVE COLLAPSE: engine must only ever see base barcodes
    final Map<String, CartItem> safe = collapseToBase(cartItems);
    final Map<String, CartItem> result = {};
    double totalDiscount = 0.0;
    double grandTotal = 0.0;
    int freeCount = 0;
    final offers = activeOffers.map(normalizeOffer).toList();

    void writeLine({
      required String key,
      required CartItem item,
      required bool active,
      required String type,
      required double unitPrice,
      required int bQty,
      required int fQty,
      required String targetId,
      bool overflow = false,
    }) {
      final double fp = unitPrice < 0 ? 0 : unitPrice;
      totalDiscount += (item.originalPrice - fp) * item.quantity;
      grandTotal += fp * item.quantity;
      result[key] = item.copyWith(
        clearanceActive: active,
        clearanceType: type,
        clearanceValue: fp,
        buyQty: bQty,
        freeQty: fQty,
        freeProductId: targetId,
        isOverflow: overflow,
        freeQtyGiven: 0,
      );
    }

    safe.forEach((rawKey, original) {
      // CRITICAL FIX: skip any split key that slipped through
      if (rawKey.endsWith('_FREE') || rawKey.endsWith('_OVERFLOW')) return;

      final String bc = cleanBarcode(rawKey);
      final int qty = original.quantity;
      final int stock = liveStockLogs[bc] ?? qty;
      final double mrp = original.originalPrice;

      final trigger = offers.firstWhere(
        (o) =>
            (cleanBarcode(o['barcode']) == bc ||
                cleanBarcode(o['productId']) == bc) &&
            o['clearanceActive'] == true,
        orElse: () => {},
      );
      final crossTarget = offers.firstWhere(
        (o) =>
            cleanBarcode(o['targetProductId']) == bc &&
            o['clearanceActive'] == true,
        orElse: () => {},
      );

      if (trigger.isNotEmpty) {
        final String ot =
            (trigger['clearanceType'] ?? '').toString().toUpperCase();

        // ── NEW: CROSS OFFER TRIGGER IDENTIFICATION ──────────────
        // Trigger item ko full MRP pe rakhenge, par active: true karenge
        // taaki UI me customer ko offer badge (e.g. "Buy 1 get AirPods free") dikhe.
        if (ot == 'BUY_X_GET_Y_CROSS' || ot == 'CROSS_PRODUCT') {
          writeLine(
              key: bc,
              item: original,
              active: true,
              type: ot,
              unitPrice: mrp,
              bQty: (trigger['buyQty'] as int?) ?? 1,
              fQty: (trigger['freeQty'] as int?) ?? 0,
              targetId: cleanBarcode(trigger['targetProductId']));
          return;
        }

        // ── BOGO / BUY_X_GET_Y: The correct retail cycle math ──────────────
        if (ot == 'BOGO' || ot == 'BUY_X_GET_Y') {
          final int bQty = (trigger['buyQty'] as int?) ?? 1;
          final int fQty = (trigger['freeQty'] as int?) ?? 1;

          if (bQty <= 0) return;

          // How many times did they hit the buy threshold?
          final int eligibleCycles = qty ~/ bQty;

          // Calculate the theoretical free items they earned
          int theoreticalFree = eligibleCycles * fQty;

          // CRITICAL STOCK CHECK: Can we actually give them this many free items?
          // The total items needed = paid (qty) + free
          int maxFreeAllowedByStock = stock - qty;
          if (maxFreeAllowedByStock < 0) maxFreeAllowedByStock = 0;

          // Actual free items is the lesser of what they earned vs what's in stock
          final int actualFreeEarned = theoreticalFree > maxFreeAllowedByStock
              ? maxFreeAllowedByStock
              : theoreticalFree;

          // Write the paid items
          writeLine(
              key: bc,
              item: original.copyWith(quantity: qty),
              active: actualFreeEarned > 0, // Only active if they got something
              type: ot,
              unitPrice: mrp,
              bQty: bQty,
              fQty: fQty,
              targetId: '');

          // Automatically append the free items
          if (actualFreeEarned > 0) {
            freeCount += actualFreeEarned;
            writeLine(
                key: '${bc}_FREE',
                item: original.copyWith(quantity: actualFreeEarned),
                active: true,
                type: 'FREE_ITEM',
                unitPrice: 0.0,
                bQty: bQty,
                fQty: fQty,
                targetId: '');
          }
          return;
        }

        if (ot == 'TIERED_QTY') {
          final int minQ = (trigger['minQty'] as int?) ?? 1;
          final double disc = safeParse(trigger['discount']);
          final bool met = qty >= minQ;
          writeLine(
              key: bc,
              item: original,
              active: met,
              type: ot,
              unitPrice: met ? mrp * (1 - disc / 100) : mrp,
              bQty: minQ,
              fQty: 0,
              targetId: '');
          return;
        }

        if (ot == 'FLASH_SALE') {
          final dynamic exp = trigger['expiresAt'];
          final bool expired =
              exp is Timestamp && DateTime.now().isAfter(exp.toDate());
          final double disc = safeParse(trigger['discount']);
          writeLine(
              key: bc,
              item: original,
              active: !expired,
              type: ot,
              unitPrice: expired ? mrp : mrp * (1 - disc / 100),
              bQty: 1,
              fQty: 0,
              targetId: '');
          return;
        }

        if (ot == 'BUNDLE_PRICE') {
          final int bunQty = (trigger['bundleQty'] as int?) ?? 1;
          final double bunPrice = safeParse(trigger['bundlePrice']);
          final int fullB = qty ~/ bunQty;
          final int rem2 = qty % bunQty;
          final double total = (fullB * bunPrice) + (rem2 * mrp);
          writeLine(
              key: bc,
              item: original,
              active: fullB > 0,
              type: ot,
              unitPrice: qty > 0 ? total / qty : mrp,
              bQty: bunQty,
              fQty: 0,
              targetId: '');
          return;
        }

        if (ot == 'PERCENTAGE') {
          writeLine(
              key: bc,
              item: original,
              active: true,
              type: ot,
              unitPrice: mrp * (1 - safeParse(trigger['discount']) / 100),
              bQty: 1,
              fQty: 0,
              targetId: '');
          return;
        }

        if (ot == 'FLAT_AMOUNT') {
          writeLine(
              key: bc,
              item: original,
              active: true,
              type: ot,
              unitPrice: mrp - safeParse(trigger['discount']),
              bQty: 1,
              fQty: 0,
              targetId: '');
          return;
        }
      }

      if (crossTarget.isNotEmpty) {
        final String ct =
            (crossTarget['clearanceType'] ?? '').toString().toUpperCase();
        final String trigId = cleanBarcode(
            crossTarget['barcode'] ?? crossTarget['productId'] ?? '');
        final trigEntry = safe.entries
            .where((e) => cleanBarcode(e.key) == trigId)
            .firstOrNull;

        if (trigEntry != null) {
          final int trigQty = trigEntry.value.quantity;

          // ── BUY X GET Y (DIFFERENT ITEM) ─────────────────────────────────
          if (ct == 'BUY_X_GET_Y_CROSS') {
            final int cbQty = (crossTarget['buyQty'] as int?) ?? 1;
            final int cfQty = (crossTarget['freeQty'] as int?) ?? 1;

            // Calculate free items earned from trigger quantity
            final int earnedFree = cbQty > 0 ? (trigQty ~/ cbQty) * cfQty : 0;

            // Limit by available physical stock
            final int maxFreeAllowed = earnedFree > stock ? stock : earnedFree;

            // We can only give free what they actually added to the cart
            final int freeToGive = maxFreeAllowed > qty ? qty : maxFreeAllowed;
            final int paidCount = qty - freeToGive;

            if (freeToGive > 0) {
              freeCount += freeToGive;
              writeLine(
                  key: '${bc}_FREE',
                  item: original.copyWith(quantity: freeToGive),
                  active: true,
                  type: 'FREE_ITEM',
                  unitPrice: 0.0,
                  bQty: cbQty,
                  fQty: cfQty,
                  targetId: trigId);
            }
            if (paidCount > 0) {
              writeLine(
                  key: freeToGive > 0 ? '${bc}_OVERFLOW' : bc,
                  item: original.copyWith(quantity: paidCount),
                  active: false,
                  type: '',
                  unitPrice: mrp,
                  bQty: 1,
                  fQty: 0,
                  targetId: '',
                  overflow: freeToGive > 0);
            }
            return;
          }

          // ── CROSS PRODUCT (% OFF DIFFERENT ITEM) ─────────────────────────
          if (ct == 'CROSS_PRODUCT') {
            final double disc = safeParse(crossTarget['discount']);

            // 🚀 Enterprise Rule: 1 Trigger Item unlocks discount for 1 Target Item
            // (Prevents a user from adding 1 iPhone and getting discount on 50 AirPods)
            int discountedQty = qty > trigQty ? trigQty : qty;
            int normalQty = qty - discountedQty;

            if (discountedQty > 0) {
              writeLine(
                  key: bc,
                  item: original.copyWith(quantity: discountedQty),
                  active: true,
                  type: ct,
                  unitPrice: mrp * (1 - disc / 100),
                  bQty: 1,
                  fQty: 0,
                  targetId: trigId);
            }
            if (normalQty > 0) {
              writeLine(
                  key: discountedQty > 0 ? '${bc}_OVERFLOW' : bc,
                  item: original.copyWith(quantity: normalQty),
                  active: false,
                  type: '',
                  unitPrice: mrp,
                  bQty: 1,
                  fQty: 0,
                  targetId: '',
                  overflow: discountedQty > 0);
            }
            return;
          }
        }
      }

      // No offer — full MRP
      writeLine(
          key: bc,
          item: original,
          active: false,
          type: '',
          unitPrice: mrp,
          bQty: 1,
          fQty: 0,
          targetId: '');
    });

    return OfferCalculationResult(
      updatedCartItems: result,
      totalAppliedDiscount: totalDiscount < 0 ? 0 : totalDiscount,
      newGrandTotal: grandTotal,
      totalFreeItems: freeCount,
    );
  }
}
