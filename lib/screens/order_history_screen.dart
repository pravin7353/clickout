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
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              String orderId = docs[index].id;
              double amount = (data['totalAmount'] ?? 0).toDouble();
              String status = data['status'] ?? 'UNKNOWN';
              bool isBlackBox = data['isBlackBoxCorrupted'] == true;
              Timestamp? createdAt = data['createdAt'] as Timestamp?;
              String dateStr = createdAt != null
                  ? DateFormat('dd MMM yyyy, hh:mm a')
                      .format(createdAt.toDate())
                  : 'Unknown Date';

              void handleTap() {
                if (status == 'PENDING' && data['paymentMode'] == 'CASH') {
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

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                elevation: 2,
                color: isBlackBox ? Colors.black87 : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: status == 'COMPLETED'
                            ? Colors.green.shade100
                            : (status == 'PENDING'
                                ? Colors.orange.shade100
                                : Colors.red.shade100),
                        child: Icon(
                          status == 'COMPLETED'
                              ? Icons.check_circle
                              : (status == 'PENDING'
                                  ? Icons.hourglass_empty
                                  : Icons.error),
                          color: status == 'COMPLETED'
                              ? Colors.green
                              : (status == 'PENDING'
                                  ? Colors.orange
                                  : Colors.red),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Order: ${orderId.substring(0, 8)}...",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'DejaVuSansMono',
                                    color: isBlackBox
                                        ? Colors.white
                                        : Colors.black87)),
                            const SizedBox(height: 4),
                            Text(dateStr,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isBlackBox
                                        ? Colors.white70
                                        : Colors.grey)),
                            if (isBlackBox && data['revisionHistory'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  "⚠️ AI Record: ${(data['revisionHistory'] as List).length} Attempt(s) Logged",
                                  style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text("₹${amount.toStringAsFixed(0)}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isBlackBox
                                      ? Colors.white
                                      : Colors.black87)),
                          const SizedBox(height: 4),
                          Text(status,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: status == 'COMPLETED'
                                      ? Colors.green
                                      : Colors.orange)),
                        ],
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
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold))
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
    );
  }
}
