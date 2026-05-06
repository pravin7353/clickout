import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_detail_screen.dart';
import '../../services/system/auto_heal_service.dart';
import '../utils/user_session.dart';

class ActiveGatePassScreen extends StatefulWidget {
  const ActiveGatePassScreen({super.key});

  @override
  State<ActiveGatePassScreen> createState() => _ActiveGatePassScreenState();
}

class _ActiveGatePassScreenState extends State<ActiveGatePassScreen> {
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  final bool isGlobal = UserSession.tenantId.isEmpty;

  @override
  void initState() {
    super.initState();
    if (userId != null) {
      AutoHealService().healCorruptedOrders(userId!);
    }
  }

  Stream<QuerySnapshot> _getOrdersStream() {
    // 🚀 SAFE QUERY: No extra filters to avoid Firebase Composite Index Errors
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Active Gate Passes",
          style: GoogleFonts.syne(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: const Color(0xFF111827)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF3F4F6), height: 1),
        ),
      ),
      body: userId == null
          ? Center(child: Text("Please log in.", style: GoogleFonts.dmSans()))
          : StreamBuilder<QuerySnapshot>(
              stream: _getOrdersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF111827)));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                List<QueryDocumentSnapshot> allDocs = snapshot.data!.docs;

                // 🚀 LOCAL FILTER: Store mode bypasses Firebase Index Error
                if (!isGlobal) {
                  allDocs = allDocs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return data['storeId'] == UserSession.storeId;
                  }).toList();
                }

                List<QueryDocumentSnapshot> activeDocs = [];

                for (var doc in allDocs) {
                  var data = doc.data() as Map<String, dynamic>;
                  String e =
                      (data['exitStatus'] ?? '').toString().toUpperCase();
                  String s = (data['status'] ?? '').toString().toUpperCase();
                  bool isConsumed = data['qrConsumed'] == true;

                  bool isRejected = e == 'REJECTED';
                  bool isExpired = e == 'EXPIRED' ||
                      e == 'EXPIRED_BY_SYSTEM' ||
                      s == 'EXPIRED';
                  bool isDeleted = s == 'DELETED' || s == 'CANCELLED';
                  bool isCompleted =
                      e == 'EXITED' || e == 'APPROVED' || e == 'COMPLETED';

                  // 🚀 ULTIMATE ACTIVE RULE
                  bool isActive = !isExpired &&
                      !isDeleted &&
                      (isRejected || (!isCompleted && !isConsumed));

                  if (isActive) {
                    activeDocs.add(doc);
                  }
                }

                if (activeDocs.isEmpty) return _buildEmptyState();

                return ListView(
                  padding: const EdgeInsets.only(top: 15, bottom: 30),
                  children: activeDocs
                      .map((doc) => _buildActiveOrderCard(doc))
                      .toList(),
                );
              },
            ),
    );
  }

  Widget _buildActiveOrderCard(QueryDocumentSnapshot doc) {
    var order = doc.data() as Map<String, dynamic>;
    final String orderId = doc.id;
    final String shortId = orderId.length > 6
        ? orderId.substring(orderId.length - 6).toUpperCase()
        : orderId;
    final double amount =
        double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0.0;

    final String exitStatus =
        (order['exitStatus'] ?? '').toString().toUpperCase();
    final String payStatus =
        (order['paymentStatus'] ?? '').toString().toUpperCase();

    String statusText = "Payment Pending";
    Color statusColor = const Color(0xFFF59E0B);
    Color statusBg = const Color(0xFFFEF3C7);
    IconData icon = Icons.hourglass_top_rounded;

    if (exitStatus == 'REJECTED') {
      statusText = "Needs Fix";
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEE2E2);
      icon = Icons.error_outline_rounded;
    } else if (exitStatus == 'READY_FOR_EXIT' || payStatus == 'PAID') {
      statusText = "Ready for Scan";
      statusColor = const Color(0xFF16A34A);
      statusBg = const Color(0xFFDCFCE7);
      icon = Icons.verified_user_rounded;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: orderId))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: statusColor.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration:
                    BoxDecoration(color: statusBg, shape: BoxShape.circle),
                child: Icon(icon, color: statusColor, size: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Order #$shortId",
                      style: GoogleFonts.syne(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827))),
                  const SizedBox(height: 4),
                  Text("₹${amount.toStringAsFixed(0)} • Tap to view",
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: const Color(0xFF6B7280))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: statusBg, borderRadius: BorderRadius.circular(100)),
              child: Text(statusText,
                  style: GoogleFonts.dmSans(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                  color: Color(0xFFF9FAFB), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline_rounded,
                  size: 60, color: Color(0xFFD1D5DB))),
          const SizedBox(height: 20),
          Text("No active gate passes",
              style: GoogleFonts.syne(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: const Color(0xFF111827))),
          const SizedBox(height: 8),
          Text("You have no pending or active orders right now.",
              style: GoogleFonts.dmSans(
                  color: const Color(0xFF6B7280), fontSize: 14)),
        ],
      ),
    );
  }
}
