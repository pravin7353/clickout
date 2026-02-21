import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/order_model.dart';

class InvoiceService {
  static Future<Uint8List> generateInvoicePdf(OrderModel order) async {
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.DefaultTextStyle(
            style: pw.TextStyle(font: ttf, fontSize: 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ClickOut Invoice',
                  style: pw.TextStyle(
                    font: ttf,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.SizedBox(height: 6),
                pw.Text('Date: ${order.createdAt.toLocal()}'),
                pw.Divider(),

                // ================= TABLE =================
                pw.Table.fromTextArray(
                  headers: ['Item', 'Qty', 'Price', 'GST', 'Total'],
                  data: order.items.map((item) {
                    return [
                      item['name'],
                      item['qty'].toString(),
                      '₹${item['price']}',
                      '${item['gst']}%',
                      '₹${item['total']}',
                    ];
                  }).toList(),
                ),

                pw.Divider(),

                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Subtotal: ₹${order.subtotal}'),
                      pw.Text('GST: ₹${order.gstTotal}'),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Grand Total: ₹${order.grandTotal}',
                        style: pw.TextStyle(
                          font: ttf,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
