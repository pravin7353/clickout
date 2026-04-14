import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'order_detail_screen.dart';
import 'payment_qr_screen.dart';
import '../../services/system/auto_heal_service.dart';
import '../../utils/user_session.dart'; // 🚀 SAAS INJECTION IMPORT

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
          _currentSort = SortType.amountDesc;
          break;
        case SortType.amountDesc:
          _currentSort = SortType.amountAsc;
          break;
        case SortType.amountAsc:
          _currentSort = SortType.dateLatest;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 THE FIX: Ye line 'currentUserId' ke laal error ko hamesha ke liye mita degi!
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('View Gate Pass & History',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFFC62828),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _cycleSort,
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        // 🚀 SAAS INJECTION FIX: Ab customer ko wahi ki history dikhegi jis dukan me wo khada hai
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: currentUserId)
            .where('tenantId', isEqualTo: UserSession.tenantId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFFC62828)));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No orders found in this store.",
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          var docs = snapshot.data!.docs;

          // Sorting Logic
          docs.sort((a, b) {
            var dataA = a.data() as Map<String, dynamic>;
            var dataB = b.data() as Map<String, dynamic>;

            if (_currentSort == SortType.dateLatest) {
              Timestamp? tA = dataA['createdAt'] as Timestamp?;
              Timestamp? tB = dataB['createdAt'] as Timestamp?;
              return (tB ?? Timestamp.now()).compareTo(tA ?? Timestamp.now());
            } else if (_currentSort == SortType.pendingFirst) {
              return (dataA['status'] == 'PENDING' ? 0 : 1)
                  .compareTo(dataB['status'] == 'PENDING' ? 0 : 1);
            } else if (_currentSort == SortType.completedFirst) {
              return (dataA['status'] == 'COMPLETED' ? 0 : 1)
                  .compareTo(dataB['status'] == 'COMPLETED' ? 0 : 1);
            } else if (_currentSort == SortType.amountDesc) {
              double amtA = (dataA['totalAmount'] ?? 0).toDouble();
              double amtB = (dataB['totalAmount'] ?? 0).toDouble();
              return amtB.compareTo(amtA);
            } else {
              double amtA = (dataA['totalAmount'] ?? 0).toDouble();
              double amtB = (dataB['totalAmount'] ?? 0).toDouble();
              return amtA.compareTo(amtB);
            }
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String orderId = docs[index].id;
              double amount = (data['totalAmount'] ?? 0).toDouble();
              bool isBlackBox = data['isBlackBoxCorrupted'] == true;

              // Date Fallback Logic
              Timestamp? timestamp = data['timestamp'] as Timestamp? ??
                  data['createdAt'] as Timestamp?;
              String dateStr = timestamp != null
                  ? DateFormat('dd MMM yyyy, hh:mm a')
                      .format(timestamp.toDate())
                  : 'Unknown Date';

              // 🚀 SMART STATUS PILL ENGINE
              String exitStatus =
                  (data['exitStatus'] ?? '').toString().toUpperCase();
              String payStatus =
                  (data['paymentStatus'] ?? '').toString().toUpperCase();
              String rawStatus =
                  (data['status'] ?? '').toString().toUpperCase();

              bool isFixed = data['wasEverRejected'] == true ||
                  (data['gatePassVersion'] != null &&
                      data['gatePassVersion'] > 1) ||
                  rawStatus == 'SUPERSEDED';

              String pillText = 'UNKNOWN';
              Color pillColor = Colors.grey;
              Color iconBgColor = Colors.grey.shade200;
              IconData mainIcon = Icons.help_outline;

              if (exitStatus == 'REJECTED') {
                pillText = 'EXIT STOPPED';
                pillColor = Colors.red;
                iconBgColor = Colors.red.shade100;
                mainIcon = Icons.error_outline;
              } else if (exitStatus == 'COMPLETED' ||
                  exitStatus == 'EXITED' ||
                  exitStatus == 'APPROVED') {
                if (isFixed || isBlackBox) {
                  pillText = 'FIXED & EXITED';
                  pillColor = const Color(0xFF00BFA5); // Teal Accent
                  iconBgColor = const Color(0xFFE0F2F1);
                  mainIcon = Icons.build;
                } else {
                  pillText = 'CLEAR EXIT';
                  pillColor = Colors.green;
                  iconBgColor = Colors.green.shade100;
                  mainIcon = Icons.check_circle;
                }
              } else if (payStatus == 'PAID' &&
                  (exitStatus == 'PENDING' || exitStatus == 'READY_FOR_EXIT')) {
                pillText = 'NEW GATE PASS GENERATED';
                pillColor = Colors.blue;
                iconBgColor = Colors.blue.shade100;
                mainIcon = Icons.qr_code_scanner;
              } else if (payStatus == 'PENDING') {
                pillText = 'PAYMENT PENDING';
                pillColor = Colors.orange;
                iconBgColor = Colors.orange.shade100;
                mainIcon = Icons.hourglass_empty;
              } else if (exitStatus == 'EXPIRED' || rawStatus == 'EXPIRED') {
                pillText = 'GATE PASS EXPIRED';
                pillColor = Colors.purpleAccent;
                iconBgColor = Colors.purpleAccent.shade100;
                mainIcon = Icons.timer_off;
              }

              void handleTap() {
                if (payStatus == 'PENDING' && data['paymentMode'] == 'CASH') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PaymentQRScreen(
                              orderId: orderId, amount: amount)));
                } else {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => OrderDetailScreen(orderId: orderId)));
                }
              }

              // 🚀 VIP EXACT MOCKUP UI
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 1,
                color: isBlackBox ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Icon Avatar
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: isBlackBox
                              ? pillColor.withOpacity(0.15)
                              : iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(mainIcon, color: pillColor, size: 26),
                      ),
                      const SizedBox(width: 16),
                      // Middle Detail Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "₹${amount.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'DejaVuSansMono',
                                color:
                                    isBlackBox ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: isBlackBox
                                    ? Colors.white54
                                    : Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // THE COLOURED STATUS PILL
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isBlackBox
                                    ? pillColor.withOpacity(0.1)
                                    : Colors.white,
                                border: Border.all(
                                    color: pillColor.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    pillText,
                                    style: TextStyle(
                                      color: pillColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  if (isBlackBox) ...[
                                    const SizedBox(width: 4),
                                    Icon(Icons.build,
                                        color: pillColor, size: 10),
                                  ]
                                ],
                              ),
                            ),
                            // Black Box AI Log Alert
                            if (isBlackBox &&
                                data['revisionHistory'] != null) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: Colors.orange, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    "AI Record: ${(data['revisionHistory'] as List).length} Attempt(s) Logged",
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ],
                        ),
                      ),
                      // Right Options Menu
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
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
                            child: Row(
                              children: [
                                Icon(Icons.visibility,
                                    size: 20, color: Colors.blueAccent),
                                SizedBox(width: 10),
                                Text('View Details',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
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
    );
  }
}
