import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/orders/order_service.dart';
import '../services/cart/cart_service.dart';
import 'home_screen.dart';
import 'order_detail_screen.dart';

class PaymentQRScreen extends StatelessWidget {
  final String orderId;
  final double amount;

  const PaymentQRScreen(
      {super.key, required this.orderId, required this.amount});

  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<DocumentSnapshot>(
        stream: OrderService().getOrderStatusStream(orderId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.red));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final status =
              (data?['status'] ?? 'PENDING').toString().toUpperCase();
          final payStatus =
              (data?['paymentStatus'] ?? 'PENDING').toString().toUpperCase();

          DateTime? expiresAt = (data?['qrExpiresAt'] as Timestamp?)?.toDate();
          bool isExpired =
              expiresAt != null && DateTime.now().isAfter(expiresAt);

          // 🚨 AGAR 8 GHANTE POORE HO GAYE TOH SEEDHA BLOCK KARO
          if (isExpired && payStatus != 'PAID' && status != 'COMPLETED') {
            return _buildExpiredView(context);
          }

          // ✅ PAYMENT SUCCESS
          if (payStatus == 'PAID' || status == 'COMPLETED') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // 🚀 FIX: Safely wipe entire cart (handles both normal & correction mode safely)
              Provider.of<CartService>(context, listen: false).clearCart();
            });
            return _buildSuccessView(context);
          }

          return _buildQRView(context, expiresAt);
        },
      ),
    );
  }

  Widget _buildQRView(BuildContext context, DateTime? expiresAt) {
    return Stack(
      children: [
        Container(
          height: 350,
          width: double.infinity,
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [cherryRedLight, cherryRedDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40))),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    children: [
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 22)),
                      const Expanded(
                          child: Text("ClickOut",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontFamily: 'DejaVuSansMono',
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold))),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text("Cash Counter",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold)),
                const Text("Show this QR to the cashier",
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 220, left: 20, right: 20),
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10))
                  ]),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        border:
                            Border.all(color: Colors.blue.shade200, width: 2),
                        borderRadius: BorderRadius.circular(20)),
                    child: QrImageView(
                        data: orderId, version: QrVersions.auto, size: 200.0),
                  ),
                  const SizedBox(height: 15),

                  // ⏳ 8-HOUR VALIDITY BANNER
                  if (expiresAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.3))),
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
                                  fontSize: 12)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 15),
                  Text("Order ID: $orderId",
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 10),
                  const Text("Total Payable",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text("₹${amount.toStringAsFixed(0)}",
                      style: TextStyle(
                          color: cherryRedDark,
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'DejaVuSansMono')),
                  const SizedBox(height: 30),
                  const Text("Waiting for cashier confirmation...",
                      style: TextStyle(
                          color: Colors.black54, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  const LinearProgressIndicator(
                      backgroundColor: Color(0xFFEEEEEE),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                  const SizedBox(height: 25),

                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false),
                    icon:
                        const Icon(Icons.add_shopping_cart, color: Colors.grey),
                    label: const Text("Go Back & Continue Shopping",
                        style: TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 👻 THE AUTO-KILL SCREEN
  Widget _buildExpiredView(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.timer_off, color: Colors.red, size: 60)),
          const SizedBox(height: 30),
          const Text("QR EXPIRED",
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.red)),
          const SizedBox(height: 15),
          const Text(
              "This session was valid for 8 hours and has now expired.\n\nIt has been moved to your Black Box. Please create a new cart.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
          const SizedBox(height: 50),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false),
              child: const Text("GO TO HOME",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1.0)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 60)),
          const SizedBox(height: 30),
          const Text("PAYMENT SUCCESS!",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 50),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: cherryRedDark,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => OrderDetailScreen(orderId: orderId))),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner, color: Colors.white),
                    SizedBox(width: 10),
                    Text("VIEW GATE PASS",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18))
                  ]),
            ),
          )
        ],
      ),
    );
  }
}
