import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart'; // 🚀 ADDED RAZORPAY
import '../services/orders/order_service.dart';
import '../services/cart/cart_service.dart';
import '../services/payment/razorpay_service.dart';
import '../services/payment/phonepe_service.dart'; // 🚀 ADDED PHONEPE SERVICE
import 'home_screen.dart';
import 'order_detail_screen.dart';
import '../utils/user_session.dart';

// 🚀 CHANGED TO STATEFUL WIDGET FOR RAZORPAY LISTENERS
//import 'package:url_launcher/url_launcher.dart'; // 🚀 IMPORT ZAROORI HAI

class UpiPaymentScreen extends StatefulWidget {
  final String orderId;
  final double amount;
  final String paymentType; // 🚀 NAYA FLAG

  const UpiPaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
    this.paymentType = 'upi', // Default UPI rahega
  });

  @override
  State<UpiPaymentScreen> createState() => _UpiPaymentScreenState();
}

class _UpiPaymentScreenState extends State<UpiPaymentScreen> {
  // 🍒 THE BEAUTIFUL CLICKOUT THEME COLORS
  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);

  // 🚀 GATEWAY INSTANCES
  final RazorpayService _razorpayService = RazorpayService();
  final PhonePeService _phonePeService =
      PhonePeService(); // 🟢 Naya PhonePe Service
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // 🧑‍🏫 RAZORPAY STARTUP
    _razorpayService.initializeRazorpay(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentError,
    );
    // 🟢 PHONEPE STARTUP
    _phonePeService.initPhonePe();
  }

  @override
  void dispose() {
    // 🧑‍🏫 CLEANUP: Jab screen band ho toh Razorpay ko memory se hata do
    _razorpayService.dispose();
    super.dispose();
  }

  // 🟢 SUCCESS HANDLER: Paisa mil gaya! Firebase update karo
  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({
        'paymentStatus': 'PAID',
        'status': 'completed',
        'exitStatus': 'READY_FOR_EXIT',
        'razorpayPaymentId':
            response.paymentId, // 🧾 Receipt number save kar lo
      });

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Payment Successful! ✅"),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Firebase update failed: $e");
    }
  }

  // 🔴 ERROR HANDLER: User ne back daba diya ya card fail hua
  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Payment Failed or Cancelled: ${response.message}"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // 🚀 THE NEW CHECKOUT ENGINE (Gets Store Name & Opens Popup)
  Future<void> _processRazorpayCheckout(Map<String, dynamic> orderData) async {
    setState(() => _isProcessing = true);

    try {
      final String? storeId = orderData['storeId'];
      if (storeId == null) throw "Store ID missing.";

      // Fetch Store Name for the Razorpay Popup UI
      final db = FirebaseFirestore.instance;
      String storeName = "ClickOut Store";

      var storeDoc = await db.collection('stores').doc(storeId).get();
      if (storeDoc.exists && storeDoc.data() != null) {
        storeName = storeDoc.data()!['storeName'] ?? storeName;
      } else {
        var storeQuery = await db
            .collection('stores')
            .where('branchCode', isEqualTo: storeId)
            .limit(1)
            .get();
        if (storeQuery.docs.isNotEmpty) {
          storeName = storeQuery.docs.first.data()['storeName'] ?? storeName;
        }
      }

      // 🧑‍🏫 OPEN CHECKOUT: Service call kardi! Ab screen pe popup aayega
      _razorpayService.openCheckout(
        amount: widget.amount,
        orderId: widget.orderId,
        storeName: storeName,
        contactNumber: "9999999999", // Replace with actual customer phone later
      );
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<DocumentSnapshot>(
        stream: OrderService().getOrderStatusStream(widget.orderId),
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

          if (isExpired && payStatus != 'PAID' && status != 'COMPLETED') {
            return _buildExpiredView(context);
          }

          if (payStatus == 'PAID' || status == 'COMPLETED') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Provider.of<CartService>(context, listen: false).clearCart();
            });
            return _buildSuccessView(context);
          }

          return _buildUpiView(context, expiresAt, data ?? {});
        },
      ),
    );
  }

  Widget _buildUpiView(BuildContext context, DateTime? expiresAt,
      Map<String, dynamic> orderData) {
    return Stack(
      children: [
        // 🚀 HEADER
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
                const Text("Secure Checkout",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold)),
                const Text("Pay via UPI, Cards, or Netbanking",
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ),
        // 🚀 CARD
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
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: cherryRedLight.withOpacity(0.1),
                        shape: BoxShape.circle),
                    child: Icon(Icons.security,
                        size: 80,
                        color: cherryRedDark), // Changed Icon to Security
                  ),
                  const SizedBox(height: 15),

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
                  Text("Order ID: ${widget.orderId}",
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 10),
                  const Text("Total Payable",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 5),
                  Text("₹${widget.amount.toStringAsFixed(0)}",
                      style: TextStyle(
                          color: cherryRedDark,
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'DejaVuSansMono')),
                  const SizedBox(height: 30),

                  // 💰 SMART DYNAMIC BUTTON (UPI vs CARD)
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: cherryRedDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15))),
                      onPressed: _isProcessing
                          ? null
                          : () {
                              if (widget.paymentType == 'card') {
                                _processRazorpayCheckout(
                                    orderData); // 💳 2% Fee wala Razorpay
                              } else {
                                _processRealUpiPayment(
                                    orderData); // 🚀 0% Fee wala Direct GPay
                              }
                            },
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.payment, color: Colors.white),
                      label: Text(
                          _isProcessing
                              ? "PROCESSING..."
                              : (widget.paymentType == 'card'
                                  ? "PAY VIA CARD"
                                  : "PAY VIA UPI APP"),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.0)),
                    ),
                  ),

                  const SizedBox(height: 15),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (route) => false),
                    icon: const Icon(Icons.close, color: Colors.grey),
                    label: const Text("Cancel & Go Back",
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
          const Text("SESSION EXPIRED",
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.red)),
          const SizedBox(height: 15),
          const Text(
              "This session was valid for 8 hours and has now expired.\n\nPlease create a new cart to proceed.",
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
                          letterSpacing: 1.0)))),
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
                          builder: (_) =>
                              OrderDetailScreen(orderId: widget.orderId))),
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
                      ]))),
        ],
      ),
    );
  }

  // 🟢 NEW PHONEPE PAYMENT CALLER (Zero Commission UPI)
  Future<void> _processRealUpiPayment(Map<String, dynamic> orderData) async {
    setState(() => _isProcessing = true);

    await _phonePeService.startPayment(
      context: context,
      amount: widget.amount,
      orderId: widget.orderId,
      tenantId: UserSession.tenantId, // 🔒 ADDED
      storeId: UserSession.storeId, // 🔒 ADDED
      onCompletion: (status, message) async {
        if (status == 'SUCCESS') {
          // 🛑 WAIT! Turant Firebase update mat karo.
          // Pehle double check karo PhonePe server se!
          setState(() => _isProcessing = true);

          bool isRealSuccess =
              await _phonePeService.checkPaymentStatus(widget.orderId);

          if (isRealSuccess) {
            // 🟢 ASLI SUCCESS: Ab Firebase update karo
            try {
              await FirebaseFirestore.instance
                  .collection('orders')
                  .doc(widget.orderId)
                  .update({
                'paymentStatus': 'PAID',
                'status': 'completed',
                'exitStatus': 'READY_FOR_EXIT',
                'paymentGateway': 'PHONEPE_UPI',
              });

              if (mounted) {
                setState(() => _isProcessing = false);
                // ... aage ka navigation code (agar koi hai) ...
              }
            } catch (e) {
              if (mounted) setState(() => _isProcessing = false);
              debugPrint("Order Update Error: $e");
            }
          } else {
            if (mounted) {
              setState(() => _isProcessing = false);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Payment verification failed!"),
                  backgroundColor: Colors.red));
            }
          }
        } else {
          if (mounted) {
            setState(() => _isProcessing = false);
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message), backgroundColor: Colors.red));
          }
        }
      },
    );
  }
}
