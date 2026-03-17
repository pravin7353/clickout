class CartItem {
  final String barcode;
  final String name;
  final double originalPrice;
  final double gst;
  final double weight;
  final int quantity;

  // 🎁 OFFER FIELDS (No Math here, just storage)
  final bool clearanceActive;
  final String clearanceType;
  final int buyQty;
  final int freeQty;
  final double clearanceValue;
  final String freeProductId;
  final String freeProductName;
  final double comboPrice;

  CartItem({
    required this.barcode,
    required this.name,
    required this.originalPrice,
    required this.gst,
    required this.weight,
    required this.quantity,
    this.clearanceActive = false,
    this.clearanceType = '',
    this.buyQty = 1,
    this.freeQty = 0,
    this.clearanceValue = 0.0,
    this.freeProductId = '',
    this.freeProductName = '',
    this.comboPrice = 0.0,
  });

  // 🚀 ENGINE-DRIVEN PRICING
  // OfferEngineService sets clearanceValue as the Final Price for FLAT/PERCENT/COMBO
  double get finalUnitPrice {
    if (!clearanceActive) return originalPrice;
    if (clearanceType == 'BOGO' || clearanceType == 'BUY_X_GET_Y') {
      return originalPrice;
    }
    return clearanceValue > 0 ? clearanceValue : originalPrice;
  }

  // 📦 CALCULATED BY UI LATER
  double get totalPrice => finalUnitPrice * quantity;
  int get payableQty => quantity;

  CartItem copyWith({
    int? quantity,
    bool? clearanceActive,
    String? clearanceType,
    double? clearanceValue,
    int? buyQty,
    int? freeQty,
    String? freeProductId,
    String? freeProductName,
    double? comboPrice,
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
      buyQty: buyQty ?? this.buyQty,
      freeQty: freeQty ?? this.freeQty,
      clearanceValue: clearanceValue ?? this.clearanceValue,
      freeProductId: freeProductId ?? this.freeProductId,
      freeProductName: freeProductName ?? this.freeProductName,
      comboPrice: comboPrice ?? this.comboPrice,
    );
  }

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'originalPrice': originalPrice,
        'gst': gst,
        'weight': weight,
        'quantity': quantity,
        'clearanceActive': clearanceActive,
        'clearanceType': clearanceType,
        'buyQty': buyQty,
        'freeQty': freeQty,
        'clearanceValue': clearanceValue,
        'freeProductId': freeProductId,
        'freeProductName': freeProductName,
        'comboPrice': comboPrice,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        barcode: json['barcode'],
        name: json['name'],
        originalPrice:
            double.tryParse(json['originalPrice']?.toString() ?? '0') ?? 0.0,
        gst: double.tryParse(json['gst']?.toString() ?? '0') ?? 0.0,
        weight: double.tryParse(json['weight']?.toString() ?? '0') ?? 0.0,
        quantity: json['quantity'] ?? 1,
        clearanceActive: json['clearanceActive'] ?? false,
        clearanceType: json['clearanceType'] ?? '',
        buyQty: json['buyQty'] ?? 1,
        freeQty: json['freeQty'] ?? 0,
        clearanceValue:
            double.tryParse(json['clearanceValue']?.toString() ?? '0') ?? 0.0,
        freeProductId: json['freeProductId'] ?? '',
        freeProductName: json['freeProductName'] ?? '',
        comboPrice:
            double.tryParse(json['comboPrice']?.toString() ?? '0') ?? 0.0,
      );
}
