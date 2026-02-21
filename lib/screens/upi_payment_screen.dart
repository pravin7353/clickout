import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';
import '../services/upi_service.dart'; // ✅ New Service Included
import 'order_detail_screen.dart';

class UpiPaymentScreen extends StatefulWidget {
  final String orderId;
  final double amount;

  const UpiPaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
  });

  @override
  State<UpiPaymentScreen> createState() => _UpiPaymentScreenState();
}

class _UpiPaymentScreenState extends State<UpiPaymentScreen> {
  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);

  String merchantName = "Loading...";
  String gpayId = "";
  String paytmId = "";
  String phonePeId = "";
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _fetchMerchantDetails();
  }

  Future<void> _fetchMerchantDetails() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('store_config')
          .doc('payment_details')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          merchantName = data['merchantName'] ?? "ClickOut Merchant";
          gpayId = data['gpayId'] ?? "";
          paytmId = data['paytmId'] ?? "";
          phonePeId = data['phonepeId'] ?? "";
          _isLoadingData = false;
        });
      } else {
        _useDefaultDetails();
      }
    } catch (e) {
      debugPrint("Error fetching config: $e");
      _useDefaultDetails();
    }
  }

  void _useDefaultDetails() {
    if (!mounted) return;
    setState(() {
      merchantName = "Pravin Kumar Jaiswal";
      gpayId = "jaiswal.pravin415-1@okicici";
      paytmId = "9323137353@ptyes";
      phonePeId = "jaiswal.pravin4151@ybl";
      _isLoadingData = false;
    });
  }

  // 🚀 THE NATIVE LAUNCHER FUNCTION
  Future<void> _launchUPI(
      String appName, String upiId, SupportedUpiApp targetApp) async {
    try {
      await UpiService.initiatePayment(
        upiId: upiId,
        merchantName: merchantName,
        amount: widget.amount,
        orderId: widget.orderId,
        app: targetApp,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: cherryRedDark,
            behavior: SnackBarBehavior.floating, // Premium UI
          ),
        );
      }
    }
  }

  Future<void> _markOrderAsPaid() async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .update({'status': 'PAID'});

      if (mounted) {
        Provider.of<CartService>(context, listen: false).clear();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: widget.orderId),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating order: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text("Pay Online",
            style: TextStyle(fontFamily: 'DejaVuSansMono')),
        backgroundColor: cherryRedDark,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator(color: cherryRedDark))
          : Column(
              children: [
                // 1. AMOUNT HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: cherryRedDark,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text("Total Payable",
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 5),
                      Text(
                        "₹${widget.amount.toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'DejaVuSansMono'),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text("Paying to: $merchantName",
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                const Text("Select App to Pay",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 20),

                // 2. UPI APP BUTTONS WITH NEW ENUMS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildUpiButton(
                        "GPay",
                        "assets/icons/gpay.png",
                        Colors.blue,
                        () => _launchUPI(
                            "Google Pay", gpayId, SupportedUpiApp.gpay)),
                    _buildUpiButton(
                        "PhonePe",
                        "assets/icons/phonepe.png",
                        Colors.purple,
                        () => _launchUPI(
                            "PhonePe", phonePeId, SupportedUpiApp.phonepe)),
                    _buildUpiButton(
                        "Paytm",
                        "assets/icons/paytm.png",
                        Colors.lightBlueAccent,
                        () => _launchUPI(
                            "Paytm", paytmId, SupportedUpiApp.paytm)),
                  ],
                ),

                const Spacer(),

                // 3. MANUAL CONFIRMATION
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: Column(
                    children: [
                      const Text(
                        "After payment, click the button below:",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, // Green for Success
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _markOrderAsPaid,
                          child: const Text("I HAVE COMPLETED PAYMENT",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }

  Widget _buildUpiButton(
      String name, String iconPath, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 10)
              ],
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Image.asset(iconPath,
                  errorBuilder: (c, o, s) =>
                      Icon(Icons.account_balance_wallet, color: color)),
            ),
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
