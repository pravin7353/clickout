import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/invoice/pdf_invoice_service.dart';
import '../services/cart/cart_service.dart';
import '../services/gate/gatepass_service.dart';
import 'cart_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  final Color expiredPurple = Colors.blueGrey;
  final Color fixExitedPurple =
      const Color(0xFF8E24AA); // 🚀 Naya Color Fix & Exited k liye

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

          DateTime? expiresAt =
              (orderData['qrExpiresAt'] as Timestamp?)?.toDate();

          // 🚀 LOGIC FIX: Frontend time issue fixed. Now relies strictly on Backend Status
          bool isExpired = (exitStatus == 'EXPIRED' ||
              exitStatus == 'EXPIRED_BY_SYSTEM' ||
              orderStatus == 'EXPIRED');

          bool wasEverRejected = orderData['wasEverRejected'] == true;
          bool isConsumed = orderData['qrConsumed'] == true;

          // 🚀 THE FIX: Treat 'qrConsumed' as a successful exit (if not rejected) so it shows "Clear Exit" instead of the grey "Gate Pass Used"
          bool isExitComplete = (exitStatus == 'COMPLETED' ||
              exitStatus == 'EXITED' ||
              exitStatus == 'APPROVED' ||
              (isConsumed && exitStatus != 'REJECTED'));

          bool isCleanExit = isExitComplete && !wasEverRejected;
          bool isFixAndExited = isExitComplete && wasEverRejected;

          // Auto-Clear Cart on Guard Approval
          if (isExitComplete) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final cart = Provider.of<CartService>(context, listen: false);
              if (cart.items.isNotEmpty || cart.isCorrectionMode) {
                cart.clearCart(
                    force:
                        true); // 🔓 SYSTEM BYPASS: Guard ne approve kar diya hai!
              }
            });
          }

          Widget content;
          String visualStatus = exitStatus;

          // 🚀 BUG 2 FIX: isExpired check moved UP! So expired orders don't fall into wrong UI.
          if (orderStatus == 'DELETED' || orderStatus == 'CANCELLED') {
            content = _buildStatusMessage(Icons.delete_forever, "ORDER DELETED",
                "This order is no longer valid.", Colors.grey);
          } else if (isExpired) {
            visualStatus = 'EXPIRED';
            content = _buildAutoKillUI();
          } else if (paymentStatus != 'PAID') {
            content = _buildUnpaidUI();
          } else if (isCleanExit) {
            visualStatus = 'COMPLETED';
            content = _buildSuccessUI();
          } else if (isFixAndExited) {
            visualStatus = 'FIX_EXITED';
            content = _buildFixExitedUI();
          } else if (exitStatus == 'REJECTED') {
            content = _buildFailureUI(orderData, context);
          } else {
            content = _buildGatePassUI(orderData, expiresAt);
          }

          return Stack(
            children: [
              _buildHeaderBackground(visualStatus),
              SafeArea(
                child: Center(
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildStatusIcon(visualStatus),
                      const SizedBox(height: 10),
                      Text(_getStatusTitle(visualStatus),
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
                            const SizedBox(height: 15),

                            // 🚀 NEW DETAILED ORDER SUMMARY
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(10)),
                              child: _buildOrderSummary(orderData),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 🚀 DOWNLOAD INVOICE BUTTON
                      if (paymentStatus == 'PAID' &&
                          orderStatus != 'DELETED' &&
                          !isExpired)
                        SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black87,
                                    side:
                                        BorderSide(color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                icon: const Icon(Icons.picture_as_pdf_rounded,
                                    color: Colors.redAccent),
                                label: const Text("📄 View / Download Invoice",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
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
                            // 🚀 NAV FIX: Always pop to return to the history list smoothly
                            Navigator.pop(context);
                          }))),
            ],
          );
        },
      ),
    );
  }

  // 🧾 NEW ORDER SUMMARY BUILDER
  Widget _buildOrderSummary(Map<String, dynamic> data) {
    List<dynamic> items = data['items'] ?? [];
    double subtotal = 0;
    double savings = 0;
    double totalPaid =
        double.tryParse(data['totalAmount']?.toString() ?? '0') ?? 0;

    List<Widget> itemWidgets = items.map((item) {
      // 🚀 BUG 4 FIX: Syncing exact variable names with cart_service!
      double oldPrice = double.tryParse(item['originalPrice']?.toString() ??
              item['price']?.toString() ??
              '0') ??
          0;
      double newPrice = double.tryParse(item['finalUnitPrice']?.toString() ??
              item['discountPrice']?.toString() ??
              oldPrice.toString()) ??
          0;
      int qty = int.tryParse(
              item['quantity']?.toString() ?? item['qty']?.toString() ?? '1') ??
          1;

      subtotal += (oldPrice * qty);
      savings += ((oldPrice - newPrice) * qty);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text("${qty}x ${item['name']}",
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 10),
            Text("₹${(newPrice * qty).toStringAsFixed(0)}",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("ORDER SUMMARY",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.grey,
                    letterSpacing: 1)),
            Text(_formatDate(data['timestamp']),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        const Divider(height: 20),
        ...itemWidgets,
        const Divider(height: 20),
        _buildDetailRow("Subtotal", "₹${subtotal.toStringAsFixed(0)}"),
        if (savings > 0)
          _buildDetailRow("Total Savings", "-₹${savings.toStringAsFixed(0)}",
              textColor: successGreen),
        const SizedBox(height: 8),
        _buildDetailRow("Grand Total", "₹${totalPaid.toStringAsFixed(0)}",
            isBold: true, size: 16),
      ],
    );
  }

  Widget _buildStatusMessage(
      IconData icon, String title, String sub, Color color) {
    return Column(children: [
      Icon(icon, size: 80, color: color),
      const SizedBox(height: 10),
      Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: color,
              letterSpacing: 0.5)),
      const SizedBox(height: 5),
      Text(sub,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 13))
    ]);
  }

  Widget _buildAutoKillUI() {
    return Column(children: [
      const Icon(Icons.timer_off, size: 80, color: Colors.blueGrey),
      const SizedBox(height: 10),
      const Text("GATE PASS EXPIRED",
          style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: Colors.blueGrey)),
      const SizedBox(height: 15),
      const Text(
          "This gate pass has expired. Contact Store Manager to Reactivate it.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, height: 1.5)),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        height: 45,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueGrey,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            // 🚀 NAV FIX: Simply pop back to the history list
            Navigator.pop(context);
          },
          child: const Text("BACK TO ORDERS",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1)),
        ),
      )
    ]);
  }

  Widget _buildUnpaidUI() {
    return Column(
      children: [
        const Text("PAYMENT PENDING",
            style: TextStyle(
                fontFamily: 'DejaVuSansMono',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
                letterSpacing: 1.5)),
        const SizedBox(height: 15),

        // 🚀 THE FIX: Bring back the QR Code for Cashier Scanning
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.orange, width: 2),
                borderRadius: BorderRadius.circular(10)),
            // 🚀 FIX: Cashier App ko sirf raw Order ID chahiye!
            child: QrImageView(
              data: widget.orderId, // 👈 YAHAN CHANGE KIYA HAI
              version: QrVersions.auto,
              size: 150.0,
            )),
        const SizedBox(height: 15),

        const Text("Show this QR at the Cash Counter to pay.",
            style: TextStyle(
                color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        const LinearProgressIndicator(
            color: Colors.orange, backgroundColor: Colors.white),
        const SizedBox(height: 5),
        const Text("Awaiting Payment at Counter...",
            style: TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      ],
    );
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

    // 🚀 THE MASTERSTROKE FIX: Generate Highly Secure QR Data
    String secureQrData = GatePassService().generateSecureQRData(
      orderId: widget.orderId,
      userId: currentUserId ?? 'UNKNOWN',
      gatePassVersion: data['gatePassVersion'] ?? 1,
    );

    // 🚀 THE FIX: Make Base64 safe for URL!
    String encodedQrData = Uri.encodeComponent(secureQrData);

    return Column(
      children: [
        const Text("GATE PASS",
            style: TextStyle(
                fontFamily: 'DejaVuSansMono',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2)),
        const SizedBox(height: 15),
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
                Text("Valid till: ${DateFormat('hh:mm a').format(expiresAt)}",
                    style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
          ),
        const SizedBox(height: 20),

        // 🚀 SECURE QR DISPLAY
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 2),
                borderRadius: BorderRadius.circular(10)),
            // 🚀 OFFLINE INSTANT QR GENERATION
            child: QrImageView(
              data: secureQrData, // Yahan encode karne ki zaroorat nahi!
              version: QrVersions.auto,
              size: 150.0,
            )),

        const SizedBox(height: 15),
        const Text("Show this at the exit gate.",
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 10),
        const LinearProgressIndicator(
            color: Colors.blueAccent, backgroundColor: Colors.white),
        Text(waitingText,
            style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSuccessUI() {
    return _buildStatusMessage(Icons.verified, "CLEAR EXIT",
        "Verification Complete. Thanks for shopping!", successGreen);
  }

  // 🚀 NAYA UI: FIX AND EXITED
  Widget _buildFixExitedUI() {
    return _buildStatusMessage(
        Icons.published_with_changes_rounded,
        "FIX & EXITED",
        "Order was corrected at the gate and successfully exited.",
        fixExitedPurple);
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
                  'status': 'SUPERSEDED',
                  'isDeleted': true,
                  'resolvedAt': FieldValue.serverTimestamp(),
                });
              } catch (e) {
                debugPrint("Correction switch failed: $e");
              }
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
    if (status == 'COMPLETED' || status == 'EXITED' || status == 'APPROVED') {
      colors = [successGreen, Colors.greenAccent.shade700];
    } else if (status == 'FIX_EXITED') {
      colors = [fixExitedPurple, Colors.purpleAccent];
    } else if (status == 'REJECTED') {
      colors = [alertRed, Colors.redAccent];
    } else if (status == 'EXPIRED') {
      colors = [expiredPurple, Colors.blueGrey.shade300];
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
    if (status == 'FIX_EXITED') {
      return const Icon(Icons.published_with_changes_rounded,
          color: Colors.white, size: 60);
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
    if (status == 'COMPLETED' || status == 'EXITED' || status == 'APPROVED')
      return "Clear Exit";
    if (status == 'FIX_EXITED') return "Fix & Exited";
    if (status == 'REJECTED') return "Verification Failed";
    if (status == 'EXPIRED') return "Gate Pass Expired";
    return "Gate Pass";
  }

  Widget _buildDetailRow(String label, String value,
      {Color textColor = Colors.black87,
      bool isBold = false,
      double size = 13}) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  color: isBold ? Colors.black87 : Colors.grey,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  fontSize: size)),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: size,
                  color: textColor,
                  fontFamily: 'DejaVuSansMono'))
        ]));
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "";
    DateTime date =
        (timestamp is Timestamp) ? timestamp.toDate() : DateTime.now();
    return DateFormat('dd MMM, hh:mm a').format(date);
  }
}
