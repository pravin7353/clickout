import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cart/cart_service.dart';
import '../models/cart_item.dart';
import 'checkout_screen.dart';
import 'scan_product_screen.dart';
import 'home_screen.dart';

enum PaymentMethod { upi, cash, card }

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // 🛡️ RISK CONTROL: Run Validation on Load
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runCartValidation();
    });
  }

  void _runCartValidation() async {
    final cart = context.read<CartService>();
    List<String> changes = await cart.validateCart();

    if (changes.isNotEmpty && mounted) {
      showDialog(
        context: context,
        barrierDismissible:
            false, // Taaki customer msg padhe bina close na kare
        builder: (ctx) => Dialog(
          backgroundColor:
              Colors.transparent, // Background hide kiya custom design ke liye
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade50, Colors.pink.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🎈 BOUNCING PARTY EMOJI ANIMATION
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 900),
                  tween: Tween<double>(begin: 0.1, end: 1.0),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: const Text("🎉", style: TextStyle(fontSize: 60)),
                    );
                  },
                ),
                const SizedBox(height: 15),

                // ✨ HAPPY HEADER
                const Text(
                  "Woohoo! Cart Synced! ✨",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.purple,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "We just auto-magically applied the latest store prices & offers to your items:",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                // 📝 JOYFUL LIST OF CHANGES
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.pink.shade100, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: changes
                        .map((msg) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("🥳 ",
                                      style: TextStyle(fontSize: 18)),
                                  Expanded(
                                    child: Text(
                                      msg,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 25),

                // 🚀 ACTION BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shadowColor: Colors.pinkAccent.withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "Awesome! Let's Go 🚀",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    const Color cherryRedLight = Color(0xFFEF5350);
    const Color cherryRedDark = Color(0xFFC62828);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Stack(
        children: [
          // 1. HEADER
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cherryRedLight, cherryRedDark],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 22),
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HomeScreen()),
                              (route) => false,
                            );
                          },
                        ),
                        const Text("ClickOut",
                            style: TextStyle(
                                fontFamily: 'DejaVuSansMono',
                                color: Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text("Your Cart",
                      style: TextStyle(
                          fontFamily: 'DejaVuSansMono',
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  Text("${cart.totalItems} Items Added",
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),

          // 2. LIST
          Padding(
            padding: const EdgeInsets.only(top: 180),
            child: Column(
              children: [
                Expanded(
                  child: cart.items.isEmpty
                      ? _buildEmptyCart(context, cherryRedDark)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: cart.items.length,
                          separatorBuilder: (ctx, i) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final item = cart.items.values.toList()[i];
                            return Dismissible(
                              key: Key(item.barcode),
                              direction: cart.isCorrectionMode
                                  ? DismissDirection.none
                                  : DismissDirection
                                      .horizontal, // 🛑 Disable swipe if locked
                              background: _buildSwipeBackground(
                                  Alignment.centerLeft, cart.isCorrectionMode),
                              secondaryBackground: _buildSwipeBackground(
                                  Alignment.centerRight, cart.isCorrectionMode),
                              onDismissed: (direction) {
                                final deletedItem = item;
                                cart.deleteItem(item.barcode);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text("${deletedItem.name} removed"),
                                    behavior: SnackBarBehavior.floating,
                                    margin: const EdgeInsets.only(
                                        bottom: 80, left: 10, right: 10),
                                    action: SnackBarAction(
                                      label: 'UNDO',
                                      textColor: Colors.yellow,
                                      onPressed: () async {
                                        try {
                                          await cart.add(
                                            barcode: deletedItem.barcode,
                                            name: deletedItem.name,
                                            price: deletedItem.originalPrice,
                                            gst: deletedItem.gst,
                                            weight: deletedItem.weight,
                                          );
                                          for (int i = 1;
                                              i < deletedItem.quantity;
                                              i++) {
                                            await cart
                                                .increment(deletedItem.barcode);
                                          }
                                        } catch (e) {
                                          // Ignore if stock runs out during undo
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: _buildCartItem(
                                  item, cart, cherryRedDark, context),
                            );
                          },
                        ),
                ),
                if (cart.items.isNotEmpty)
                  _buildBillSection(context, cart, cherryRedDark),
              ],
            ),
          ),

          if (cart.items.isNotEmpty)
            Positioned(
              top: 55,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.delete_sweep_outlined,
                    color: Colors.white),
                onPressed: () => _showClearCartDialog(context, cart),
              ),
            )
        ],
      ),
    );
  }

// ... inside _CartScreenState

  Widget _buildSwipeBackground(Alignment alignment, bool isCorrectionMode) {
    return Container(
      decoration: BoxDecoration(
          // Change color to grey if locked to show it's disabled
          color: isCorrectionMode ? Colors.grey[400] : Colors.red[400],
          borderRadius: BorderRadius.circular(15)),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Icon(isCorrectionMode ? Icons.lock_outline : Icons.delete_outline,
          color: Colors.white, size: 28),
    );
  }

  Widget _buildCartItem(CartItem item, CartService cart, Color primaryColor,
      BuildContext context) {
    // 🛡️ Determine if buttons should be disabled based on quantity OR Security Mode
    bool isMinusDisabled = item.quantity <= 1 || cart.isCorrectionMode;
    bool isPlusDisabled =
        cart.isCorrectionMode; // Lock plus button completely in correction mode

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.shopping_bag, color: primaryColor),
        ),
        title: Text(item.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.clearanceActive && item.clearanceType == 'PERCENT')
              Text("₹${item.originalPrice.toStringAsFixed(2)}",
                  style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                      fontSize: 12)),
            Text("₹${item.finalUnitPrice.toStringAsFixed(2)}",
                style: TextStyle(
                    color: item.clearanceActive
                        ? Colors.green.shade700
                        : primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            if (item.clearanceType == 'BOGO')
              Text("🎁 You get: ${item.effectiveQty} items",
                  style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🛑 MINUS BUTTON (Disabled in Correction Mode)
            _iconBtn(Icons.remove, () {
              if (cart.isCorrectionMode) {
                _showSecurityError(context,
                    "Quantity cannot be reduced during Guard Correction.");
                return;
              }
              cart.decrement(item.barcode);
            }, isDisabled: isMinusDisabled),

            SizedBox(
                width: 35,
                child: Text("${item.quantity}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16))),

            // 🛑 PLUS BUTTON (Disabled in Correction Mode)
            _iconBtn(Icons.add, () async {
              if (cart.isCorrectionMode) {
                _showSecurityError(
                    context, "Cannot add items during Guard Correction.");
                return;
              }
              try {
                await cart.increment(item.barcode);
              } catch (e) {
                _showSecurityError(context, e.toString());
              }
            }, color: primaryColor, isDisabled: isPlusDisabled),
          ],
        ),
      ),
    );
  }

  // Helper function to show errors consistently
  void _showSecurityError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.security, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap,
      {bool isDisabled = false, Color? color}) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey[200]
              : (color?.withOpacity(0.1) ?? Colors.grey[100]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon,
            size: 18,
            color: isDisabled ? Colors.grey : (color ?? Colors.black)),
      ),
    );
  }

  Widget _buildBillSection(
      BuildContext context, CartService cart, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total Amount",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text("₹${cart.grandTotal.toStringAsFixed(0)}",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: primaryColor.withOpacity(0.4)),
              onPressed: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CheckoutScreen()));
              },
              child: const Text("PROCEED TO CHECKOUT",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.remove_shopping_cart_outlined,
              size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text("Your Cart is Empty",
              style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ScanProductScreen()));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
                elevation: 4,
                shadowColor: primaryColor.withOpacity(0.4)),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text("Scan Items Now",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog(BuildContext context, CartService cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Cart?"),
        content: const Text("Remove all items?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("No")),
          TextButton(
              onPressed: () {
                cart.clear();
                Navigator.pop(ctx);
              },
              child: const Text("Yes", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}
