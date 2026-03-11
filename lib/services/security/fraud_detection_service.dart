// lib/services/security/fraud_detection_service.dart
class FraudDetectionService {
  // Evaluates the cart and returns a risk profile
  Map<String, dynamic> evaluateCartRisk(List<Map<String, dynamic>> items) {
    double calculatedTotalWeight = 0.0;

    for (var item in items) {
      double wpu = double.tryParse(item['weight_per_unit']?.toString() ?? '') ??
          double.tryParse(item['weight']?.toString() ?? '') ??
          0.0;
      int q = int.tryParse(
              item['qty']?.toString() ?? item['quantity']?.toString() ?? '1') ??
          1;
      calculatedTotalWeight +=
          double.tryParse(item['total_item_weight']?.toString() ?? '') ??
              (wpu * q);
    }

    calculatedTotalWeight =
        double.parse(calculatedTotalWeight.toStringAsFixed(3));
    double actualMeasuredWeight =
        calculatedTotalWeight; // In future, this comes from a weighing scale hardware

    double weightDiff = (calculatedTotalWeight - actualMeasuredWeight).abs();
    double diffPercentage = calculatedTotalWeight > 0
        ? (weightDiff / calculatedTotalWeight) * 100
        : 0;

    String riskLevel = 'LOW';
    String recommendation = 'APPROVE';

    if (diffPercentage > 12.0) {
      riskLevel = 'HIGH';
      recommendation = 'REJECT';
    } else if (diffPercentage > 5.0 && diffPercentage <= 12.0) {
      riskLevel = 'MEDIUM';
      recommendation = 'MANUAL CHECK';
    }

    return {
      'calculatedTotalWeight': calculatedTotalWeight,
      'weightDiff': weightDiff,
      'diffPercentage': diffPercentage,
      'riskLevel': riskLevel,
      'recommendation': recommendation,
      'weightMismatchFlag': diffPercentage > 12.0,
    };
  }
}
