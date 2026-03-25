import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../utils/user_session.dart'; // 🚀 SAAS INJECTION IMPORT

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. 🔍 GET PRODUCT (GLOBAL: Sabke liye same database)
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
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
      print("Error fetching product: $e");
      return null;
    }
  }

  // 2. 🔎 SEARCH PRODUCTS (GLOBAL)
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    try {
      if (query.isEmpty) return [];
      String searchTerm = query.toLowerCase();

      // ⚠️ CHANGE: Global search 'products' collection mein
      final snapshot = await _db
          .collection('products')
          .where('tenantId',
              isEqualTo: UserSession.tenantId) // 🚀 SAAS INJECTION
          .where('storeId', isEqualTo: UserSession.storeId) // 🚀 SAAS INJECTION
          .where('searchKey', isGreaterThanOrEqualTo: searchTerm)
          .where('searchKey', isLessThan: '${searchTerm}z')
          .limit(10)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print("Search Error: $e");
      return [];
    }
  }

  // 3. 📸 UPLOAD IMAGE (GLOBAL FOLDER)
  Future<String?> uploadProductImage(File imageFile, String barcode) async {
    try {
      // ⚠️ CHANGE: Images bhi ek common folder mein jayengi
      final ref = FirebaseStorage.instance.ref().child(
            'product_images/$barcode.jpg',
          );

      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Image Upload Error: $e");
      return null;
    }
  }

  // 4. 💾 ADD PRODUCT (GLOBAL SAVE)
  Future<void> addProduct({
    required String barcode,
    required String name,
    required double price,
    required double gst,
    required double weight, // ⚖️ Weight bhi save hoga
    required int stock,
    String? imageUrl,
  }) async {
// ⚠️ CHANGE: SaaS Isolation - Barcode ke sath TenantId & StoreId link taaki clash na ho
    String docId = '${UserSession.tenantId}_${UserSession.storeId}_$barcode';

    await _db.collection('products').doc(docId).set({
      'name': name,
      'searchKey': name.toLowerCase(),
      'barcode': barcode,
      'price': price,
      'gst': gst,
      'weight': weight,
      'stock': stock,
      'physicalStock': stock,
      'soldStock': 0,
      'imageUrl': imageUrl,
      'tenantId': UserSession.tenantId, // 🚀 SAAS INJECTION
      'storeId': UserSession.storeId, // 🚀 SAAS INJECTION
    });
  }
}
