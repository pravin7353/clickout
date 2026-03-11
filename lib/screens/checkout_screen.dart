import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:provider/provider.dart';
import '../services/cart/cart_service.dart';
import '../services/orders/order_service.dart';
import 'payment_qr_screen.dart';
import 'upi_payment_screen.dart';

// 🧠 THE SINGLE SOURCE OF TRUTH
enum PaymentMethod { upi, cash, card }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = false;

  // ✅ INITIAL STATE FIX
  PaymentMethod _selectedPayment = PaymentMethod.upi;

  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Stack(
        children: [
          Container(
            height: 200,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          "ClickOut",
                          style: TextStyle(
                            fontFamily: 'DejaVuSansMono',
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    "Checkout",
                    style: TextStyle(
                      fontFamily: 'DejaVuSansMono',
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 160),
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: cherryRedDark))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5)),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text("Total to Pay",
                                  style: TextStyle(
                                      fontFamily: 'DejaVuSansMono',
                                      color: Colors.grey,
                                      fontSize: 16)),
                              const SizedBox(height: 5),
                              Text(
                                "Rs ${cart.grandTotal.toStringAsFixed(0)}",
                                style: TextStyle(
                                  fontFamily: 'DejaVuSansMono',
                                  color: cherryRedDark,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),

                        // 🚀 THE FIX: UI SHIELD FOR CORRECTION MODE
                        if (cart.isCorrectionMode) ...[
                          Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(15),
                                border:
                                    Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(children: [
                                const Icon(Icons.verified_user,
                                    color: Colors.green, size: 30),
                                const SizedBox(width: 15),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      const Text("Payment Verified",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                              fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text(
                                          "You have already paid for this order. Proceed to generate your revised Gate Pass.",
                                          style: TextStyle(
                                              color: Colors.green.shade800,
                                              fontSize: 12)),
                                    ]))
                              ])),
                          const SizedBox(height: 40),
                        ] else ...[
                          const Text("Select Payment Method",
                              style: TextStyle(
                                  fontFamily: 'DejaVuSansMono',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          const SizedBox(height: 15),
                          _buildPaymentOption(
                              icon: Icons.qr_code_2,
                              title: "Pay by any UPI app",
                              subtitle: "GPay, PhonePe, Paytm",
                              method: PaymentMethod.upi,
                              activeColor: cherryRedDark,
                              isUpi: true),
                          const SizedBox(height: 10),
                          _buildPaymentOption(
                              icon: Icons.money,
                              title: "Pay Via Cash",
                              subtitle: "Pay at counter",
                              method: PaymentMethod.cash,
                              activeColor: cherryRedDark),
                          const SizedBox(height: 10),
                          _buildPaymentOption(
                              icon: Icons.credit_card,
                              title: "Debit / Credit Card",
                              subtitle: "Visa, Mastercard, Rupay",
                              method: PaymentMethod.card,
                              activeColor: cherryRedDark),
                          const SizedBox(height: 40),
                        ],

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cart.isCorrectionMode
                                  ? Colors.green
                                  : cherryRedDark,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 5,
                            ),
                            onPressed: () => _handlePayment(context, cart),
                            child: Text(
                                cart.isCorrectionMode
                                    ? "GENERATE GATE PASS"
                                    : "PAY NOW",
                                style: const TextStyle(
                                    fontFamily: 'DejaVuSansMono',
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required PaymentMethod method,
    required Color activeColor,
    bool isUpi = false,
  }) {
    bool isSelected = _selectedPayment == method;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact(); // 📱 Subtle feedback
        setState(() => _selectedPayment = method);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: isSelected ? activeColor : Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withOpacity(0.1)
                      : Colors.grey[100],
                  shape: BoxShape.circle),
              child: Icon(icon,
                  color: isSelected ? activeColor : Colors.grey, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isSelected
                                  ? Colors.black
                                  : Colors.grey[700])),
                      if (isUpi) const SizedBox(width: 8),
                    ],
                  ),
                  Text(subtitle,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: activeColor),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayment(BuildContext context, CartService cart) async {
    setState(() => _isLoading = true);
    List<String> validationWarnings = await cart.validateCart();

    if (validationWarnings.isNotEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showValidationAlert(validationWarnings);
      }
      return;
    }
    _placeOrder(cart);
  }

  void _showValidationAlert(List<String> warnings) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 10),
          Text("Order Update")
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Some items in your cart have changed:"),
            const SizedBox(height: 10),
            ...warnings
                .map((w) => Text("• $w", style: const TextStyle(fontSize: 13))),
          ],
        ),
        actions: [
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: cherryRedDark),
              onPressed: () => Navigator.pop(context),
              child: const Text("OK, Review",
                  style: TextStyle(color: Colors.white)))
        ],
      ),
    );
  }

  // 🚀 PERFECT DYNAMIC ROUTING
  void _placeOrder(CartService cart) async {
    try {
      HapticFeedback.mediumImpact();
      final items = cart.items.values.map((item) => item.toJson()).toList();
      final double orderTotal = cart.grandTotal;

      String modeString = _selectedPayment.name.toUpperCase();

      final orderId = await OrderService().createOrUpdateOrder(
        items: items,
        totalAmount: orderTotal,
        gstTotal: cart.totalGST,
        paymentMode: modeString,
        correctionOrderId:
            cart.correctionOrderId, // 🚀 THE MISSING LINK PASSED TO BACKEND!
      );

      if (mounted) {
        setState(() => _isLoading = false);

        // 🚀 THE FIX: BYPASS PAYMENT SCREENS COMPLETELY IF IT'S A CORRECTION
        if (cart.isCorrectionMode) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PaymentQRScreen(orderId: orderId, amount: orderTotal)));
          return;
        }

        // 🔀 DYNAMIC NAVIGATION BASED ON STATE FOR NORMAL FLOW
        if (_selectedPayment == PaymentMethod.upi) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      UpiPaymentScreen(orderId: orderId, amount: orderTotal)));
        } else if (_selectedPayment == PaymentMethod.cash) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PaymentQRScreen(orderId: orderId, amount: orderTotal)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  "Card Payments coming soon! Redirecting to Cash flow...")));
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PaymentQRScreen(orderId: orderId, amount: orderTotal)));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red));
      }
    }
  }
}
