// lib/services/invoice/invoice_service.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceService {
  // 🖨️ PRINT INVOICE
  static Future<void> printInvoice(
      Map<String, dynamic> orderData, String orderId) async {
    final pdf = await _generatePdf(orderData, orderId);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Invoice_$orderId',
    );
  }

  // 📤 SHARE INVOICE (System Share Sheet)
  static Future<void> shareInvoice(
      Map<String, dynamic> orderData, String orderId) async {
    final pdf = await _generatePdf(orderData, orderId);
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Invoice_$orderId.pdf',
    );
  }

  // 💾 GET PDF BYTES (Agar email bhejna ho ya backend pe save karna ho)
  static Future<Uint8List> getInvoiceBytes(
      Map<String, dynamic> orderData, String orderId) async {
    final pdf = await _generatePdf(orderData, orderId);
    return await pdf.save();
  }

  // 🎨 INTERNAL PDF GENERATOR (Your existing smart parsing logic)
  static Future<pw.Document> _generatePdf(
      Map<String, dynamic> data, String id) async {
    final pdf = pw.Document();

    // 🚀 1. FETCH DYNAMIC T&C FROM ADMIN PANEL
    String termsAndConditions =
        "1. Exchange within 7 days with original receipt.\n2. Goods once sold will not be refunded.";
    try {
      String tId = data['tenantId']?.toString() ?? '';
      if (tId.isNotEmpty) {
        var tDoc = await FirebaseFirestore.instance
            .collection('tenants')
            .doc(tId)
            .get();
        if (tDoc.exists && tDoc.data()!.containsKey('invoiceConfig')) {
          termsAndConditions =
              tDoc.data()!['invoiceConfig']['terms'] ?? termsAndConditions;
        }
      }
    } catch (_) {} // Fallback to default if offline/error

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

    // Calculations
    double totalMRP =
        double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0.0;
    double totalGSTAmount = 0;
    double totalBasePrice = 0;

    // ⚖️ Extract Total Weight
    double totalWeight =
        double.tryParse(data['totalWeight']?.toString() ?? '0') ?? 0.0;
    String weightDisplay = totalWeight >= 1000
        ? "${(totalWeight / 1000).toStringAsFixed(2)} KG"
        : "${totalWeight.toStringAsFixed(0)} g";

    for (var item in items) {
      double itemMRP = double.tryParse(item['price']?.toString() ?? '') ??
          double.tryParse(item['discountedPrice']?.toString() ?? '') ??
          double.tryParse(item['originalPrice']?.toString() ?? '0') ??
          0.0;

      double itemQty = double.tryParse(item['qty']?.toString() ?? '') ??
          double.tryParse(item['quantity']?.toString() ?? '0') ??
          0.0;

      double gstRate = item['gst'] != null
          ? double.tryParse(item['gst'].toString()) ?? 18.0
          : 18.0;

      double basePricePerUnit = itemMRP / (1 + (gstRate / 100));
      double totalBaseForLine = basePricePerUnit * itemQty;
      double gstAmountForLine = (itemMRP * itemQty) - totalBaseForLine;

      totalBasePrice += totalBaseForLine;
      totalGSTAmount += gstAmountForLine;
    }

    // 🧠 2. SMART TITLE & DYNAMIC DATA LOGIC
    String documentTitle =
        totalGSTAmount > 0.0 ? "TAX INVOICE" : "BILL OF SUPPLY";
    String storeName =
        data['branchCode']?.toString() ?? 'CLICKOUT'; // Dynamic Store
    String cashierName = data['scannedByName']?.toString() ?? '';
    String guardName =
        data['verifiedByGuardId']?.toString() ?? 'Pending Approval';
    String paymentMode = data['paymentMode']?.toString() ?? 'Online';

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
                  pw.Text(storeName, // 🚀 Dynamic Store Name
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red)),
                  pw.Text(documentTitle, // 🚀 Math Decided Title
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
                        pw.Text("Mode: $paymentMode"),
                        if (paymentMode == 'CASH' && cashierName.isNotEmpty)
                          pw.Text(
                              "Cashier: $cashierName"), // 🚀 Cashier Name added
                        pw.Text(
                            "Exit Approved By: $guardName"), // 🚀 Guard Name added
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

              // 📊 TABLE
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

                    // 🚀 3. OFFER LOGIC: Add [FREE] tag if applicable
                    String itemName = e['name']?.toString() ?? 'Unknown Item';
                    String clearanceType = e['clearanceType']?.toString() ?? '';
                    if (mrp == 0 || clearanceType == 'FREE_ITEM') {
                      itemName = "[FREE] $itemName";
                    }

                    double gstRate = e['gst'] != null
                        ? double.tryParse(e['gst'].toString()) ?? 18.0
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
                      itemName,
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

              // TOTALS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                            "Taxable Value:  ${totalBasePrice.toStringAsFixed(2)}"),
                        pw.Text(
                            "Total GST:  ${totalGSTAmount.toStringAsFixed(2)}"),
                        pw.Text("Total Bag Weight:  $weightDisplay",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700)),
                        pw.Divider(),
                        pw.Text("GRAND TOTAL:  ${totalMRP.toStringAsFixed(2)}",
                            style: pw.TextStyle(
                                fontWeight: pw.FontWeight.bold, fontSize: 16)),
                        pw.Text("(Incl. of all taxes)",
                            style: const pw.TextStyle(
                                fontSize: 10, color: PdfColors.grey)),
                      ]),
                ],
              ),
              pw.SizedBox(height: 30),

              // 📜 4. DYNAMIC TERMS & CONDITIONS
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.Text(
                "Terms & Conditions:",
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                termsAndConditions,
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }
}
