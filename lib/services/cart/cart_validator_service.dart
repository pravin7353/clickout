// lib/services/cart/cart_validator_service.dart
import 'package:flutter/material.dart';
import '../inventory/inventory_service.dart';
import '../../models/cart_item.dart'; // Ensure correct path to your model

class CartValidatorService {
  final InventoryService _inventoryService = InventoryService();

  // 🛡️ THE VALIDATION ENGINE
  Future<Map<String, dynamic>> validate(
      Map<String, CartItem> currentItems, bool isCorrectionMode) async {
    // 🚨 MASTER FIX: No validation in Correction Mode to protect paid items
    if (isCorrectionMode) {
      debugPrint(
          "🛡️ CORRECTION MODE ACTIVE: Skipping validation to protect paid stock.");
      return {
        'warnings': <String>[],
        'itemsToRemove': <String>[],
        'updates': <String, CartItem>{}
      };
    }

    List<String> warnings = [];
    List<String> itemsToRemove = [];
    Map<String, CartItem> updates = {};

    for (String barcode in currentItems.keys) {
      final data = await _inventoryService.getProductLiveDetails(barcode);
      CartItem currentItem = currentItems[barcode]!;

      // 1. Item removed from database completely
      if (data == null) {
        warnings.add("Item removed from store.");
        itemsToRemove.add(barcode);
        continue;
      }

      int liveStock = _inventoryService.getLiveStock(data);
      double freshPrice = double.tryParse(data['price'].toString()) ?? 0.0;

      // 2. Out of Stock Check
      if (liveStock <= 0) {
        warnings.add("${data['name']} Out of Stock.");
        itemsToRemove.add(barcode);
      }
      // 3. Stock Limit Check
      else if (currentItem.quantity > liveStock) {
        warnings.add(
            "${data['name']} quantity reduced to available stock ($liveStock).");
        updates[barcode] = _copyItemWithUpdates(currentItem,
            quantity: liveStock, data: data, freshPrice: freshPrice);
      }
      // 4. Price & Offer Updates Check
      else {
        bool priceChanged =
            (currentItem.originalPrice - freshPrice).abs() > 0.01;
        bool offerChanged =
            currentItem.clearanceActive != (data['clearanceActive'] ?? false) ||
                currentItem.clearanceValue != data['clearanceValue'];

        if (priceChanged || offerChanged) {
          warnings.add("Rate/Offer updated for ${data['name']}.");
          updates[barcode] = _copyItemWithUpdates(currentItem,
              quantity: currentItem.quantity,
              data: data,
              freshPrice: freshPrice);
        }
      }
    }

    return {
      'warnings': warnings,
      'itemsToRemove': itemsToRemove,
      'updates': updates,
    };
  }

  // Helper method to clone and update cart item
  CartItem _copyItemWithUpdates(CartItem old,
      {required int quantity,
      required Map<String, dynamic> data,
      required double freshPrice}) {
    return CartItem(
      barcode: old.barcode,
      name: old.name,
      originalPrice: freshPrice,
      gst: old.gst,
      weight: old.weight,
      quantity: quantity,
      clearanceActive: data['clearanceActive'] ?? false,
      clearanceType: data['clearanceType']?.toString(),
      clearanceValue: data['clearanceValue'],
    );
  }
}
