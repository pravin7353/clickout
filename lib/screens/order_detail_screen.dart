import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/invoice/pdf_invoice_service.dart';
import '../services/cart/cart_service.dart';
import 'cart_screen.dart';

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
  final Color expiredPurple = Colors.purpleAccent; // 👻 The Black Box Color

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

          // 🕒 8-HOUR EXPIRY LOGIC ENGINE
          DateTime? expiresAt =
              (orderData['qrExpiresAt'] as Timestamp?)?.toDate();
          bool isExpired =
              expiresAt != null && DateTime.now().isAfter(expiresAt);
          bool isCleanExit = (exitStatus == 'COMPLETED' ||
              exitStatus == 'EXITED' ||
              exitStatus == 'APPROVED');

          // 🚀 THE LOOP FIX: Auto-Clear Cart on Guard Approval
          if (isCleanExit) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final cart = Provider.of<CartService>(context, listen: false);
              // 🔥 MASTER FIX: 'clear()' locked tha isliye crash ho gaya.
              // 'clearCart()' background system bypass hai jo forcefully sab saaf karega!
              if (cart.items.isNotEmpty || cart.isCorrectionMode) {
                cart.clearCart();
              }
            });
          }

          Widget content;

          if (orderStatus == 'DELETED' || orderStatus == 'CANCELLED') {
            content = _buildStatusMessage(Icons.delete_forever, "ORDER DELETED",
                "This order is no longer valid.", Colors.grey);
          }
          // 🚨 THE TREMENDOUS 8-HOUR AUTO-KILL SWITCH
          else if (!isCleanExit &&
              (isExpired ||
                  exitStatus == 'EXPIRED_BY_SYSTEM' ||
                  orderStatus == 'EXPIRED')) {
            content = _buildAutoKillUI();
            exitStatus = 'EXPIRED'; // Force header update
          } else if (paymentStatus != 'PAID') {
            content = _buildUnpaidUI();
          } else if (exitStatus == 'PENDING' ||
              exitStatus == 'READY_FOR_EXIT') {
            content = _buildGatePassUI(orderData, expiresAt);
          }
          // 🟢 100% GREEN SUCCESS CHECK
          else if (isCleanExit) {
            content = _buildSuccessUI();
          }
          // 🔴 100% RED FAILURE CHECK
          else if (exitStatus == 'REJECTED') {
            content = _buildFailureUI(orderData, context);
          } else {
            content = _buildGatePassUI(orderData, expiresAt);
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
                      if (paymentStatus == 'PAID' &&
                          orderStatus != 'DELETED' &&
                          !isExpired)
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
                          onPressed: () {
                            if (isCleanExit) {
                              // 🚀 FIX: Agar Gate Pass approve ho gaya, toh back dabane par
                              // wapas Cart/Payment pe jane ke bajaye seedha Home pe feko!
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            } else {
                              Navigator.pop(context);
                            }
                          }))),
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

  // 👻 THE EXPIRED UI
  Widget _buildAutoKillUI() {
    return Column(children: [
      const Icon(Icons.timer_off, size: 80, color: Colors.purpleAccent),
      const SizedBox(height: 10),
      const Text("GATE PASS EXPIRED",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: Colors.purpleAccent)),
      const SizedBox(height: 15),
      const Text(
          "This gate pass was valid for 8 hours and has now expired. It has been secured in the Black Box.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, height: 1.5)),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text("GO TO HOME",
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      )
    ]);
  }

  Widget _buildUnpaidUI() {
    return _buildStatusMessage(Icons.warning_amber_rounded, "PAYMENT PENDING",
        "Please pay at the cash counter to generate Gate Pass.", Colors.orange);
  }

  Widget _buildGatePassUI(Map<String, dynamic> data, DateTime? expiresAt) {
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
        const SizedBox(height: 15),

        // ⏳ 8-HOUR VALIDITY BANNER
        if (expiresAt != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer_outlined,
                    color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Text(
                  "Valid till: ${DateFormat('hh:mm a').format(expiresAt)}",
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 2),
                borderRadius: BorderRadius.circular(10)),
            child: Image.network(
                "https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${widget.orderId}",
                height: 150,
                width: 150)),
        const SizedBox(height: 15),
        const Text("Show this at the exit gate.",
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 10),
        const LinearProgressIndicator(
            color: Colors.blueAccent, backgroundColor: Colors.white),
        Text(waitingText,
            style: const TextStyle(color: Colors.blueAccent, fontSize: 10)),
      ],
    );
  }

  Widget _buildSuccessUI() {
    return _buildStatusMessage(
        Icons.verified, "YOU MAY EXIT", "Verification Complete", successGreen);
  }

  Widget _buildFailureUI(Map<String, dynamic> data, BuildContext context) {
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
              try {
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(widget.orderId)
                    .update({
                  'exitStatus': 'RESOLVED_BY_USER',
                  'status': 'SUPERSEDED', // Marks old order as dead
                  'isDeleted': true,
                  'resolvedAt': FieldValue.serverTimestamp(),
                });
              } catch (e) {
                debugPrint("Correction switch failed: $e");
              }

              if (context.mounted) {
                final cart = Provider.of<CartService>(context, listen: false);
                // 🚀 THE HOLD FIX: Cart is already intact in local memory!
                // We just need to unlock the UI for editing and attach the old orderId
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
    if (status == 'COMPLETED' || status == 'EXITED' || status == 'APPROVED') {
      colors = [successGreen, Colors.greenAccent];
    } else if (status == 'REJECTED') {
      colors = [alertRed, Colors.redAccent];
    } else if (status == 'EXPIRED') {
      colors = [expiredPurple, Colors.deepPurple];
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
    if (status == 'COMPLETED' || status == 'EXITED' || status == 'APPROVED') {
      return const Icon(Icons.check_circle, color: Colors.white, size: 60);
    }
    if (status == 'REJECTED') {
      return const Icon(Icons.cancel, color: Colors.white, size: 60);
    }
    if (status == 'EXPIRED') {
      return const Icon(Icons.auto_delete, color: Colors.white, size: 60);
    }
    return const Icon(Icons.qr_code_scanner, color: Colors.white, size: 60);
  }

  String _getStatusTitle(String status) {
    if (status == 'COMPLETED' || status == 'EXITED' || status == 'APPROVED') {
      return "Exit Approved";
    }
    if (status == 'REJECTED') return "Verification Failed";
    if (status == 'EXPIRED') return "Gate Pass Expired";
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
