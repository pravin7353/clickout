import '../widgets/shared_cart_item_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cart/cart_service.dart';
import '../utils/user_session.dart';
import '../models/cart_item.dart'; // Needed for type casting in CartGroup
import '../screens/cart_screen.dart'; // Routing for Checkout

class ProductSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFC53030), // Match Brand Red
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white60, fontSize: 16),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: () {
              query = '';
              showSuggestions(context);
            }),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
        icon:
            const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
        onPressed: () => close(context, null));
  }

  // 🚀 THE MAGIC UX: We inject the 40/60 Split here!
  @override
  Widget buildResults(BuildContext context) {
    _addToHistory(query);
    return _buildSplitScreen(context, isResults: true);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSplitScreen(context, isResults: false);
  }

  // ─── 40/60 SPLIT BUILDER ──────────────────────────────────────────────────
  Widget _buildSplitScreen(BuildContext context, {required bool isResults}) {
    // Force rebuild of cart area when context changes
    final cart = context.watch<CartService>();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F4),
      body: Column(
        children: [
          // 🟩 TOP 40%: SEARCH ZONE
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: isResults
                  ? _buildProductList(query)
                  : (query.isEmpty
                      ? _buildHistoryView()
                      : _buildProductList(query)),
            ),
          ),

          // Divider Line
          Container(height: 2, color: Colors.grey.withOpacity(0.2)),

          // 🟩 BOTTOM 60%: LIVE CART ZONE
          Expanded(
            flex: 6,
            child: _buildLiveCartPanel(context, cart),
          ),
        ],
      ),
    );
  }

  // ─── TOP PANEL COMPONENTS (Search & History) ─────────────────────────────
  Widget _buildHistoryView() {
    return FutureBuilder<List<String>>(
      future: _getHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 50, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text("No recent searches",
                    style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
            final historyItem = snapshot.data![index];
            return ListTile(
              leading: const Icon(Icons.history, color: Colors.grey),
              title: Text(historyItem),
              trailing:
                  const Icon(Icons.north_west, size: 16, color: Colors.grey),
              onTap: () {
                query = historyItem;
                showResults(context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProductList(String searchQuery) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('tenantId', isEqualTo: UserSession.tenantId)
          .where('branchCode', isEqualTo: UserSession.storeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFC62828)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text("No items found",
                  style: TextStyle(color: Colors.grey[600])));
        }

        final results = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['isBlocked'] == true) return false;
          final name = data['name'].toString().toLowerCase();
          final barcode = data['barcode'].toString();
          final searchLower = searchQuery.toLowerCase();
          return name.contains(searchLower) || barcode.contains(searchLower);
        }).toList();

        if (results.isEmpty)
          return Center(
              child: Text("Item not found",
                  style: TextStyle(color: Colors.grey[600])));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final data = results[index].data() as Map<String, dynamic>;
            final cart = Provider.of<CartService>(context, listen: false);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEB),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.shopping_bag_outlined,
                      color: Color(0xFFC62828), size: 20),
                ),
                title: Text(data['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text("₹${data['price']}",
                    style: const TextStyle(
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                trailing: SizedBox(
                  width: 70,
                  height: 32,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC62828),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: EdgeInsets.zero,
                        elevation: 0),
                    onPressed: () async {
                      try {
                        String cleanGst = data['gst']
                            .toString()
                            .replaceAll(RegExp(r'[^0-9.]'), '');
                        await cart.add(
                          barcode: data['barcode'].toString(),
                          name: data['name'],
                          price: double.parse(data['price'].toString()),
                          gst: double.tryParse(cleanGst) ?? 0.0,
                          weight: data['weight'] != null
                              ? double.parse(data['weight'].toString())
                              : 0.0,
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.red));
                      }
                    },
                    child: const Text("ADD",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── BOTTOM PANEL COMPONENTS (Live Cart) ─────────────────────────────────
  Widget _buildLiveCartPanel(BuildContext context, CartService cart) {
    // Smart Grouping Logic using Shared Component
    final List<CartGroup> groupedList = buildCartGroups(cart.items);

    return Column(
      children: [
        // Cart Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Your Cart (${cart.totalItems})",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
              Text("₹${cart.grandTotal.toStringAsFixed(0)}",
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFC53030))),
            ],
          ),
        ),

        // Smart List
        Expanded(
          child: groupedList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          size: 40, color: Colors.grey.withOpacity(0.4)),
                      const SizedBox(height: 8),
                      const Text("Cart is empty",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  itemCount: groupedList.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SharedCartItemCard(
                          group: groupedList[index], cart: cart),
                    );
                  },
                ),
        ),

        // Checkout Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4))
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC53030),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: cart.items.isEmpty
                  ? null
                  : () {
                      // Close search and go to checkout
                      close(context, null);
                      Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CartScreen()));
                    },
              icon: const Icon(Icons.shopping_cart_checkout, size: 18),
              label: const Text("VIEW FULL CART",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ),
      ],
    );
  }

  // 🚀 FIX: Added BuildContext context parameter
  Widget _buildSmartGroupCard(
      BuildContext context, CartGroup group, CartService cart) {
    final base = group.baseItem;
    final free = group.freeItem;
    final overflow = group.overflowItem;

    if (base == null && free == null && overflow == null)
      return const SizedBox.shrink();

    final CartItem display = base ?? overflow ?? free!;
    final int paidQty = (base?.quantity ?? 0) + (overflow?.quantity ?? 0);
    final int freeQty = free?.quantity ?? 0;
    final int totalQty = paidQty + freeQty;
    final double paidTotal =
        (base?.totalPrice ?? 0) + (overflow?.totalPrice ?? 0);
    final double mrp = display.originalPrice;
    final bool hasOffer = (base?.clearanceActive ?? false) || freeQty > 0;
    final String offerType =
        base?.clearanceType ?? (freeQty > 0 ? 'FREE_ITEM' : '');

    // 🚀 THE MAGIC: SWIPE TO DELETE WRAPPER
    return Dismissible(
        key: ValueKey(group.baseKey),
        confirmDismiss: (direction) async {
          if (cart.isCorrectionMode) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Locked during correction"),
                backgroundColor: Colors.red));
            return false; // Blocks delete
          }
          return true;
        },
        direction: cart.isCorrectionMode
            ? DismissDirection.none
            : DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
              color: const Color(0xFFE53E3E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_outline_rounded,
              color: Color(0xFFE53E3E), size: 28),
        ),
        onDismissed: (direction) {
          final name = display.name;
          cart.deleteItem(group.baseKey);
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("$name removed"),
            backgroundColor: const Color(0xFF111111),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.yellow,
              onPressed: () async {
                try {
                  await cart.add(
                      barcode: display.barcode,
                      name: display.name,
                      price: display.originalPrice,
                      gst: display.gst,
                      weight: display.weight);
                  for (int i = 1; i < totalQty; i++)
                    await cart.increment(display.barcode);
                } catch (_) {}
              },
            ),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: hasOffer
                ? Border.all(color: const Color(0xFF16A34A).withOpacity(0.25))
                : Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasOffer
                          ? const Color(0xFF16A34A).withOpacity(0.08)
                          : const Color(0xFFE53E3E).withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.shopping_bag_outlined,
                        color: hasOffer
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFE53E3E),
                        size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(display.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF111111))),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (hasOffer &&
                                base != null &&
                                base.clearanceType != 'BOGO' &&
                                base.clearanceType != 'BUY_X_GET_Y' &&
                                base.clearanceType != 'FREE_ITEM')
                              Text("₹${mrp.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      decoration: TextDecoration.lineThrough)),
                            if (hasOffer &&
                                base != null &&
                                base.clearanceType != 'BOGO' &&
                                base.clearanceType != 'BUY_X_GET_Y' &&
                                base.clearanceType != 'FREE_ITEM')
                              const SizedBox(width: 4),
                            Text(
                              hasOffer &&
                                      base != null &&
                                      base.clearanceType != 'BOGO' &&
                                      base.clearanceType != 'BUY_X_GET_Y'
                                  ? "₹${base.finalUnitPrice.toStringAsFixed(0)}/item"
                                  : "₹${mrp.toStringAsFixed(0)}/item",
                              style: TextStyle(
                                  fontSize: 11,
                                  color: hasOffer
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF6B7280),
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text("₹${paidTotal.toStringAsFixed(0)}",
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111))),
                ],
              ),
              if (freeQty > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF16A34A).withOpacity(0.2))),
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard_rounded,
                          color: Color(0xFF16A34A), size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(
                              _offerLabel(offerType, base?.buyQty ?? 1,
                                  base?.freeQty ?? freeQty),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w600))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(100)),
                        child: Text("+$freeQty FREE",
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      freeQty > 0
                          ? "$paidQty paid · $freeQty free"
                          : "$totalQty items",
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF6B7280))),
                  Row(
                    children: [
                      _miniStepBtn(Icons.remove, () {
                        if (cart.isCorrectionMode) return;
                        try {
                          cart.decrement(group.baseKey);
                        } catch (_) {}
                      }, enabled: !cart.isCorrectionMode && totalQty > 1),
                      SizedBox(
                          width: 32,
                          child: Text("$totalQty",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14))),
                      _miniStepBtn(Icons.add, () async {
                        if (cart.isCorrectionMode) return;
                        try {
                          await cart.increment(group.baseKey);
                        } catch (_) {}
                      }, enabled: !cart.isCorrectionMode, isAdd: true),
                    ],
                  )
                ],
              )
            ],
          ),
        ));
  }

  String _offerLabel(String type, int buyQty, int freeQty) {
    if (type == 'BOGO') return "Buy 1 Get 1 Free";
    if (type == 'BUY_X_GET_Y') return "Buy $buyQty Get $freeQty Free";
    if (type == 'BUY_X_GET_Y_CROSS') return "Cross-Product: $freeQty free";
    return "Free item applied";
  }

  Widget _miniStepBtn(IconData icon, VoidCallback onTap,
      {bool enabled = true, bool isAdd = false}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: enabled
              ? (isAdd ? const Color(0xFFFFEBEB) : const Color(0xFFF6F6F4))
              : const Color(0xFFF6F6F4),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: enabled
                  ? (isAdd
                      ? const Color(0xFFE53E3E).withOpacity(0.3)
                      : const Color(0xFFE5E7EB))
                  : const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon,
            size: 14,
            color: enabled
                ? (isAdd ? const Color(0xFFE53E3E) : const Color(0xFF111111))
                : const Color(0xFF9CA3AF)),
      ),
    );
  }

  Future<void> _addToHistory(String term) async {
    if (term.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('search_history') ?? [];
    history.remove(term);
    history.insert(0, term);
    if (history.length > 10) history = history.sublist(0, 10);
    await prefs.setStringList('search_history', history);
  }

  Future<List<String>> _getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('search_history') ?? [];
  }
}
