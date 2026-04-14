import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/cart/cart_service.dart';
import '../models/cart_item.dart';
import 'checkout_screen.dart';
import 'scan_product_screen.dart';
import 'home_screen.dart';

// ── Design tokens ─────────────────────────────────────────────────────────
const Color _red = Color(0xFFE53E3E);
const Color _redDark = Color(0xFFC53030);
const Color _redLight = Color(0xFFFFEBEB);
const Color _bg = Color(0xFFF6F6F4);
const Color _card = Color(0xFFFFFFFF);
const Color _divider = Color(0xFFE5E7EB);
const Color _text1 = Color(0xFF111111);
const Color _text2 = Color(0xFF6B7280);
const Color _text3 = Color(0xFF9CA3AF);
const Color _green = Color(0xFF16A34A);
const Color _greenBg = Color(0xFFDCFCE7);
const Color _amber = Color(0xFFF59E0B);

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runValidation());
  }

  Future<void> _runValidation() async {
    final cart = context.read<CartService>();
    List<String> changes = await cart.validateCart();
    if (!mounted) return;
    if (changes.isNotEmpty) _showChangesDialog(changes);
  }

  void _showChangesDialog(List<String> changes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _card,
        insetPadding: const EdgeInsets.all(20),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                    color: _redLight, shape: BoxShape.circle),
                child: const Icon(Icons.sync_rounded, color: _red, size: 28),
              ),
              const SizedBox(height: 14),
              Text("Cart Updated",
                  style: GoogleFonts.syne(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _text1)),
              const SizedBox(height: 6),
              Text("Latest prices & stock applied",
                  style: GoogleFonts.dmSans(fontSize: 13, color: _text2)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: _bg, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: changes
                      .map((msg) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 14, color: _amber),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(msg,
                                        style: GoogleFonts.dmSans(
                                            fontSize: 12, color: _text1))),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text("Got it",
                      style: GoogleFonts.syne(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    return Scaffold(
      backgroundColor: _bg,
      body: cart.items.isEmpty ? _buildEmpty() : _buildBody(cart),
    );
  }

  // ─── EMPTY STATE ─────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return SafeArea(
      child: Column(children: [
        _buildHeader(null),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: const BoxDecoration(
                      color: _redLight, shape: BoxShape.circle),
                  child: const Icon(Icons.shopping_bag_outlined,
                      color: _red, size: 44),
                ),
                const SizedBox(height: 20),
                Text("Your cart is empty",
                    style: GoogleFonts.syne(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _text1)),
                const SizedBox(height: 8),
                Text("Scan items to add them here",
                    style: GoogleFonts.dmSans(fontSize: 14, color: _text2)),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ScanProductScreen())),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30))),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                  label: Text("Scan Items",
                      style: GoogleFonts.syne(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ─── MAIN BODY ────────────────────────────────────────────────────────────
  Widget _buildBody(CartService cart) {
    // Group items by base barcode for consolidated display
    final List<_CartGroup> groups = _buildGroups(cart.items);

    return Column(
      children: [
        _buildHeader(cart),
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Savings banner (if any offers applied)
              if (cart.items.values.any((i) => i.clearanceActive))
                SliverToBoxAdapter(child: _buildSavingsBanner(cart)),

              // Cart items
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildGroupCard(groups[i], cart),
                    ),
                    childCount: groups.length,
                  ),
                ),
              ),

              // Bill section
              SliverToBoxAdapter(child: _buildBill(cart)),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ],
    );
  }

  // ─── HEADER ───────────────────────────────────────────────────────────────
  Widget _buildHeader(CartService? cart) {
    return Container(
      color: _card,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: _text1),
                    onPressed: () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (r) => false),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Your Cart",
                            style: GoogleFonts.syne(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: _text1)),
                        if (cart != null)
                          Text(
                              "${cart.totalItems} item${cart.totalItems == 1 ? '' : 's'}",
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, color: _text2)),
                      ],
                    ),
                  ),
                  if (cart != null && cart.items.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _showClearDialog(cart),
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: _red),
                      label: Text("Clear",
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: _red,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: _divider),
          ],
        ),
      ),
    );
  }

  // ─── SAVINGS BANNER ───────────────────────────────────────────────────────
  Widget _buildSavingsBanner(CartService cart) {
    double saved = 0;
    int freeQty = 0;
    cart.items.forEach((key, item) {
      if (key.endsWith('_FREE')) {
        freeQty += item.quantity;
        return;
      }
      if (item.clearanceActive) {
        saved += (item.originalPrice - item.finalUnitPrice) * item.quantity;
      }
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _greenBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: _green.withOpacity(0.15), shape: BoxShape.circle),
            child:
                const Icon(Icons.celebration_rounded, color: _green, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("You're saving on this order!",
                    style: GoogleFonts.syne(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _green)),
                Text(
                  [
                    if (saved > 0) "₹${saved.toStringAsFixed(0)} discount",
                    if (freeQty > 0)
                      "$freeQty free item${freeQty > 1 ? 's' : ''}",
                  ].join(" + "),
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: _green.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── GROUP BUILDER ────────────────────────────────────────────────────────
  List<_CartGroup> _buildGroups(Map<String, CartItem> items) {
    final Map<String, _CartGroup> groups = {};
    items.forEach((key, item) {
      final String base =
          key.replaceAll('_FREE', '').replaceAll('_OVERFLOW', '');
      if (!groups.containsKey(base)) {
        groups[base] = _CartGroup(baseKey: base);
      }
      if (key.endsWith('_FREE')) {
        groups[base]!.freeItem = item;
      } else if (key.endsWith('_OVERFLOW')) {
        groups[base]!.overflowItem = item;
      } else {
        groups[base]!.baseItem = item;
      }
    });
    return groups.values.toList();
  }

  // ─── CARD FOR ONE PRODUCT GROUP ───────────────────────────────────────────
  Widget _buildGroupCard(_CartGroup group, CartService cart) {
    final CartItem? base = group.baseItem;
    final CartItem? free = group.freeItem;
    final CartItem? overflow = group.overflowItem;

    if (base == null && free == null && overflow == null) {
      return const SizedBox.shrink();
    }

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

    return Dismissible(
      key: Key(group.baseKey),
      direction: cart.isCorrectionMode
          ? DismissDirection.none
          : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
            color: _red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: _red, size: 24),
      ),
      onDismissed: (_) {
        final name = display.name;
        cart.deleteItem(group.baseKey);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("$name removed"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _text1,
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
                for (int i = 1; i < totalQty; i++) {
                  await cart.increment(display.barcode);
                }
              } catch (_) {}
            },
          ),
        ));
      },
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: hasOffer
              ? Border.all(color: _green.withOpacity(0.25))
              : Border.all(color: _divider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: hasOffer
                          ? _green.withOpacity(0.08)
                          : _red.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.shopping_bag_outlined,
                        color: hasOffer ? _green : _red, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // Name + price info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(display.name,
                            style: GoogleFonts.syne(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _text1),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (hasOffer &&
                                base != null &&
                                base.clearanceType != 'BOGO' &&
                                base.clearanceType != 'BUY_X_GET_Y' &&
                                base.clearanceType != 'FREE_ITEM')
                              Text("₹${mrp.toStringAsFixed(0)}",
                                  style: GoogleFonts.dmSans(
                                      fontSize: 11,
                                      color: _text3,
                                      decoration: TextDecoration.lineThrough)),
                            if (hasOffer &&
                                base != null &&
                                base.clearanceType != 'BOGO' &&
                                base.clearanceType != 'BUY_X_GET_Y' &&
                                base.clearanceType != 'FREE_ITEM')
                              const SizedBox(width: 6),
                            Text(
                              hasOffer &&
                                      base != null &&
                                      base.clearanceType != 'BOGO' &&
                                      base.clearanceType != 'BUY_X_GET_Y'
                                  ? "₹${base.finalUnitPrice.toStringAsFixed(0)}/item"
                                  : "₹${mrp.toStringAsFixed(0)}/item",
                              style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  color: hasOffer ? _green : _text2,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Total price (right side)
                  Text("₹${paidTotal.toStringAsFixed(0)}",
                      style: GoogleFonts.syne(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _text1)),
                ],
              ),

              // BOGO / Free item row
              if (freeQty > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _greenBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _green.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.card_giftcard_rounded,
                          color: _green, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _offerLabel(offerType, base?.buyQty ?? 1,
                              base?.freeQty ?? freeQty),
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: _green,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(100)),
                        child: Text("+$freeQty FREE",
                            style: GoogleFonts.syne(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],

              // Qty stepper
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: qty info
                  Text(
                    freeQty > 0
                        ? "$paidQty paid  ·  $freeQty free  =  $totalQty items"
                        : "$totalQty item${totalQty == 1 ? '' : 's'}",
                    style: GoogleFonts.dmSans(fontSize: 11, color: _text2),
                  ),

                  // Right: stepper (acts on base/total qty)
                  Row(
                    children: [
                      _stepBtn(Icons.remove_rounded, () {
                        if (cart.isCorrectionMode) {
                          _snack("Locked during correction");
                          return;
                        }
                        try {
                          cart.decrement(group.baseKey);
                        } catch (e) {
                          _snack(e.toString());
                        }
                      }, enabled: !cart.isCorrectionMode && totalQty > 1),
                      SizedBox(
                        width: 36,
                        child: Text("$totalQty",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.syne(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: _text1)),
                      ),
                      _stepBtn(Icons.add_rounded, () async {
                        if (cart.isCorrectionMode) {
                          _snack("Locked during correction");
                          return;
                        }
                        try {
                          await cart.increment(group.baseKey);
                        } catch (e) {
                          _snack(e.toString());
                        }
                      }, enabled: !cart.isCorrectionMode, isAdd: true),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap,
      {bool enabled = true, bool isAdd = false}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? (isAdd ? _red.withOpacity(0.1) : _bg) : _bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enabled
                  ? (isAdd ? _red.withOpacity(0.3) : _divider)
                  : _divider),
        ),
        child: Icon(icon,
            size: 16, color: enabled ? (isAdd ? _red : _text1) : _text3),
      ),
    );
  }

  String _offerLabel(String type, int buyQty, int freeQty) {
    switch (type) {
      case 'BOGO':
        return "Buy 1 Get 1 Free";
      case 'BUY_X_GET_Y':
        return "Buy $buyQty Get $freeQty Free";
      case 'BUY_X_GET_Y_CROSS':
        return "Cross-Product: $freeQty item(s) free";
      case 'FREE_ITEM':
        return "Free item applied";
      default:
        return "Offer applied";
    }
  }

  // ─── BILL SECTION ─────────────────────────────────────────────────────────
  Widget _buildBill(CartService cart) {
    final TextEditingController promoCtrl = TextEditingController();
    double itemTotal = 0;
    double totalSavings = 0;
    cart.items.forEach((key, item) {
      if (key.endsWith('_FREE')) return; // free items add 0 to total already
      itemTotal += item.originalPrice * item.quantity;
    });
    totalSavings = itemTotal - (cart.grandTotal + cart.promoDiscountAmount);
    if (totalSavings < 0) totalSavings = 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, -2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Bill Summary",
              style: GoogleFonts.syne(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _text1)),
          const SizedBox(height: 16),

          // Promo code
          if (cart.appliedPromoCode == null) ...[
            Container(
              decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _divider)),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.local_offer_outlined,
                      color: _amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: promoCtrl,
                      textCapitalization: TextCapitalization.characters,
                      style: GoogleFonts.dmSans(fontSize: 13, color: _text1),
                      decoration: InputDecoration(
                        hintText: "Enter promo code",
                        hintStyle:
                            GoogleFonts.dmSans(fontSize: 13, color: _text3),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (promoCtrl.text.trim().isEmpty) return;
                      try {
                        await cart.applyPromoCode(
                            promoCtrl.text.trim().toUpperCase());
                        if (mounted) _snack("Promo applied!", isError: false);
                      } catch (e) {
                        if (mounted) _snack(e.toString());
                      }
                    },
                    child: Text("APPLY",
                        style: GoogleFonts.syne(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _amber)),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _greenBg, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: _green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("'${cart.appliedPromoCode}' applied",
                              style: GoogleFonts.dmSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _green)),
                          Text(
                              "Saving ₹${cart.promoDiscountAmount.toStringAsFixed(0)}",
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: _green)),
                        ]),
                  ),
                  GestureDetector(
                    onTap: cart.removePromoCode,
                    child: Text("REMOVE",
                        style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: _red,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          _billRow("Item Total", "₹${itemTotal.toStringAsFixed(0)}"),
          if (totalSavings > 0) ...[
            const SizedBox(height: 8),
            _billRow("Offer Savings", "-₹${totalSavings.toStringAsFixed(0)}",
                valueColor: _green),
          ],
          if (cart.promoDiscountAmount > 0) ...[
            const SizedBox(height: 8),
            _billRow("Promo Discount",
                "-₹${cart.promoDiscountAmount.toStringAsFixed(0)}",
                valueColor: _green),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: _divider),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Grand Total",
                  style: GoogleFonts.syne(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _text1)),
              Text("₹${cart.grandTotal.toStringAsFixed(0)}",
                  style: GoogleFonts.syne(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _red)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CheckoutScreen())),
              child: Text(
                  cart.isCorrectionMode
                      ? "Fix & Resubmit"
                      : "Proceed to Checkout",
                  style: GoogleFonts.syne(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: _text2)),
        Text(value,
            style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? _text1)),
      ],
    );
  }

  // ─── DIALOGS & HELPERS ────────────────────────────────────────────────────
  void _showClearDialog(CartService cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: _card,
        title: Text("Clear Cart?",
            style:
                GoogleFonts.syne(fontWeight: FontWeight.w700, color: _text1)),
        content: Text("All items will be removed.",
            style: GoogleFonts.dmSans(color: _text2)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("Cancel", style: GoogleFonts.dmSans(color: _text2))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              cart.clear();
              Navigator.pop(ctx);
            },
            child: Text("Clear",
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: GoogleFonts.dmSans(
                    color: Colors.white, fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: isError ? _redDark : _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }
}

// ── Data class for grouped display ───────────────────────────────────────────
class _CartGroup {
  final String baseKey;
  CartItem? baseItem;
  CartItem? freeItem;
  CartItem? overflowItem;
  _CartGroup({required this.baseKey});
}
