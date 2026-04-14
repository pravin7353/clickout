import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cart/cart_service.dart';
import '../utils/user_session.dart'; // 🚀 SAAS INJECTION IMPORT

class ProductSearchDelegate extends SearchDelegate {
  @override
  ThemeData appBarTheme(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFC62828),
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle:
            TextStyle(color: Colors.white60, fontFamily: 'DejaVuSansMono'),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: const TextStyle(
            color: Colors.white, fontFamily: 'DejaVuSansMono', fontSize: 18),
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

  @override
  Widget buildResults(BuildContext context) {
    _addToHistory(query);
    return _buildProductList(query);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return FutureBuilder<List<String>>(
        future: _getHistory(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildNoRecentHistory();
          }
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final historyItem = snapshot.data![index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(historyItem,
                    style: const TextStyle(fontFamily: 'DejaVuSansMono')),
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
    } else {
      return _buildProductList(query);
    }
  }

  Widget _buildProductList(String searchQuery) {
    return StreamBuilder<QuerySnapshot>(
      // 🚀 THE SAAS FIX: Search ONLY in the current store's inventory
      stream: FirebaseFirestore.instance
          .collection('products')
          .where('tenantId', isEqualTo: UserSession.tenantId)
          .where('branchCode',
              isEqualTo: UserSession.storeId) // 🚀 FIXED FIELD NAME!
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFC62828)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNotFound();
        }

        final results = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['isBlocked'] == true) {
            return false; // 🚫 Block Dead Stock from Search UI
          }

          final name = data['name'].toString().toLowerCase();
          final barcode = data['barcode'].toString();
          final searchLower = searchQuery.toLowerCase();
          return name.contains(searchLower) || barcode.contains(searchLower);
        }).toList();

        if (results.isEmpty) return _buildNotFound();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: results.length,
          itemBuilder: (context, index) {
            final data = results[index].data() as Map<String, dynamic>;
            final cart = Provider.of<CartService>(context, listen: false);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.shopping_bag_outlined,
                      color: Color(0xFFC62828)),
                ),
                title: Text(data['name'],
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'DejaVuSansMono')),
                subtitle: Text("Rs ${data['price']}",
                    style: const TextStyle(
                        color: Color(0xFFC62828),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'DejaVuSansMono')),
                trailing: SizedBox(
                  width: 80,
                  height: 35,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC62828),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: () async {
                      try {
                        String rawGst = data['gst'].toString();
                        String cleanGst =
                            rawGst.replaceAll(RegExp(r'[^0-9.]'), '');
                        double finalGst = double.tryParse(cleanGst) ?? 0.0;

                        await cart.add(
                          barcode: data['barcode'].toString(),
                          name: data['name'],
                          price: double.parse(data['price'].toString()),
                          gst: finalGst,
                          weight: data['weight'] != null
                              ? double.parse(data['weight'].toString())
                              : 0.0,
                        );

                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("${data['name']} added to cart!",
                                style: const TextStyle(
                                    fontFamily: 'DejaVuSansMono')),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 3),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    child: const Text("ADD",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("Item not found",
              style: TextStyle(
                  color: Colors.grey[600],
                  fontFamily: 'DejaVuSansMono',
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildNoRecentHistory() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No recent searches",
              style: TextStyle(
                  color: Colors.grey[400], fontFamily: 'DejaVuSansMono')),
        ],
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
