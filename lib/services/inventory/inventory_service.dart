// lib/services/inventory/inventory_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/user_session.dart';

class InventoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 📦 FETCH PRODUCT LIVE DETAILS
  Future<Map<String, dynamic>?> getProductLiveDetails(String barcode) async {
    try {
      final snap = await _db
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .where('tenantId',
              isEqualTo: UserSession.tenantId) // 🚀 SAAS INJECTION
          .where('storeId', isEqualTo: UserSession.storeId) // 🚀 SAAS INJECTION
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        return snap.docs.first.data();
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
