// lib/services/offers/offer_engine_service.dart
import 'package:flutter/foundation.dart';
import '../../models/cart_item.dart';

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
  // 🚀 MASTER FUNCTION: applyAllOffers
  // Ab ye har naye type ke offer (BOGO, FLAT, PERCENT) ko handle karega
  static OfferCalculationResult applyAllOffers({
    required Map<String, CartItem> cartItems,
    required List<Map<String, dynamic>>
        activeOffers, // Pura product data yahan aayega
    required Map<String, int> liveStockLogs,
  }) {
    Map<String, CartItem> processedItems = {};
    double totalDiscount = 0.0;
    double finalGrandTotal = 0.0;
    int freeItemsCount = 0;

    cartItems.forEach((barcode, item) {
      int availableStock = liveStockLogs[barcode] ?? item.quantity;

      // 🛑 STRICT STOCK VALIDATION: Cart Quantity Physical Stock se zyada nahi ho sakti
      int actualCartQty = item.quantity;
      if (actualCartQty > availableStock) {
        actualCartQty = availableStock;
      }

      int payableQty = actualCartQty;
      double itemFinalUnitPrice = item.originalPrice;
      String appliedOfferTag = '';

      // 🔍 Find if this product has an active offer from Admin Panel
      // Admin saves data directly inside the product document, which comes here
      var productOffer = activeOffers.firstWhere(
        (offer) =>
            (offer['productId'] == barcode || offer['barcode'] == barcode) &&
            offer['clearanceActive'] == true,
        orElse: () => <String, dynamic>{},
      );

      // Agar data activeOffers list me nahi mila, par item.clearanceActive true hai (Fallback)
      if (productOffer.isEmpty && item.clearanceActive) {
        productOffer = {
          'clearanceType': item.clearanceType ?? 'PERCENT',
          'clearanceValue': item.clearanceValue ?? 0,
        };
      }

      if (productOffer.isNotEmpty) {
        String offerType =
            (productOffer['clearanceType'] ?? productOffer['type'] ?? '')
                .toString()
                .toUpperCase();

        switch (offerType) {
          // 🟢 CASE 1: BOGO & BUY X GET Y
          case 'BOGO':
          case 'BUY_X_GET_Y':
            int buyQty =
                int.tryParse(productOffer['buyQty']?.toString() ?? '1') ?? 1;
            int freeQty =
                int.tryParse(productOffer['freeQty']?.toString() ?? '1') ?? 1;

            // 🧠 THE BOGO MATH ENGINE
            int comboSize = buyQty + freeQty;
            int totalCombos = actualCartQty ~/ comboSize;
            int remainder = actualCartQty % comboSize;

            payableQty = (totalCombos * buyQty) + remainder;
            int calculatedFreeQty = totalCombos * freeQty;

            freeItemsCount += calculatedFreeQty;
            appliedOfferTag =
                productOffer['clearanceTag'] ?? 'BUY $buyQty GET $freeQty';
            break;

          // 🟡 CASE 2: PERCENTAGE DISCOUNT
          case 'PERCENT':
            double discountPercent = double.tryParse(
                    productOffer['clearanceValue']?.toString() ?? '0') ??
                0.0;
            if (discountPercent > 0 && discountPercent <= 100) {
              itemFinalUnitPrice = item.originalPrice -
                  (item.originalPrice * (discountPercent / 100));
            }
            appliedOfferTag = productOffer['clearanceTag'] ??
                '${discountPercent.toStringAsFixed(0)}% OFF';
            break;

          // 🔴 CASE 3: FLAT DISCOUNT (₹ OFF)
          case 'FLAT':
            double flatDiscount = double.tryParse(
                    productOffer['flatDiscount']?.toString() ?? '0') ??
                0.0;
            itemFinalUnitPrice = item.originalPrice - flatDiscount;
            if (itemFinalUnitPrice < 0) {
              itemFinalUnitPrice = 0; // 🛡️ Zero limit protection
            }
            appliedOfferTag = productOffer['clearanceTag'] ??
                '₹${flatDiscount.toStringAsFixed(0)} OFF';
            break;

          // 🟣 CASE 4: COMBO / BUNDLE (Basic handling for current item)
          case 'COMBO':
            // Custom logic based on bundle size (Advanced Phase)
            appliedOfferTag = productOffer['clearanceTag'] ?? 'COMBO DEAL';
            break;
        }
      }

      // 🧮 CALCULATE FINANCIAL TOTALS
      double itemOriginalTotal = item.originalPrice * actualCartQty;
      double itemCalculatedTotal = itemFinalUnitPrice * payableQty;

      totalDiscount += (itemOriginalTotal - itemCalculatedTotal);
      finalGrandTotal += itemCalculatedTotal;

      // ✅ REBUILD ITEM SAFELY (Update with calculated math)
      processedItems[barcode] = CartItem(
          barcode: item.barcode,
          name: item.name,
          originalPrice: item.originalPrice,
          gst: item.gst,
          weight: item.weight,
          quantity: actualCartQty, // Updated restricted quantity
          clearanceActive: productOffer.isNotEmpty,
          clearanceType: appliedOfferTag, // Using tag for UI display
          clearanceValue: itemFinalUnitPrice // Safe final unit price
          );
    });

    return OfferCalculationResult(
      updatedCartItems: processedItems,
      totalAppliedDiscount: totalDiscount,
      newGrandTotal: finalGrandTotal,
      totalFreeItems: freeItemsCount,
    );
  }
}
