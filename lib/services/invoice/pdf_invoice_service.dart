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
    } catch (_) {}

    // Font fix for Rupee Symbol
    final ttf = await PdfGoogleFonts.robotoRegular();
    final ttfBold = await PdfGoogleFonts.robotoBold();

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
    double totalOriginalMRP = 0;
    double manualTotalWeight = 0;

    try {
      for (var item in items) {
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

        // 🔥 THE RESTORED 1:20 PM GST LOGIC
        double gstRate = 0.0;
        if (item['gst'] != null && item['gst'].toString().isNotEmpty) {
          String rawGst =
              item['gst'].toString().replaceAll(RegExp(r'[^0-9.]'), '');
          gstRate = double.tryParse(rawGst) ?? 0.0;
        }

        // 🔥 THE RESTORED 1:20 PM WEIGHT LOGIC (Ultra Safe)
        double w =
            double.tryParse(item['total_item_weight']?.toString() ?? '') ??
                double.tryParse(item['weight_per_unit']?.toString() ?? '') ??
                double.tryParse(item['weight']?.toString() ?? '0') ??
                0.0;

        manualTotalWeight += (w * itemQty);

        double basePricePerUnit = itemFinalPrice / (1 + (gstRate / 100));
        double totalBaseForLine = basePricePerUnit * itemQty;
        double gstAmountForLine = (itemFinalPrice * itemQty) - totalBaseForLine;

        totalBasePrice += totalBaseForLine;
        totalGSTAmount += gstAmountForLine;
      }
    } catch (e) {
      print("PDF Math Error: $e");
    }

    double dbTotalWeight =
        double.tryParse(data['totalWeight']?.toString() ?? '0') ?? 0.0;
    double finalTotalWeight =
        dbTotalWeight > 0 ? dbTotalWeight : manualTotalWeight;

    String weightDisplay = finalTotalWeight >= 1000
        ? "${(finalTotalWeight / 1000).toStringAsFixed(2)} KG"
        : "${finalTotalWeight.toStringAsFixed(0)} g";

    double totalSavings = totalOriginalMRP - totalMRP;
    if (totalSavings < 0) totalSavings = 0;

    // 🧠 2. SMART TITLE & DYNAMIC DATA LOGIC
    String invoiceNumber =
        data['invoiceNo']?.toString() ?? id; // 🚀 DB SE NAYA NUMBER UTHAYEGA
    String documentTitle =
        totalGSTAmount > 0.0 ? "TAX INVOICE" : "BILL OF SUPPLY";
    String branchCode = data['branchCode']?.toString() ?? 'STORE';
    String storeName = data['storeName']?.toString() ?? branchCode;

    // Fetch actual Store Name from DB
    try {
      if (branchCode.isNotEmpty && branchCode != 'STORE') {
        var sSnap = await FirebaseFirestore.instance
            .collection('stores')
            .where('branchCode', isEqualTo: branchCode)
            .limit(1)
            .get();
        if (sSnap.docs.isNotEmpty) {
          storeName = (sSnap.docs.first.data()['storeName'] ??
                  sSnap.docs.first.data()['branchName'] ??
                  storeName)
              .toString()
              .toUpperCase();
        }
      }
    } catch (_) {}
    String cashierName = data['scannedByName']?.toString() ?? '';
    String guardName =
        data['verifiedByGuardId']?.toString() ?? 'Pending Approval';
    String paymentMode = data['paymentMode']?.toString() ?? 'Online';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                            "Billed To: ${data['customerName'] ?? data['userId'] ?? 'Unknown'}"),
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
                        pw.Text("Invoice #: $invoiceNumber"),
                        pw.Text("Date: $dateStr"),
                      ]),
                ],
              ),
              pw.SizedBox(height: 20),
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

                    // 🔥 THE RESTORED 1:20 PM GST LOGIC
                    double gstRate = 0.0;
                    if (e['gst'] != null && e['gst'].toString().isNotEmpty) {
                      String raw = e['gst']
                          .toString()
                          .replaceAll(RegExp(r'[^0-9.]'), '');
                      gstRate = double.tryParse(raw) ?? 0.0;
                    }

                    double base = (mrp / (1 + (gstRate / 100)));
                    double total = mrp * qty;
                    double gstAmt = total - (base * qty);

                    // 🔥 THE RESTORED 1:20 PM WEIGHT LOGIC
                    double itemWgt = double.tryParse(
                            e['total_item_weight']?.toString() ?? '') ??
                        (double.tryParse(
                                    e['weight_per_unit']?.toString() ?? '') ??
                                double.tryParse(
                                    e['weight']?.toString() ?? '0') ??
                                0.0) *
                            qty;

                    String itemWgtStr = itemWgt >= 1000
                        ? "${(itemWgt / 1000).toStringAsFixed(2)}kg"
                        : "${itemWgt.toStringAsFixed(0)}g";

                    // 🚀 3. OFFER LOGIC: Add [FREE] tag if applicable
                    String itemName = e['name']?.toString() ?? 'Unknown Item';
                    String clearanceType = e['clearanceType']?.toString() ?? '';
                    if (mrp == 0 || clearanceType == 'FREE_ITEM') {
                      itemName = "[FREE] $itemName";
                    }

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
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }
}
