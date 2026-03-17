import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'order_detail_screen.dart';
import 'payment_qr_screen.dart';
import '../../services/system/auto_heal_service.dart';

enum SortType {
  pendingFirst,
  completedFirst,
  amountAsc,
  amountDesc,
  dateLatest
}

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  SortType _currentSort = SortType.dateLatest;

  @override
  void initState() {
    super.initState();
    // Screen khulte hi background me auto-heal run kar do
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      AutoHealService().healCorruptedOrders(userId);
    }
  }

  void _cycleSort() {
    setState(() {
      switch (_currentSort) {
        case SortType.dateLatest:
          _currentSort = SortType.pendingFirst;
          break;
        case SortType.pendingFirst:
          _currentSort = SortType.completedFirst;
          break;
        case SortType.completedFirst:
          _currentSort = SortType.amountAsc;
          break;
        case SortType.amountAsc:
          _currentSort = SortType.amountDesc;
          break;
        case SortType.amountDesc:
          _currentSort = SortType.dateLatest;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    const Color cherryRedLight = Color(0xFFEF5350);
    const Color cherryRedDark = Color(0xFFC62828);
    const Color bgGrey = Color(0xFFF4F6F8);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: bgGrey,
        body: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [cherryRedLight, cherryRedDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(35),
                      bottomRight: Radius.circular(35)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 15,
                        offset: Offset(0, 5))
                  ]),
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CircleAvatar(
                              backgroundColor: Colors.white24,
                              radius: 20,
                              child: IconButton(
                                  icon: const Icon(Icons.arrow_back_ios_new,
                                      color: Colors.white, size: 18),
                                  onPressed: () => Navigator.pop(context))),
                          const Text("ClickOut VIP",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.bold)),
                          Container(
                              decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(12)),
                              child: IconButton(
                                  icon: const Icon(Icons.sort,
                                      color: Colors.white),
                                  onPressed: _cycleSort)),
                        ],
                      ),
                    ),
                    const Text("My Activity",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w900)),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: InkWell(
                        onTap: () {
                          if (userId != null) {
                            Clipboard.setData(ClipboardData(text: userId));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("VIP ID Copied!")));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12)),
                          child: Text("ID: ${userId ?? 'Guest'}",
                              style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontFamily: 'monospace')),
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 5,
                                offset: Offset(0, 2))
                          ],
                        ),
                        labelColor: cherryRedDark,
                        unselectedLabelColor: Colors.white,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5),
                        tabs: const [
                          Tab(text: "LIVE & HISTORY ⏱️"),
                          Tab(text: "BLACK BOX ⬛")
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: userId == null
                  ? const Center(child: Text("Please Login to view orders"))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .where('userId', isEqualTo: userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(
                              child: CircularProgressIndicator(
                                  color: cherryRedDark));
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return _buildEmptyState();
                        }

                        final allOrders = snapshot.data!.docs;

                        // 🟢 LAYER A: LIVE & HISTORY
                        var liveOrders = allOrders.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          String exitStatus = (data['exitStatus'] ?? '')
                              .toString()
                              .toUpperCase();
                          String payStatus = (data['paymentStatus'] ?? '')
                              .toString()
                              .toUpperCase();

                          DateTime? expiresAt =
                              (data['qrExpiresAt'] as Timestamp?)?.toDate();
                          bool isExpired = expiresAt != null &&
                              DateTime.now().isAfter(expiresAt);

                          if (exitStatus == 'REJECTED') return true;

                          bool isCleanExit = (exitStatus == 'COMPLETED' ||
                              exitStatus == 'APPROVED' ||
                              exitStatus == 'EXITED');
                          bool isActivePending = (payStatus == 'PENDING' ||
                                  exitStatus == 'PENDING' ||
                                  exitStatus == 'READY_FOR_EXIT') &&
                              !isExpired;

                          if (data['isDeleted'] == true && !isActivePending) {
                            return false;
                          }
                          if (isCleanExit) return true;
                          if (isExpired) return false;
                          if (payStatus == 'REFUNDED') return false;

                          return true;
                        }).toList();

                        // 🔴 LAYER B: THE BLACK BOX
                        var blackBoxOrders = allOrders.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          String exitStatus = (data['exitStatus'] ?? '')
                              .toString()
                              .toUpperCase();
                          String payStatus = (data['paymentStatus'] ?? '')
                              .toString()
                              .toUpperCase();
                          bool wasEverRejected =
                              data['wasEverRejected'] == true;

                          DateTime? expiresAt =
                              (data['qrExpiresAt'] as Timestamp?)?.toDate();
                          bool isExpired = expiresAt != null &&
                              DateTime.now().isAfter(expiresAt);
                          bool isCleanExit = (exitStatus == 'COMPLETED' ||
                              exitStatus == 'APPROVED' ||
                              exitStatus == 'EXITED');
                          bool isActivePending = (payStatus == 'PENDING' ||
                                  exitStatus == 'PENDING' ||
                                  exitStatus == 'READY_FOR_EXIT') &&
                              !isExpired &&
                              exitStatus != 'REJECTED';

                          if (isActivePending) return false;
                          if (!isCleanExit && isExpired) return true;
                          if (isCleanExit && wasEverRejected) return true;
                          if (payStatus == 'REFUNDED') return true;

                          return false;
                        }).toList();

                        _sortList(liveOrders);
                        _sortList(blackBoxOrders);

                        return TabBarView(
                          children: [
                            _buildOrderList(liveOrders,
                                isBlackBox: false,
                                cherryRedDark: cherryRedDark),
                            _buildOrderList(blackBoxOrders,
                                isBlackBox: true, cherryRedDark: cherryRedDark),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _sortList(List<DocumentSnapshot> orders) {
    orders.sort((a, b) {
      final dataA = a.data() as Map<String, dynamic>;
      final dataB = b.data() as Map<String, dynamic>;
      Timestamp t1 = dataA['timestamp'] is Timestamp
          ? dataA['timestamp']
          : Timestamp.now();
      Timestamp t2 = dataB['timestamp'] is Timestamp
          ? dataB['timestamp']
          : Timestamp.now();
      String statusA = (dataA['paymentStatus'] ?? '').toString().toUpperCase();
      String statusB = (dataB['paymentStatus'] ?? '').toString().toUpperCase();
      double amtA =
          double.tryParse(dataA['totalAmount']?.toString() ?? '0') ?? 0;
      double amtB =
          double.tryParse(dataB['totalAmount']?.toString() ?? '0') ?? 0;

      bool isASuccess = statusA == 'PAID';
      bool isBSuccess = statusB == 'PAID';
      bool isAPending = statusA == 'PENDING';
      bool isBPending = statusB == 'PENDING';

      switch (_currentSort) {
        case SortType.pendingFirst:
          if (isAPending && !isBPending) return -1;
          if (!isAPending && isBPending) return 1;
          return t2.compareTo(t1);
        case SortType.completedFirst:
          if (isASuccess && !isBSuccess) return -1;
          if (!isASuccess && isBSuccess) return 1;
          return t2.compareTo(t1);
        case SortType.amountAsc:
          return amtA.compareTo(amtB);
        case SortType.amountDesc:
          return amtB.compareTo(amtA);
        case SortType.dateLatest:
          return t2.compareTo(t1);
      }
    });
  }

  Widget _buildEmptyState() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long, size: 80, color: Colors.grey[300]),
      const SizedBox(height: 15),
      Text("No records found",
          style: TextStyle(
              color: Colors.grey[500],
              fontSize: 18,
              fontWeight: FontWeight.bold))
    ]));
  }

  Widget _buildOrderList(List<DocumentSnapshot> orders,
      {required bool isBlackBox, required Color cherryRedDark}) {
    if (orders.isEmpty) {
      return Center(
          child: Text(
              isBlackBox ? "Your Audit Trail is Clean! 🌟" : "No active orders",
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.bold)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final doc = orders[index];
        final data = doc.data() as Map<String, dynamic>;

        DateTime date =
            (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
        String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(date);
        double totalAmount =
            double.tryParse(data['totalAmount'].toString()) ?? 0.0;

        String payStatus =
            (data['paymentStatus'] ?? 'PENDING').toString().toUpperCase();
        String exitStatus =
            (data['exitStatus'] ?? 'PENDING').toString().toUpperCase();
        String paymentMode =
            (data['paymentMode'] ?? 'UNKNOWN').toString().toUpperCase();
        bool wasEverRejected = data['wasEverRejected'] == true;

        DateTime? expiresAt = (data['qrExpiresAt'] as Timestamp?)?.toDate();
        bool isExpired = expiresAt != null && DateTime.now().isAfter(expiresAt);

        // 🚀 PURE LOGIC (No Fakes)
        bool isCleanExit = (exitStatus == 'COMPLETED' ||
            exitStatus == 'APPROVED' ||
            exitStatus == 'EXITED');

        String displayStatus = "UNKNOWN";
        Color displayColor = Colors.grey;
        IconData displayIcon = Icons.help_outline;

        if (!isCleanExit && isExpired) {
          displayStatus = "EXPIRED (8 HOURS OVER)";
          displayColor = Colors.purpleAccent;
          displayIcon = Icons.auto_delete;
        } else if (exitStatus == 'REJECTED') {
          displayStatus = "GUARD REJECTED (FIX REQUIRED)";
          displayColor = Colors.red;
          displayIcon = Icons.gpp_bad;
        } else if (payStatus == 'PENDING') {
          if (paymentMode == 'CASH') {
            displayStatus = "PENDING AT CASH COUNTER";
            displayColor = Colors.orange;
            displayIcon = Icons.point_of_sale;
          } else {
            displayStatus = "PENDING UPI PAYMENT";
            displayColor = Colors.blueAccent;
            displayIcon = Icons.qr_code_2;
          }
        } else if (payStatus == 'PAID' &&
            (exitStatus == 'READY_FOR_EXIT' || exitStatus == 'PENDING')) {
          displayStatus = "NEW GATE PASS GENERATED";
          displayColor = Colors.blue;
          displayIcon = Icons.qr_code_scanner;
        } else if (isCleanExit) {
          displayStatus = wasEverRejected ? "FIXED & EXITED" : "CLEAR EXIT";
          displayColor = wasEverRejected ? Colors.teal : Colors.green;
          displayIcon =
              wasEverRejected ? Icons.build_circle : Icons.check_circle;
        }

        void handleTap() {
          // If it needs a Guard scan (Pending or Paid but not exited), show QR!
          if ((payStatus == 'PENDING' &&
                  exitStatus != 'REJECTED' &&
                  !isExpired) ||
              (payStatus == 'PAID' &&
                  (exitStatus == 'READY_FOR_EXIT' ||
                      exitStatus == 'PENDING'))) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PaymentQRScreen(orderId: doc.id, amount: totalAmount)));
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => OrderDetailScreen(orderId: doc.id)));
          }
        }

        return GestureDetector(
          onTap: handleTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(18),
            decoration: isBlackBox
                ? BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.redAccent.withOpacity(0.8), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  )
                : BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
            child: Row(
              children: [
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color:
                            displayColor.withOpacity(isBlackBox ? 0.3 : 0.15),
                        shape: BoxShape.circle),
                    child: Icon(displayIcon, color: displayColor, size: 28)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("₹${totalAmount.toStringAsFixed(2)}",
                          style: TextStyle(
                              fontFamily: 'DejaVuSansMono',
                              fontSize: 22,
                              letterSpacing: -0.5,
                              color: isBlackBox ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      Text(formattedDate,
                          style: TextStyle(
                              color: isBlackBox
                                  ? Colors.white54
                                  : Colors.grey[500],
                              fontWeight: FontWeight.w500,
                              fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: displayColor.withOpacity(0.1),
                            border: Border.all(
                                color: displayColor.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(displayStatus,
                            style: TextStyle(
                                color: displayColor,
                                fontSize: 10,
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.bold)),
                      ),
                      if (isBlackBox && !isCleanExit && isExpired)
                        const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text("⚠️ System: Abandoned after 8 hours",
                                style: TextStyle(
                                    color: Colors.purpleAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold))),
                      if (isBlackBox && data['revisionHistory'] != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                                "⚠️ AI Record: ${(data['revisionHistory'] as List).length} Attempt(s) Logged",
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)))
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: isBlackBox ? Colors.white54 : Colors.grey),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  onSelected: (value) {
                    if (value == 'view') handleTap();
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                        value: 'view',
                        child: Row(children: [
                          Icon(Icons.visibility,
                              size: 20, color: Colors.blueAccent),
                          SizedBox(width: 10),
                          Text('View Details',
                              style: TextStyle(fontWeight: FontWeight.bold))
                        ])),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
