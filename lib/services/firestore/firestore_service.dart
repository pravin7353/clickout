import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. 🔍 GET PRODUCT (GLOBAL: Sabke liye same database)
  Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    try {
      // ⚠️ CHANGE: Ab hum root 'products' collection check kar rahe hain
      final doc = await _db.collection('products').doc(barcode).get();

      if (doc.exists) {
        return doc.data();
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
    // ⚠️ CHANGE: Root 'products' collection mein save karo
    await _db.collection('products').doc(barcode).set({
      'name': name,
      'searchKey': name.toLowerCase(), // Search karne ke liye
      'barcode': barcode,
      'price': price,
      'gst': gst,
      'weight': weight, // ⚖️ Saved Weight
      'stock': stock,
      'imageUrl': imageUrl,
      'addedBy': _auth.currentUser?.uid, // Tracking ke liye kisne add kiya
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
