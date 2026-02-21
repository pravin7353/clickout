import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'order_detail_screen.dart';
import 'home_screen.dart';

class CashPaymentScreen extends StatefulWidget {
  final String orderId;
  final double totalAmount; // ✅ Yahan amount receive hoga

  const CashPaymentScreen(
      {super.key, required this.orderId, required this.totalAmount});

  @override
  State<CashPaymentScreen> createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends State<CashPaymentScreen> {
  // 🔥 Theme Colors
  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);

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
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var data = snapshot.data!.data() as Map<String, dynamic>?;
          String paymentStatus = data?['paymentStatus'] ?? 'PENDING';

          // 🔥 IF PAID -> REDIRECT AUTOMATICALLY
          if (paymentStatus == 'PAID') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          OrderDetailScreen(orderId: widget.orderId)));
            });
          }

          return Stack(
            children: [
              // 1. BACKGROUND HEADER
              Container(
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cherryRedLight, cherryRedDark],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Navbar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        child: Row(
                          children: [
                            IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const HomeScreen()),
                                  (route) => false),
                            ),
                            const Text(
                              "Cash Counter",
                              style: TextStyle(
                                fontFamily: 'DejaVuSansMono',
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Icon(Icons.storefront,
                          size: 60, color: Colors.white70),
                      const SizedBox(height: 10),
                      const Text(
                        "Show QR at Counter",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        "Please pay cash to the cashier",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. CARD CONTENT
              Padding(
                padding: const EdgeInsets.only(top: 220, left: 20, right: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // QR CODE
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: cherryRedLight.withOpacity(0.3), width: 2),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Image.network(
                          "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${widget.orderId}",
                          height: 200,
                          width: 200,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const SizedBox(
                                height: 200,
                                width: 200,
                                child:
                                    Center(child: CircularProgressIndicator()));
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.qr_code_2,
                                  size: 200, color: Colors.grey),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // AMOUNT
                      const Text(
                        "Total Payable",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      // ✅ YAHAN SAHI AMOUNT DIKHEGA
                      Text(
                        "₹${widget.totalAmount.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: cherryRedDark,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'DejaVuSansMono',
                        ),
                      ),

                      const SizedBox(height: 25),

                      // STATUS INDICATOR
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.orange),
                            ),
                            SizedBox(width: 10),
                            Text(
                              "Waiting for payment...",
                              style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
