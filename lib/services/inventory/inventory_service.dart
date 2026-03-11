// lib/services/inventory/inventory_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 📦 FETCH PRODUCT LIVE DETAILS
  Future<Map<String, dynamic>?> getProductLiveDetails(String barcode) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('products').doc(barcode).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // 📊 EXTRACT SAFE STOCK VALUE (Handles database variations safely)
  int getLiveStock(Map<String, dynamic> productData) {
    return int.tryParse(productData['physicalStock']?.toString() ??
            productData['stock']?.toString() ??
            '0') ??
        0;
  }
}
