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
  static OfferCalculationResult applyAllOffers({
    required Map<String, CartItem> cartItems,
    required List<Map<String, dynamic>> activeOffers,
    required Map<String, int> liveStockLogs,
  }) {
    Map<String, CartItem> processedItems = {};
    double totalDiscount = 0.0;
    double finalGrandTotal = 0.0;
    int freeItemsCount = 0;

    cartItems.forEach((barcode, item) {
      int availableStock = liveStockLogs[barcode] ?? item.quantity;
      int actualCartQty =
          item.quantity > availableStock ? availableStock : item.quantity;
      int payableQty = actualCartQty;
      double itemFinalUnitPrice = item.originalPrice;

      // 🔍 Find if this product has an active offer
      var productOffer = activeOffers.firstWhere(
        (offer) =>
            (offer['productId'] == barcode || offer['barcode'] == barcode) &&
            offer['clearanceActive'] == true,
        orElse: () => <String, dynamic>{},
      );

      // Fallback to internal if not found
      if (productOffer.isEmpty && item.clearanceActive) {
        productOffer = {
          'clearanceType': item.clearanceType,
          'clearanceValue': item.clearanceValue,
          'buyQty': item.buyQty,
          'freeQty': item.freeQty,
          'freeProductId': item.freeProductId,
          'freeProductName': item.freeProductName,
          'flatDiscount': item.clearanceValue,
          'comboPrice': item.comboPrice,
        };
      }

      // 🛑 THE GHOST KILLER: Agar CartService ne is offer ko DEAD declare kar diya hai
      if (item.clearanceType == 'DEAD_OFFER') {
        productOffer = <String, dynamic>{}; // Kill it immediately!
      }

      bool isActive = productOffer.isNotEmpty;

      if (isActive) {
        String offerType =
            (productOffer['clearanceType'] ?? productOffer['type'] ?? '')
                .toString()
                .toUpperCase();

        switch (offerType) {
          // 🟢 CASE 1: BOGO (SAME ITEM FREE)
          case 'BOGO':
            int buyQty =
                int.tryParse(productOffer['buyQty']?.toString() ?? '1') ?? 1;
            int freeQty =
                int.tryParse(productOffer['freeQty']?.toString() ?? '1') ?? 1;
            int comboSize = buyQty + freeQty;
            int totalCombos = actualCartQty ~/ comboSize;
            int remainder = actualCartQty % comboSize;
            payableQty = (totalCombos * buyQty) + remainder;
            freeItemsCount += (totalCombos * freeQty);
            break;

          // 🟣 CASE 2: BUY X GET Y (CROSS PRODUCT)
          case 'BUY_X_GET_Y':
            int buyQty =
                int.tryParse(productOffer['buyQty']?.toString() ?? '1') ?? 1;
            int freeQty =
                int.tryParse(productOffer['freeQty']?.toString() ?? '1') ?? 1;
            // X par koi discount nahi milta, paise poore lagte hain!
            payableQty = actualCartQty;
            int totalCombos = actualCartQty ~/ buyQty;
            freeItemsCount += (totalCombos * freeQty);
            break;

          // 🟡 CASE 3: PERCENTAGE
          case 'PERCENT':
            double discountPercent = double.tryParse(
                    productOffer['clearanceValue']?.toString() ?? '0') ??
                0.0;
            if (discountPercent > 0 && discountPercent <= 100) {
              itemFinalUnitPrice = item.originalPrice -
                  (item.originalPrice * (discountPercent / 100));
            }
            break;

          // 🔴 CASE 4: FLAT DISCOUNT
          case 'FLAT':
            double flatDiscount = double.tryParse(
                    productOffer['flatDiscount']?.toString() ??
                        productOffer['clearanceValue']?.toString() ??
                        '0') ??
                0.0;
            itemFinalUnitPrice = item.originalPrice - flatDiscount;
            if (itemFinalUnitPrice < 0) itemFinalUnitPrice = 0;
            break;

          // 🔵 CASE 5: COMBO
          case 'COMBO':
            itemFinalUnitPrice = double.tryParse(
                    productOffer['comboPrice']?.toString() ?? '0') ??
                item.originalPrice;
            break;
        }
      }

      double itemOriginalTotal = item.originalPrice * actualCartQty;
      double itemCalculatedTotal = itemFinalUnitPrice * payableQty;

      totalDiscount += (itemOriginalTotal - itemCalculatedTotal);
      finalGrandTotal += itemCalculatedTotal;

      processedItems[barcode] = CartItem(
        barcode: item.barcode,
        name: item.name,
        originalPrice: item.originalPrice,
        gst: item.gst,
        weight: item.weight,
        quantity: actualCartQty,
        clearanceActive: isActive,
        // 🔥 UI TYPE PRESERVATION (Tag mat bhejo yahan se, warna UI break ho jayega)
        clearanceType: isActive
            ? (productOffer['clearanceType'] ?? item.clearanceType)
            : '',
        clearanceValue: isActive ? itemFinalUnitPrice : 0.0,
        buyQty: isActive
            ? (int.tryParse(productOffer['buyQty']?.toString() ?? '1') ??
                item.buyQty)
            : 1,
        freeQty: isActive
            ? (int.tryParse(productOffer['freeQty']?.toString() ?? '0') ??
                item.freeQty)
            : 0,
        freeProductId: isActive
            ? (productOffer['freeProductId'] ?? item.freeProductId)
            : '',
        freeProductName: isActive
            ? (productOffer['freeProductName'] ?? item.freeProductName)
            : '',
        comboPrice: isActive
            ? (double.tryParse(productOffer['comboPrice']?.toString() ?? '0') ??
                item.comboPrice)
            : 0.0,
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
