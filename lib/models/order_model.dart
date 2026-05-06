import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double gstTotal;
  final double grandTotal;
  final double totalWeight;
  final String paymentMode;
  final String? transactionId;
  final DateTime createdAt;

  // 🏪 STORE & DEVICE INFO
  final String branchCode;
  final String tenantId; // 👈 Naya SaaS ID
  final String storeId; // 👈 Naya SaaS ID
  final String deviceId;
  final String collectedBy;

  // 💰 PAYMENT STATUS
  final String paymentStatus;

  // 🛡️ SECURITY & SCANNING FIELDS
  final bool qrConsumed;
  final DateTime qrExpiresAt;

  // 👮 GUARD SCAN INFO
  final String exitStatus;
  final DateTime? exitTimestamp;
  final String? exitVerifiedBy;
  final DateTime? scanTimestamp;
  final String? scannedByEmpId;
  final String? scannedByName;

  // 🔥 MAGIC ANALYTICS & GUARD REJECT REASON
  final bool wasEverRejected;
  final String? rejectReason;

  // ⚖️ KALI ENGINE (Base Weight Flags)
  final bool weightVerifiedAtGate;
  final bool weightMismatchFlag;

  // 🧠 AI WEIGHT INTELLIGENCE (NEW PHASE-1)
  final double totalExpectedWeight;
  final double weightToleranceUsed;
  final double weightDifference;
  final String riskLevel; // LOW, MEDIUM, HIGH
  final String guardRecommendation; // APPROVE, MANUAL CHECK, REJECT

  OrderModel({
    required this.id,
    required this.items,
    required this.subtotal,
    required this.gstTotal,
    required this.grandTotal,
    required this.totalWeight,
    required this.paymentMode,
    this.transactionId,
    required this.createdAt,
    required this.branchCode,
    this.tenantId = '', // 👈 Default empty
    this.storeId = '', // 👈 Default empty
      required this.deviceId,
    required this.collectedBy,
    required this.paymentStatus,
    required this.qrConsumed,
    required this.qrExpiresAt,
    required this.exitStatus,
    this.exitTimestamp,
    this.exitVerifiedBy,
    this.scanTimestamp,
    this.scannedByEmpId,
    this.scannedByName,
    this.wasEverRejected = false,
    this.rejectReason,
    this.weightVerifiedAtGate = false,
    this.weightMismatchFlag = false,
    this.totalExpectedWeight = 0.0,
    this.weightToleranceUsed = 10.0,
    this.weightDifference = 0.0,
    this.riskLevel = 'LOW',
    this.guardRecommendation = 'APPROVE',
  });

  Map<String, dynamic> toMap() {
    return {
      'items': items,
      'subtotal': subtotal,
      'gstTotal': gstTotal,
      'totalAmount': grandTotal,
      'totalWeight': totalWeight,
      'paymentMode': paymentMode,
      'transactionId': transactionId,
      'timestamp': FieldValue.serverTimestamp(),

      'branchCode': branchCode,
      'tenantId': tenantId, // 👈 Firebase me bhejne ke liye
      'storeId': storeId, // 👈 Firebase me bhejne ke liye
      'deviceId': deviceId,
      'collectedBy': collectedBy,
      'paymentStatus': paymentStatus,

      'qrConsumed': qrConsumed,
      'qrExpiresAt': qrExpiresAt,

      'exitStatus': exitStatus,
      'exitTimestamp': exitTimestamp,
      'exitVerifiedBy': exitVerifiedBy,
      'scanTimestamp': scanTimestamp,
      'scannedByEmpId': scannedByEmpId,
      'scannedByName': scannedByName,

      'wasEverRejected': wasEverRejected,
      'rejectReason': rejectReason,

      'weightVerifiedAtGate': weightVerifiedAtGate,
      'weightMismatchFlag': weightMismatchFlag,

      // 🧠 AI Engine Data
      'totalExpectedWeight': totalExpectedWeight,
      'weightToleranceUsed': weightToleranceUsed,
      'weightDifference': weightDifference,
      'riskLevel': riskLevel,
      'guardRecommendation': guardRecommendation,
    };
  }

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return OrderModel(
      id: doc.id,
      items: List<Map<String, dynamic>>.from(data['items'] ?? []),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      gstTotal: (data['gstTotal'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      totalWeight: (data['totalWeight'] as num?)?.toDouble() ?? 0.0,
      paymentMode: data['paymentMode'] ?? 'UNKNOWN',
      transactionId: data['transactionId'],
      createdAt: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      branchCode: data['branchCode'] ?? 'MART01',
      tenantId: data['tenantId'] ?? '', // 👈 Firebase se padhne ke liye
      storeId: data['storeId'] ?? '', // 👈 Firebase se padhne ke liye
      deviceId: data['deviceId'] ?? 'APP',
      collectedBy: data['collectedBy'] ?? '',
      paymentStatus: data['paymentStatus'] ?? 'PENDING',
      qrConsumed: data['qrConsumed'] ?? false,
      qrExpiresAt: (data['qrExpiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(hours: 4)),
      exitStatus: data['exitStatus'] ?? 'PENDING',
      exitTimestamp: (data['exitTimestamp'] as Timestamp?)?.toDate(),
      exitVerifiedBy: data['exitVerifiedBy'],
      scanTimestamp: (data['scanTimestamp'] as Timestamp?)?.toDate(),
      scannedByEmpId: data['scannedByEmpId'],
      scannedByName: data['scannedByName'],
      wasEverRejected: data['wasEverRejected'] ?? false,
      rejectReason: data['rejectReason'],
      weightVerifiedAtGate: data['weightVerifiedAtGate'] ?? false,
      weightMismatchFlag: data['weightMismatchFlag'] ?? false,

      // 🧠 AI Engine Fallbacks (Safely handle old orders)
      totalExpectedWeight: (data['totalExpectedWeight'] as num?)?.toDouble() ??
          (data['totalWeight'] as num?)?.toDouble() ??
          0.0,
      weightToleranceUsed:
          (data['weightToleranceUsed'] as num?)?.toDouble() ?? 10.0,
      weightDifference: (data['weightDifference'] as num?)?.toDouble() ?? 0.0,
      riskLevel: data['riskLevel'] ?? 'LOW',
      guardRecommendation: data['guardRecommendation'] ?? 'APPROVE',
    );
  }
}
