import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_detail_screen.dart';
import '../../services/system/auto_heal_service.dart';
import '../utils/user_session.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  // 🚀 THE FIX: Dynamic getter instead of static final variable (Real-time check)
  String? get userId => FirebaseAuth.instance.currentUser?.uid;
  bool get isGlobal => UserSession.tenantId.isEmpty;

  int _currentSortIndex = 0;
  final List<String> _sortModes = [
    "⏱️ Date: Newest",
    "⏱️ Date: Oldest",
    "💸 Price: Highest",
    "💸 Price: Lowest"
  ];

  void _sortOrders(List<QueryDocumentSnapshot> docs) {
    String mode = _sortModes[_currentSortIndex];
    docs.sort((a, b) {
      Map<String, dynamic> dataA = a.data() as Map<String, dynamic>;
      Map<String, dynamic> dataB = b.data() as Map<String, dynamic>;

      DateTime dateA =
          (dataA['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      DateTime dateB =
          (dataB['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      double priceA =
          double.tryParse(dataA['totalAmount']?.toString() ?? '0') ?? 0.0;
      double priceB =
          double.tryParse(dataB['totalAmount']?.toString() ?? '0') ?? 0.0;

      if (mode == "⏱️ Date: Newest") return dateB.compareTo(dateA);
      if (mode == "⏱️ Date: Oldest") return dateA.compareTo(dateB);
      if (mode == "💸 Price: Highest") return priceB.compareTo(priceA);
      if (mode == "💸 Price: Lowest") return priceA.compareTo(priceB);
      return dateB.compareTo(dateA);
    });
  }

  @override
  void initState() {
    super.initState();
    if (userId != null) {
      AutoHealService().healCorruptedOrders(userId!);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'EXITED':
      case 'APPROVED':
      case 'CLEAR EXIT':
        return const Color(0xFFE8F5E9);
      case 'REJECTED':
      case 'NEEDS FIX':
        return const Color(0xFFFFEBEE);
      case 'FIX & EXIT':
        return const Color(0xFFF3E5F5);
      case 'EXPIRED':
        return const Color(0xFFF3F4F6);
      default:
        return const Color(0xFFE0F2FE);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'EXITED':
      case 'APPROVED':
      case 'CLEAR EXIT':
        return const Color(0xFF166534);
      case 'REJECTED':
      case 'NEEDS FIX':
        return const Color(0xFF991B1B);
      case 'FIX & EXIT':
        return const Color(0xFF6B21A8);
      case 'EXPIRED':
        return const Color(0xFF4B5563);
      default:
        return const Color(0xFF075985);
    }
  }

  String _formatStatus(String rawStatus, Map<String, dynamic> order) {
    String e = (order['exitStatus'] ?? '').toString().toUpperCase();
    bool wasEverRejected = order['wasEverRejected'] == true;

    if (e == 'COMPLETED' || e == 'EXITED' || e == 'APPROVED') {
      return wasEverRejected ? 'Fix & Exit' : 'Clear Exit';
    }
    if (e == 'REJECTED') return 'Needs Fix';
    if (e == 'EXPIRED' || e == 'EXPIRED_BY_SYSTEM') return 'Expired';
    return e.isNotEmpty ? e : 'Current Order';
  }

// 📡 Custom Stream based on Global vs In-Store
  Stream<QuerySnapshot> _getOrdersStream() {
    // 🚀 SAFE QUERY: No extra filters to avoid Firebase Composite Index Errors
    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isGlobal ? "All Orders History" : "Store Order History",
          style: GoogleFonts.syne(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: const Color(0xFF111827)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => setState(() => _currentSortIndex =
                  (_currentSortIndex + 1) % _sortModes.length),
              icon: const Icon(Icons.sort_rounded,
                  color: Color(0xFF111827), size: 16),
              label: Text(_sortModes[_currentSortIndex],
                  style: GoogleFonts.dmSans(
                      color: const Color(0xFF111827),
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
              style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
            ),
          ),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: const Color(0xFFF3F4F6), height: 1)),
      ),
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          // ⏳ 1. Wait for Firebase to check memory (Fixes Web Refresh issue)
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF111827)));
          }

          // 🛑 2. If actually logged out, show a proper message
          if (!authSnapshot.hasData || authSnapshot.data == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 50, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text("Please log in to view history.",
                      style: GoogleFonts.syne(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          // ✅ 3. User confirmed! Now fetch their orders dynamically.
          final liveUserId = authSnapshot.data!.uid;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('userId', isEqualTo: liveUserId)
                .orderBy('timestamp', descending: true)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF111827)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                return _buildEmptyState();

              List<QueryDocumentSnapshot> allDocs = snapshot.data!.docs;

              // 🚀 LOCAL FILTER: Store mode me sirf current store ke orders dikhao (Firebase Index Error Bypass)
              if (!isGlobal) {
                allDocs = allDocs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return data['storeId'] == UserSession.storeId;
                }).toList();
              }

              if (allDocs.isEmpty) return _buildEmptyState();

              _sortOrders(allDocs);

              // 🚀 SPLIT LOGIC: SAB KUCH DIKHEGA YAHAN
              List<QueryDocumentSnapshot> activeDocs = [];
              List<QueryDocumentSnapshot> pastDocs = [];

              for (var doc in allDocs) {
                var data = doc.data() as Map<String, dynamic>;
                String e = (data['exitStatus'] ?? '').toString().toUpperCase();
                String s = (data['status'] ?? '').toString().toUpperCase();
                bool isConsumed = data['qrConsumed'] == true;

                bool isRejected = e == 'REJECTED';
                bool isExpired = e == 'EXPIRED' ||
                    e == 'EXPIRED_BY_SYSTEM' ||
                    s == 'EXPIRED';
                bool isDeleted = s == 'DELETED' || s == 'CANCELLED';
                bool isCompleted =
                    e == 'EXITED' || e == 'APPROVED' || e == 'COMPLETED';

                // 🚀 ULTIMATE ACTIVE RULE: 'Already Used' Active me nahi dikhega
                bool isActive = !isExpired &&
                    !isDeleted &&
                    (isRejected || (!isCompleted && !isConsumed));

                if (isActive) {
                  activeDocs.add(doc);
                } else {
                  pastDocs.add(doc);
                }
              }

              return ListView(
                padding: const EdgeInsets.only(top: 10, bottom: 30),
                children: [
                  if (activeDocs.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Text("Active Gate Passes",
                          style: GoogleFonts.syne(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF111827))),
                    ),
                    ...activeDocs.map((doc) => _buildActiveOrderCard(doc)),
                    const SizedBox(height: 20),
                  ],
                  if (pastDocs.isNotEmpty) ...[
                    if (activeDocs.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        child: Text("Past History",
                            style: GoogleFonts.syne(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827))),
                      ),
                    isGlobal
                        ? _buildGlobalGroupedList(pastDocs)
                        : _buildFlatOrderList(pastDocs),
                  ],
                ],
              );
            },
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
            ]),
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
                  ]),
            ),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: statusBg, borderRadius: BorderRadius.circular(100)),
                child: Text(statusText,
                    style: GoogleFonts.dmSans(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalGroupedList(List<QueryDocumentSnapshot> docs) {
    Map<String, List<Map<String, dynamic>>> groupedOrders = {};
    for (var doc in docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['orderId'] = doc.id;
      // 🚀 FIX: Show actual branch code instead of default_tenant
      String storeName = data['storeName'] ??
          data['branchCode'] ??
          data['storeId'] ??
          'Unknown Store';
      if (!groupedOrders.containsKey(storeName)) groupedOrders[storeName] = [];
      groupedOrders[storeName]!.add(data);
    }

    return Column(
      children: groupedOrders.keys.map((storeName) {
        List<Map<String, dynamic>> storeOrders = groupedOrders[storeName]!;
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: true,
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.storefront_rounded,
                    color: Color(0xFF4B5563), size: 22)),
            title: Text(storeName,
                style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF111827))),
            subtitle: Text("${storeOrders.length} Transactions",
                style: GoogleFonts.dmSans(
                    fontSize: 13, color: const Color(0xFF6B7280))),
            children: storeOrders
                .map((order) => _buildMinimalistOrderTile(order))
                .toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFlatOrderList(List<QueryDocumentSnapshot> docs) {
    List<Map<String, dynamic>> orders = docs.map((doc) {
      var data = doc.data() as Map<String, dynamic>;
      data['orderId'] = doc.id;
      return data;
    }).toList();
    return Column(
        children:
            orders.map((order) => _buildMinimalistOrderTile(order)).toList());
  }

  Widget _buildMinimalistOrderTile(Map<String, dynamic> order) {
    final String orderId = order['orderId'] ?? '';
    final String shortId = orderId.length > 6
        ? orderId.substring(orderId.length - 6).toUpperCase()
        : orderId;
    final double amount =
        double.tryParse(order['totalAmount']?.toString() ?? '0') ?? 0.0;
    final List<dynamic> items = order['items'] ?? [];
    final String status = _formatStatus(
        (order['exitStatus'] ?? order['status'] ?? 'PENDING'), order);
    final dt = (order['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    return InkWell(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: orderId))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Color(0xFFF3F4F6), width: 1))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0))),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Color(0xFF64748B), size: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Order #$shortId",
                          style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: const Color(0xFF111827))),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                              color: _getStatusBgColor(status),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(status,
                              style: GoogleFonts.dmSans(
                                  color: _getStatusTextColor(status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined,
                          size: 12, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Text("${items.length} items",
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: const Color(0xFF6B7280))),
                      const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Text("•",
                              style: TextStyle(color: Color(0xFFD1D5DB)))),
                      const Icon(Icons.access_time_rounded,
                          size: 12, color: Color(0xFF9CA3AF)),
                      const SizedBox(width: 4),
                      Text(DateFormat('hh:mm a').format(dt),
                          style: GoogleFonts.dmSans(
                              fontSize: 12, color: const Color(0xFF6B7280))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("₹${amount.toStringAsFixed(0)}",
                      style: GoogleFonts.syne(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: const Color(0xFF111827))),
                ],
              ),
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
              child: const Icon(Icons.receipt_long_rounded,
                  size: 60, color: Color(0xFFD1D5DB))),
          const SizedBox(height: 20),
          Text("No orders found",
              style: GoogleFonts.syne(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: const Color(0xFF111827))),
          const SizedBox(height: 8),
          Text("Your transaction history will appear here.",
              style: GoogleFonts.dmSans(
                  color: const Color(0xFF6B7280), fontSize: 14)),
        ],
      ),
    );
  }
}
