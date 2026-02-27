class CartItem {
  final String barcode;
  final String name;
  final double originalPrice; // Base price
  final double gst;
  final double weight; // Weight per unit
  final int quantity; // Scanned Qty

  // 🏷️ CLEARANCE METADATA (Naya Engine)
  final bool clearanceActive;
  final String? clearanceType; // "PERCENT" or "BOGO"
  final num? clearanceValue; // 10, 20, 50, or 100

  CartItem({
    required this.barcode,
    required this.name,
    required this.originalPrice,
    required this.gst,
    required this.weight,
    required this.quantity,
    this.clearanceActive = false,
    this.clearanceType,
    this.clearanceValue,
  });

  // ==========================================
  // 🧠 THE SMART CART ENGINE (Client-Side Math)
  // ==========================================

  // 1. FINAL UNIT PRICE (Case A: Percent Discount Logic)
  double get finalUnitPrice {
    if (clearanceActive &&
        clearanceType == 'PERCENT' &&
        clearanceValue != null) {
      return originalPrice - (originalPrice * (clearanceValue! / 100));
    }
    return originalPrice;
  }

  // 2. EFFECTIVE QUANTITY (Case B: BOGO Logic - Kitna piece milega?)
  int get effectiveQty {
    if (clearanceActive && clearanceType == 'BOGO') {
      return quantity * 2; // Buy 1 Get 1
    }
    return quantity;
  }

  // 3. PAYABLE QUANTITY (Kitne ka paisa lagega?)
  int get payableQty => quantity;

  // 4. TOTAL PRICE & WEIGHT (Auto Calculates)
  double get totalPrice => finalUnitPrice * payableQty;
  double get totalWeight => weight * effectiveQty;
  int get stockReduce => effectiveQty;

  // 🧠 KALI ENGINE: JSON for Firebase/Invoice (Cloud Sync)
  Map<String, dynamic> toJson() {
    return {
      'barcode': barcode,
      'name': name,
      'originalPrice': originalPrice, // 💡 Discounted price in invoice
      'gst': gst,
      'weight_per_unit': weight,
      'total_item_weight': totalWeight,
      'quantity': quantity,
      'clearanceActive': clearanceActive,
      'clearanceType': clearanceType,
      'clearanceValue': clearanceValue,
    };
  }

  // 🛠️ THE MISSING PIECE: Firebase se wapas padhne ke liye!
  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      barcode: json['barcode']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown Item',
      originalPrice: double.tryParse(
              (json['originalPrice'] ?? json['price'] ?? 0.0).toString()) ??
          0.0,
      gst: double.tryParse(json['gst']?.toString() ?? '0.0') ?? 0.0,
      weight: double.tryParse(
              (json['weight_per_unit'] ?? json['weight'] ?? 0.0).toString()) ??
          0.0,
      quantity:
          int.tryParse((json['quantity'] ?? json['qty'] ?? 1).toString()) ?? 1,
      clearanceActive: json['clearanceActive'] ?? false,
      clearanceType: json['clearanceType']?.toString(),
      clearanceValue: json['clearanceValue'],
    );
  }

  // Clone item helper
  CartItem copyWith({
    int? quantity,
    bool? clearanceActive,
    String? clearanceType,
    num? clearanceValue,
  }) {
    return CartItem(
      barcode: barcode,
      name: name,
      originalPrice: originalPrice,
      gst: gst,
      weight: weight,
      quantity: quantity ?? this.quantity,
      clearanceActive: clearanceActive ?? this.clearanceActive,
      clearanceType: clearanceType ?? this.clearanceType,
      clearanceValue: clearanceValue ?? this.clearanceValue,
    );
  }
}
