// imports
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// class
class PdfInvoiceService {
  // functions
  static Future<void> printInvoice(
      Map<String, dynamic> orderData, String orderId) async {
    final pdf = await _generatePdf(orderData, orderId);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_$orderId',
    );
  }

  static Future<void> shareInvoice(
      Map<String, dynamic> orderData, String orderId) async {
    final pdf = await _generatePdf(orderData, orderId);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Invoice_$orderId.pdf',
    );
  }

  static Future<pw.Document> _generatePdf(
      Map<String, dynamic> data, String id) async {
    final pdf = pw.Document();

    DateTime date = DateTime.now();
    if (data['timestamp'] != null) {
      if (data['timestamp'] is Timestamp) {
        date = (data['timestamp'] as Timestamp).toDate();
      }
    } else if (data['createdAt'] != null) {
      if (data['createdAt'] is Timestamp) {
        date = (data['createdAt'] as Timestamp).toDate();
      }
    }

    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(date);
    final items = (data['items'] as List<dynamic>? ?? []);

    double totalMRP =
        double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0;
    double totalGSTAmount = 0;
    double totalBasePrice = 0;

    // 🧮 SAVINGS CALCULATION FOR PDF
    double totalOriginalMRP = 0;

    double totalWeight =
        double.tryParse(data['totalWeight']?.toString() ?? '0') ?? 0.0;
    String weightDisplay = totalWeight >= 1000
        ? "${(totalWeight / 1000).toStringAsFixed(2)} KG"
        : "${totalWeight.toStringAsFixed(0)} g";

    // try catch error handling
    try {
      for (var item in items) {
        // Find Original Price vs Final Charged Price
        double itemOriginalPrice =
            double.tryParse(item['originalPrice']?.toString() ?? '0') ?? 0.0;
        double itemFinalPrice =
            double.tryParse(item['price']?.toString() ?? '') ??
                double.tryParse(item['discountedPrice']?.toString() ?? '') ??
                itemOriginalPrice;

        double itemQty = double.tryParse(item['qty']?.toString() ?? '') ??
            double.tryParse(item['quantity']?.toString() ?? '0') ??
            0.0;

        totalOriginalMRP += (itemOriginalPrice * itemQty);

        double gstRate = item['gst'] != null
            ? (double.tryParse(item['gst'].toString()) ?? 18.0)
            : 18.0;

        double basePricePerUnit = itemFinalPrice / (1 + (gstRate / 100));
        double totalBaseForLine = basePricePerUnit * itemQty;
        double gstAmountForLine = (itemFinalPrice * itemQty) - totalBaseForLine;

        totalBasePrice += totalBaseForLine;
        totalGSTAmount += gstAmountForLine;
      }
    } catch (e) {
      print("PDF Math Error: $e");
    }

    double totalSavings = totalOriginalMRP - totalMRP;
    if (totalSavings < 0) totalSavings = 0; // Fallback

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("CLICKOUT",
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red)),
                  pw.Text("TAX INVOICE",
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // DETAILS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("Billed To: ${data['userName'] ?? 'Customer'}"),
                        pw.Text("Mode: ${data['paymentMode'] ?? 'Online'}"),
                      ]),
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text("Invoice #: $id"),
                        pw.Text("Date: $dateStr"),
                      ]),
                ],
              ),
              pw.SizedBox(height: 20),

              // 📊 TABLE WITH WEIGHT COLUMN
              pw.Table.fromTextArray(
                context: context,
                border: null,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
                headerStyle:
                    const pw.TextStyle(color: PdfColors.white, fontSize: 10),
                data: <List<String>>[
                  <String>[
                    'Item',
                    'Qty',
                    'Weight',
                    'MRP',
                    'Taxable',
                    'GST',
                    'Total'
                  ],
                  ...items.map((e) {
                    double mrp =
                        double.tryParse(e['price']?.toString() ?? '') ??
                            double.tryParse(
                                e['discountedPrice']?.toString() ?? '') ??
                            double.tryParse(
                                e['originalPrice']?.toString() ?? '0') ??
                            0.0;

                    double qty = double.tryParse(e['qty']?.toString() ?? '') ??
                        double.tryParse(e['quantity']?.toString() ?? '0') ??
                        0.0;

                    double gstRate = e['gst'] != null
                        ? (double.tryParse(e['gst'].toString()) ?? 18.0)
                        : 18.0;
                    double base = (mrp / (1 + (gstRate / 100)));
                    double total = mrp * qty;
                    double gstAmt = total - (base * qty);

                    double itemWgt = double.tryParse(
                            e['total_item_weight']?.toString() ?? '') ??
                        (double.tryParse(
                                    e['weight_per_unit']?.toString() ?? '0') ??
                                0.0) *
                            qty;

                    String itemWgtStr = itemWgt >= 1000
                        ? "${(itemWgt / 1000).toStringAsFixed(2)}kg"
                        : "${itemWgt.toStringAsFixed(0)}g";

                    return [
                      e['name']?.toString() ?? 'Unknown Item',
                      qty.toStringAsFixed(0),
                      itemWgtStr,
                      mrp.toStringAsFixed(2),
                      (base * qty).toStringAsFixed(2),
                      gstAmt.toStringAsFixed(2),
                      total.toStringAsFixed(2)
                    ];
                  }),
                ],
              ),
              pw.SizedBox(height: 20),

              // TOTALS WITH SAVINGS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                            "Taxable Value:  ₹${totalBasePrice.toStringAsFixed(2)}"),
                        pw.Text(
                            "Total GST:  ₹${totalGSTAmount.toStringAsFixed(2)}"),
                        pw.Text("Total Bag Weight:  $weightDisplay",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700)),
                        pw.Divider(),
                        if (totalSavings > 0) ...[
                          pw.Text(
                              "TOTAL SAVINGS:  ₹${totalSavings.toStringAsFixed(2)}",
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 14,
                                  color: PdfColors.green)),
                          pw.SizedBox(height: 5),
                        ],
                        pw.Text("GRAND TOTAL:  ₹${totalMRP.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 16)),
                        pw.Text("(Incl. of all taxes)",
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey)),
                      ]),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }
}
