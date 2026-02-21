import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'order_detail_screen.dart';
import 'payment_qr_screen.dart';

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

  String _getSortLabel() {
    switch (_currentSort) {
      case SortType.pendingFirst:
        return "Pending First";
      case SortType.completedFirst:
        return "Completed First";
      case SortType.amountAsc:
        return "Amount (Low to High)";
      case SortType.amountDesc:
        return "Amount (High to Low)";
      case SortType.dateLatest:
        return "Latest First";
    }
  }

  void _confirmDeleteOrder(String orderId, Color cherryRedDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Order?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
            "This will remove the order from your history view.\n(It will remain in records for audit)."),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: cherryRedDark),
            onPressed: () async {
              Navigator.pop(ctx); // Dialog band karo
              try {
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(orderId)
                    .update({
                  'status': 'DELETED',
                  'isDeleted': true,
                  'deletedAt': FieldValue.serverTimestamp(),
                });

                // ✅ FIX: Async gap check
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Order removed from history")));
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Error: $e"), backgroundColor: Colors.red));
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    const Color cherryRedLight = Color(0xFFEF5350);
    const Color cherryRedDark = Color(0xFFC62828);

    const Color statusPending = Color(0xFFFFA000);
    const Color statusSuccess = Color(0xFF2E7D32);
    // const Color statusRejected = Color(0xFFD32F2F); // Unused warning fix
    const Color statusDeleted = Color(0xFF757575);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Stack(
        children: [
          // HEADER
          Container(
            height: 240,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [cherryRedLight, cherryRedDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.black12,
                          child: IconButton(
                              icon: const Icon(Icons.arrow_back_ios_new,
                                  color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context)),
                        ),
                        const Text("ClickOut",
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        Container(
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(10)),
                          child: IconButton(
                              icon: const Icon(Icons.sort, color: Colors.white),
                              onPressed: _cycleSort),
                        ),
                      ],
                    ),
                  ),
                  const Text("Order History",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold)),

                  // ID Display
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: InkWell(
                      onTap: () {
                        if (userId != null) {
                          Clipboard.setData(ClipboardData(text: userId));
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("User ID Copied!")));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(5)),
                        child: Text("ID: ${userId ?? 'Guest'}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontFamily: 'monospace')),
                      ),
                    ),
                  ),

                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text("Sorted by: ${_getSortLabel()}",
                        style: const TextStyle(
                            color: cherryRedDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  )
                ],
              ),
            ),
          ),

          // LIST
          Padding(
            padding: const EdgeInsets.only(top: 220),
            child: userId == null
                ? const Center(child: Text("Please Login to view orders"))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .where('userId', isEqualTo: userId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: cherryRedDark));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                              Icon(Icons.history,
                                  size: 80, color: Colors.grey[300]),
                              const SizedBox(height: 10),
                              Text("No orders yet",
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 16))
                            ]));
                      }

                      var orders = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['isDeleted'] != true &&
                            data['status'] != 'DELETED';
                      }).toList();

                      // SORTING LOGIC
                      orders.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;
                        Timestamp t1 = dataA['timestamp'] is Timestamp
                            ? dataA['timestamp']
                            : Timestamp.now();
                        Timestamp t2 = dataB['timestamp'] is Timestamp
                            ? dataB['timestamp']
                            : Timestamp.now();
                        String statusA =
                            (dataA['paymentStatus'] ?? dataA['status'] ?? '')
                                .toString()
                                .toUpperCase();
                        String statusB =
                            (dataB['paymentStatus'] ?? dataB['status'] ?? '')
                                .toString()
                                .toUpperCase();
                        double amtA = double.tryParse(
                                dataA['totalAmount']?.toString() ?? '0') ??
                            0;
                        double amtB = double.tryParse(
                                dataB['totalAmount']?.toString() ?? '0') ??
                            0;

                        bool isASuccess =
                            statusA == 'PAID' || statusA == 'COMPLETED';
                        bool isBSuccess =
                            statusB == 'PAID' || statusB == 'COMPLETED';
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

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        itemCount: orders.length,
                        separatorBuilder: (ctx, i) =>
                            const SizedBox(height: 15),
                        itemBuilder: (context, index) {
                          final doc = orders[index];
                          final data = doc.data() as Map<String, dynamic>;

                          DateTime date =
                              (data['timestamp'] as Timestamp?)?.toDate() ??
                                  DateTime.now();
                          String formattedDate =
                              DateFormat('dd MMM, hh:mm a').format(date);

                          double totalAmount = double.tryParse(
                                  data['totalAmount'].toString()) ??
                              double.tryParse(data['gstTotal'].toString()) ??
                              0.0;

                          // 🚦 SMART STATUS DISPLAY
                          String payStatus =
                              (data['paymentStatus'] ?? 'PENDING')
                                  .toString()
                                  .toUpperCase();
                          String exitStatus = (data['exitStatus'] ?? 'PENDING')
                              .toString()
                              .toUpperCase();

                          String displayStatus = "PENDING";
                          Color displayColor = statusPending;
                          IconData displayIcon = Icons.hourglass_empty;

                          if (payStatus == 'PENDING') {
                            displayStatus = "PAYMENT DUE";
                            displayColor = Colors.orange;
                            displayIcon = Icons.payment;
                          } else if (exitStatus == 'COMPLETED') {
                            displayStatus = "COMPLETED";
                            displayColor = statusSuccess;
                            displayIcon = Icons.check_circle;
                          } else if (payStatus == 'PAID') {
                            displayStatus = "GATE PASS READY";
                            displayColor = Colors.blue;
                            displayIcon = Icons.qr_code;
                          }

                          // Soft deleted check visually
                          if (data['status'] == 'DELETED') {
                            displayStatus = "DELETED";
                            displayColor = statusDeleted;
                            displayIcon = Icons.delete;
                          }

                          return GestureDetector(
                            onTap: () {
                              if (payStatus == 'PENDING') {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => PaymentQRScreen(
                                            orderId: doc.id,
                                            amount: totalAmount)));
                              } else {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => OrderDetailScreen(
                                            orderId: doc.id)));
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                      // ✅ FIX: withOpacity -> withValues (Yellow line gone)
                                      color:
                                          Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4))
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                        // ✅ FIX: withOpacity -> withValues
                                        color:
                                            displayColor.withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child:
                                        Icon(displayIcon, color: displayColor),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            "₹${totalAmount.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                                fontFamily: 'DejaVuSansMono',
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(formattedDate,
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12)),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              // ✅ FIX: withOpacity -> withValues
                                              color: displayColor.withValues(
                                                  alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(5)),
                                          child: Text(displayStatus,
                                              style: TextStyle(
                                                  color: displayColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert,
                                        color: Colors.grey),
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _confirmDeleteOrder(
                                            doc.id, cherryRedDark);
                                      }
                                      if (value == 'view') {
                                        if (payStatus == 'PENDING') {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      PaymentQRScreen(
                                                          orderId: doc.id,
                                                          amount:
                                                              totalAmount)));
                                        } else {
                                          Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      OrderDetailScreen(
                                                          orderId: doc.id)));
                                        }
                                      }
                                    },
                                    itemBuilder: (BuildContext context) =>
                                        <PopupMenuEntry<String>>[
                                      const PopupMenuItem<String>(
                                          value: 'view',
                                          child: Row(children: [
                                            Icon(Icons.visibility,
                                                size: 18, color: Colors.grey),
                                            SizedBox(width: 8),
                                            Text('View Details')
                                          ])),
                                      const PopupMenuItem<String>(
                                          value: 'delete',
                                          child: Row(children: [
                                            Icon(Icons.delete_outline,
                                                size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete Order',
                                                style: TextStyle(
                                                    color: Colors.red))
                                          ])),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
