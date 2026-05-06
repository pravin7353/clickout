import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/user_session.dart';

class StoreOffersSheet extends StatelessWidget {
  const StoreOffersSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF4F6F8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Handle Bar ───
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              "Today's Live Offers",
              style: GoogleFonts.syne(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF111811),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 🚀 100% REAL DYNAMIC DATA FROM FIREBASE
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('tenantId', isEqualTo: UserSession.tenantId)
                  // 🚀 THE FIX: Removed storeId (CartService uses only tenantId) and fixed field name
                  .where('clearanceActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFE53E3E)));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_offer_outlined,
                            size: 60, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text("No active offers right now.",
                            style: GoogleFonts.dmSans(
                                color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return GridView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    // 🧠 Dynamic Logic Extraction
                    final String name = data['name'] ?? 'Unknown Item';
                    final double price = (data['price'] ?? 0).toDouble();
                    final double dPrice =
                        (data['discountPrice'] ?? price).toDouble();
                    final String type = data['clearanceType'] ?? 'DISCOUNT';
                    final int buyQty = data['buyQty'] ?? 1;
                    final int freeQty = data['freeQty'] ?? 1;

                    String badgeText = "OFFER";
                    Color badgeColor = const Color(0xFF2196F3); // Default Blue
                    IconData centerIcon = Icons.local_offer_rounded;

                    // 🧮 Badge & Discount Calculation
                    if (type == 'BOGO') {
                      badgeText = "BOGO";
                      badgeColor = const Color(0xFF9C27B0); // Purple
                      centerIcon = Icons.card_giftcard_rounded;
                    } else if (type == 'COMBO' || type == 'BUY_X_GET_Y') {
                      badgeText = "BUY $buyQty GET $freeQty";
                      badgeColor = const Color(0xFFF59E0B); // Amber
                      centerIcon = Icons.layers_rounded;
                    } else if (price > dPrice && price > 0) {
                      int off = ((price - dPrice) / price * 100).toInt();
                      badgeText = "$off% OFF";
                      badgeColor = const Color(0xFFE53E3E); // Red
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 14),

                                // 🌟 DYNAMIC ICON
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(centerIcon,
                                      color: badgeColor, size: 30),
                                ),
                                const SizedBox(height: 12),

                                // 📦 PRODUCT NAME
                                Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      height: 1.2,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF111811)),
                                ),
                                const Spacer(),

                                // 💸 EXACT PRICE
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (price > dPrice)
                                      Text(
                                        "₹${price.toStringAsFixed(0)}",
                                        style: GoogleFonts.dmSans(
                                            fontSize: 12,
                                            color: Colors.grey.shade500,
                                            decoration:
                                                TextDecoration.lineThrough),
                                      ),
                                    if (price > dPrice)
                                      const SizedBox(width: 6),
                                    Text(
                                      "₹${dPrice.toStringAsFixed(0)}",
                                      style: GoogleFonts.syne(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF2B3674)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // 🔖 TOP LEFT BADGE
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: badgeColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: Text(
                                badgeText,
                                style: GoogleFonts.dmSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5),
                              ),
                            ),
                          ),
                        ],
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
