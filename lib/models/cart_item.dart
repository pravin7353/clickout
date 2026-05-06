class CartItem {
  final String barcode;
  final String name;
  final double originalPrice;
  final double gst;
  final double weight;
  final int quantity;
  final int freeQtyGiven;
  final bool isOverflow;
  final bool clearanceActive;
  final String clearanceType;
  final int buyQty;
  final int freeQty;
  final double clearanceValue;
  final String freeProductId;
  final String freeProductName;
  final double comboPrice;
  final String offerHint; // 🚀 FIX: To show "Add 1 more" logic in UI
  final int flashExpiry; // 🚀 FIX: To show Flash Sale Timer

  CartItem({
    required this.barcode,
    required this.name,
    required this.originalPrice,
    required this.gst,
    required this.weight,
    required this.quantity,
    this.freeQtyGiven = 0,
    this.isOverflow = false,
    this.clearanceActive = false,
    this.clearanceType = '',
    this.buyQty = 1,
    this.freeQty = 0,
    this.clearanceValue = 0.0,
    this.freeProductId = '',
    this.freeProductName = '',
    this.comboPrice = 0.0,
    this.offerHint = '',
    this.flashExpiry = 0,
  });

  // 🚀 FIX: Accepts 0.0 as a valid price for FREE items (clearanceValue >= 0)
  double get finalUnitPrice {
    if (!clearanceActive || isOverflow) {
      return originalPrice;
    }
    if (clearanceType == 'BOGO' ||
        clearanceType == 'BUY_X_GET_Y' ||
        clearanceType == 'BUY_X_GET_Y_CROSS') {
      return originalPrice;
    }
    return clearanceValue >= 0.0 ? clearanceValue : originalPrice;
  }

  int get payableQty => quantity;
  int get physicalTotalQty => quantity + freeQtyGiven;
  double get totalPrice => finalUnitPrice * payableQty;

  CartItem copyWith({
    String? name,
    String? offerHint,
    int? flashExpiry,
    double? originalPrice,
    double? gst,
    double? weight,
    int? quantity,
    int? freeQtyGiven,
    bool? isOverflow,
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
      name: name ?? this.name,
      originalPrice: originalPrice ?? this.originalPrice,
      gst: gst ?? this.gst,
      weight: weight ?? this.weight,
      quantity: quantity ?? this.quantity,
      freeQtyGiven: freeQtyGiven ?? this.freeQtyGiven,
      isOverflow: isOverflow ?? this.isOverflow,
      clearanceActive: clearanceActive ?? this.clearanceActive,
      clearanceType: clearanceType ?? this.clearanceType,
      buyQty: buyQty ?? this.buyQty,
      freeQty: freeQty ?? this.freeQty,
      clearanceValue: clearanceValue ?? this.clearanceValue,
      freeProductId: freeProductId ?? this.freeProductId,
      freeProductName: freeProductName ?? this.freeProductName,
      comboPrice: comboPrice ?? this.comboPrice,
      offerHint: offerHint ?? this.offerHint,
      flashExpiry: flashExpiry ?? this.flashExpiry,
    );
  }

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'originalPrice': originalPrice,
        'gst': gst,
        'weight': weight,
        'quantity': quantity,
        'freeQtyGiven': freeQtyGiven,
        'isOverflow': isOverflow,
        'clearanceActive': clearanceActive,
        'clearanceType': clearanceType,
        'buyQty': buyQty,
        'freeQty': freeQty,
        'clearanceValue': clearanceValue,
        'freeProductId': freeProductId,
        'freeProductName': freeProductName,
        'comboPrice': comboPrice,
        'offerHint': offerHint,
        'flashExpiry': flashExpiry,
      };

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        barcode: json['barcode'],
        name: json['name'],
        originalPrice:
            double.tryParse(json['originalPrice']?.toString() ?? '0') ?? 0.0,
        gst: double.tryParse(json['gst']?.toString() ?? '0') ?? 0.0,
        weight: double.tryParse(json['weight']?.toString() ?? '0') ?? 0.0,
        quantity: json['quantity'] ?? 1,
        freeQtyGiven: json['freeQtyGiven'] ?? 0,
        isOverflow: json['isOverflow'] ?? false,
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
        offerHint: json['offerHint'] ?? '',
        flashExpiry: json['flashExpiry'] ?? 0,
      );
}
