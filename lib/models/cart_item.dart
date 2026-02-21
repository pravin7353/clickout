class CartItem {
  final String barcode;
  final String name;
  final double price;
  final double gst;
  final double weight; // Weight per unit (in grams)
  final int quantity;

  CartItem({
    required this.barcode,
    required this.name,
    required this.price,
    required this.gst,
    required this.weight,
    required this.quantity,
  });

  // 🧠 KALI ENGINE: JSON mein explicit weights bhejenge
  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'name': name,
      'price': price,
      'gst': gst,
      'weight_per_unit': weight, // ✅ NEW: Single item weight
      'total_item_weight': weight * quantity, // ✅ NEW: Pre-calculated total
      'qty': quantity, // Backward compatibility
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      barcode: json['barcode'] ?? '',
      name: json['name'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      gst: double.tryParse(json['gst'].toString()) ?? 0.0,
      // Fallback: Agar weight_per_unit nahi hai toh purana 'weight' check karega
      weight: double.tryParse(
              (json['weight_per_unit'] ?? json['weight'] ?? 0.0).toString()) ??
          0.0,
      quantity: json['qty'] ?? json['quantity'] ?? 1,
    );
  }
}
