import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // ✅ NEW IMPORT
import '../services/pdf_invoice_service.dart';
import '../services/cart_service.dart'; // ✅ NEW IMPORT
import 'cart_screen.dart'; // ✅ NEW IMPORT

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);
  final Color successGreen = const Color(0xFF2E7D32);
  final Color alertRed = const Color(0xFFD32F2F);

  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(color: cherryRedDark));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Order Not Found"));
          }

          var orderData = snapshot.data!.data() as Map<String, dynamic>;
          String exitStatus =
              (orderData['exitStatus'] ?? 'PENDING').toString().toUpperCase();
          String paymentStatus = (orderData['paymentStatus'] ?? 'PENDING')
              .toString()
              .toUpperCase();
          String orderStatus =
              (orderData['status'] ?? 'PENDING').toString().toUpperCase();

          Widget content;
          if (orderStatus == 'DELETED' || orderStatus == 'CANCELLED') {
            content = _buildStatusMessage(Icons.delete_forever, "ORDER DELETED",
                "This order is no longer valid.", Colors.grey);
          } else if (orderStatus == 'EXPIRED') {
            content = _buildStatusMessage(Icons.timer_off, "ORDER EXPIRED",
                "Please create a new order.", Colors.orange);
          } else if (paymentStatus != 'PAID') {
            content = _buildUnpaidUI();
          } else if (exitStatus == 'PENDING' ||
              exitStatus == 'READY_FOR_EXIT') {
            content = _buildGatePassUI(orderData);
          }
          // 🟢 100% GREEN SUCCESS CHECK: Agar Guard ne Approve kiya toh YAHAN aayega!
          else if (exitStatus == 'COMPLETED' ||
              exitStatus == 'EXITED' ||
              exitStatus == 'APPROVED') {
            content = _buildSuccessUI();
          }
          // 🔴 100% RED FAILURE CHECK: Fix & Resubmit sirf tab aayega jab explicitly REJECTED ho!
          else if (exitStatus == 'REJECTED') {
            content = _buildFailureUI(orderData, context);
          } else {
            // Fallback for any unknown status
            content = _buildGatePassUI(orderData);
          }

          return Stack(
            children: [
              _buildHeaderBackground(exitStatus),
              SafeArea(
                child: Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildStatusIcon(exitStatus),
                      const SizedBox(height: 10),
                      Text(_getStatusTitle(exitStatus),
                          style: const TextStyle(
                              fontFamily: 'DejaVuSansMono',
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      Text("Order ID: ${widget.orderId}",
                          style: const TextStyle(
                              fontFamily: 'DejaVuSansMono',
                              color: Colors.white70,
                              fontSize: 12)),
                    ],
                  ),
                ),
              ),
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 200, left: 20, right: 20, bottom: 20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5))
                            ]),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            content,
                            const Divider(),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(10)),
                              child: Column(children: [
                                _buildDetailRow("Items",
                                    "${(orderData['items'] as List).length}"),
                                _buildDetailRow("Total Paid",
                                    "₹${orderData['totalAmount'] ?? orderData['gstTotal']}"),
                                _buildDetailRow("Date",
                                    _formatDate(orderData['timestamp'])),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (paymentStatus == 'PAID' && orderStatus != 'DELETED')
                        SizedBox(
                            width: double.infinity,
                            height: 45,
                            child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.black,
                                    side: const BorderSide(color: Colors.grey),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                icon: const Icon(Icons.share),
                                label: const Text("Share Invoice"),
                                onPressed: () => PdfInvoiceService.shareInvoice(
                                    orderData, widget.orderId))),
                    ],
                  ),
                ),
              ),
              Positioned(
                  top: 40,
                  left: 10,
                  child: CircleAvatar(
                      backgroundColor: Colors.black26,
                      radius: 20,
                      child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                          onPressed: () => Navigator.pop(context)))),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusMessage(
      IconData icon, String title, String sub, Color color) {
    return Column(children: [
      Icon(icon, size: 80, color: color),
      const SizedBox(height: 10),
      Text(title,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 22, color: color)),
      const SizedBox(height: 5),
      Text(sub,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey))
    ]);
  }

  Widget _buildUnpaidUI() {
    return _buildStatusMessage(Icons.warning_amber_rounded, "PAYMENT PENDING",
        "Please pay at the cash counter to generate Gate Pass.", Colors.orange);
  }

  Widget _buildGatePassUI(Map<String, dynamic> data) {
    bool isExpired = false;
    if (data['qrExpiresAt'] != null) {
      DateTime expiresAt = (data['qrExpiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) isExpired = true;
    }
    bool isConsumed = data['qrConsumed'] ?? false;

    if (isConsumed) {
      return _buildStatusMessage(Icons.check_circle_outline, "GATE PASS USED",
          "This order has already exited.", Colors.grey);
    }

    String waitingText = data['exitStatus'] == 'READY_FOR_EXIT'
        ? "Payment Verified. Ready for Exit Scan."
        : "Waiting for Guard Scan...";

    return Column(
      children: [
        const Text("GATE PASS",
            style: TextStyle(
                fontFamily: 'DejaVuSansMono',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        const SizedBox(height: 10),
        Stack(alignment: Alignment.center, children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  border: Border.all(
                      color: isExpired ? Colors.red : Colors.blueAccent,
                      width: 2),
                  borderRadius: BorderRadius.circular(10)),
              child: Opacity(
                  opacity: isExpired ? 0.1 : 1.0,
                  child: Image.network(
                      "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${widget.orderId}",
                      height: 150,
                      width: 150))),
          if (isExpired)
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: Colors.red,
                child: const Text("EXPIRED",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)))
        ]),
        const SizedBox(height: 15),
        if (isExpired)
          const Text("Valid time limit exceeded.",
              style: TextStyle(color: Colors.red))
        else
          const Text("Show this at the exit gate.",
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 10),
        if (!isExpired) ...[
          const LinearProgressIndicator(
              color: Colors.blueAccent, backgroundColor: Colors.white),
          Text(waitingText,
              style: const TextStyle(color: Colors.blueAccent, fontSize: 10))
        ],
      ],
    );
  }

  Widget _buildSuccessUI() {
    return _buildStatusMessage(
        Icons.verified, "YOU MAY EXIT", "Verification Complete", successGreen);
  }

  // 🛡️ RECOVERY ENGINE UI: Guard Rejection Handler (PINAKA UPDATED)
  Widget _buildFailureUI(Map<String, dynamic> data, BuildContext context) {
    // 🚨 BUG FIX 2: FETCH DYNAMIC GUARD REASON
    String guardReason =
        data['rejectReason'] ?? "Items mismatch detected by Guard.";

    return Column(
      children: [
        _buildStatusMessage(
            Icons.report_problem,
            "EXIT STOPPED",
            "Reason: $guardReason\nPlease review your cart and fix the items.",
            alertRed),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: alertRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            icon: const Icon(Icons.shopping_cart, color: Colors.white),
            label: const Text("Fix & Re-Submit",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            onPressed: () async {
              // 🚀 BUG FIX 3: THE GHOST ORDER KILLER!
              // Purane failed order ko "SUPERSEDED" aur "isDeleted: true" mark karo
              // Taaki wo admin audit mein rahe, par user ki history se gayab ho jaye!
              try {
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(widget.orderId)
                    .update({
                  'exitStatus': 'RESOLVED_BY_USER',
                  'status': 'SUPERSEDED',
                  'isDeleted': true, // 🔥 MAGIC FLAG: Hides from Order History
                  'resolvedAt': FieldValue.serverTimestamp(),
                });
              } catch (e) {
                debugPrint("Ghost killer failed: $e");
              }

              // 🛒 ENGINE START: Switch to Correction Mode
              if (context.mounted) {
                final cart = Provider.of<CartService>(context, listen: false);
                await cart.loadOrderForCorrection(
                    widget.orderId, data['items']);

                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                      (route) => false);
                }
              }
            },
          ),
        )
      ],
    );
  }

  Widget _buildHeaderBackground(String status) {
    List<Color> colors;
    if (status == 'COMPLETED' || status == 'EXITED') {
      colors = [successGreen, Colors.greenAccent];
    } else if (status == 'REJECTED') {
      colors = [alertRed, Colors.redAccent];
    } else {
      colors = [cherryRedLight, cherryRedDark];
    }

    return Container(
        height: 280,
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30))));
  }

  Widget _buildStatusIcon(String status) {
    if (status == 'COMPLETED' || status == 'EXITED') {
      return const Icon(Icons.check_circle, color: Colors.white, size: 60);
    }
    if (status == 'REJECTED') {
      return const Icon(Icons.cancel, color: Colors.white, size: 60);
    }
    return const Icon(Icons.qr_code_scanner, color: Colors.white, size: 60);
  }

  String _getStatusTitle(String status) {
    if (status == 'COMPLETED' || status == 'EXITED') return "Exit Approved";
    if (status == 'REJECTED') return "Verification Failed";
    return "Gate Pass";
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontFamily: 'DejaVuSansMono'))
        ]));
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "";
    DateTime date =
        (timestamp is Timestamp) ? timestamp.toDate() : DateTime.now();
    return DateFormat('dd MMM, hh:mm a').format(date);
  }
}
