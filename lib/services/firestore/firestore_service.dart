import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../utils/user_session.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. 🔍 GET PRODUCT (🚀 THE BULLETPROOF SCANNER ENGINE)
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    try {
      // Search screen jaisa same logic: Pehle dukan ka stock uthao
      final snap = await _db
          .collection('products')
          .where('tenantId', isEqualTo: UserSession.tenantId)
          .where('branchCode', isEqualTo: UserSession.storeId)
          .get();

      // Barcode se kachra (spaces, quotes) saaf karo taaki CSV ki galti chhip jaye
      String cleanScanned =
          barcode.toString().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');

      for (var doc in snap.docs) {
        final data = doc.data();
        if (data['barcode'] != null) {
          String dbBarcode = data['barcode']
              .toString()
              .replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');

          if (dbBarcode == cleanScanned) {
            return data; // 🔥 100% GUARANTEED MATCH
          }
        }
      }
      return null; // Asli me nahi mila
    } catch (e) {
      print("Scanner Error: $e");
      return null;
    }
  }

  // 2. 🔎 SEARCH PRODUCTS
  Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    try {
      if (query.isEmpty) return [];
      String searchTerm = query.toLowerCase();

      final snapshot = await _db
          .collection('products')
          .where('tenantId', isEqualTo: UserSession.tenantId)
          .where('branchCode', isEqualTo: UserSession.storeId)
          .get();

      return snapshot.docs
          .map((doc) => doc.data())
          .where((data) {
            String searchKey = (data['searchKey'] ?? data['name'] ?? '')
                .toString()
                .toLowerCase();
            return searchKey.contains(searchTerm);
          })
          .take(10)
          .toList();
    } catch (e) {
      print("Search Error: $e");
      return [];
    }
  }

  // 3. 📸 UPLOAD IMAGE
  Future<String?> uploadProductImage(File imageFile, String barcode) async {
    try {
      final ref =
          FirebaseStorage.instance.ref().child('product_images/$barcode.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Image Upload Error: $e");
      return null;
    }
  }

  // 4. 💾 ADD PRODUCT
  Future<void> addProduct({
    required String barcode,
    required String name,
    required double price,
    required double gst,
    required double weight,
    required int stock,
    String? imageUrl,
  }) async {
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
      'tenantId': UserSession.tenantId,
      'branchCode': UserSession.storeId,
    });
  }
}
