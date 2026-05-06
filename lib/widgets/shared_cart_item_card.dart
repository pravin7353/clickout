import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/cart/cart_service.dart';
import '../models/cart_item.dart';

// ── Design tokens (Extracted from Cart Screen) ──
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

// ── Shared Data Model & Helper ──
class CartGroup {
  final String baseKey;
  CartItem? baseItem;
  CartItem? freeItem;
  CartItem? overflowItem;
  CartGroup({required this.baseKey});
}

List<CartGroup> buildCartGroups(Map<String, CartItem> items) {
  final Map<String, CartGroup> groups = {};
  items.forEach((key, item) {
    final String base = key.replaceAll('_FREE', '').replaceAll('_OVERFLOW', '');
    if (!groups.containsKey(base)) {
      groups[base] = CartGroup(baseKey: base);
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

// ── Shared UI Widget ──
class SharedCartItemCard extends StatelessWidget {
  final CartGroup group;
  final CartService cart;

  const SharedCartItemCard(
      {super.key, required this.group, required this.cart});

  @override
  Widget build(BuildContext context) {
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
        (base?.totalPrice ?? 0.0) + (overflow?.totalPrice ?? 0.0);
    final double mrp = display.originalPrice;
    final bool hasOffer = (base?.clearanceActive ?? false) || freeQty > 0;
    final String offerType =
        base?.clearanceType ?? (freeQty > 0 ? 'FREE_ITEM' : '');

    return Dismissible(
      key: ValueKey(group.baseKey),
      confirmDismiss: (direction) async {
        if (cart.isCorrectionMode) {
          _snack(context, "Item locked during correction.");
          return false;
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
            color: _red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline_rounded, color: _red, size: 24),
      ),
      onDismissed: (direction) {
        final name = display.name;
        final messenger = ScaffoldMessenger.of(context);
        cart.deleteItem(group.baseKey);
        messenger.clearSnackBars();
        messenger.showSnackBar(SnackBar(
          content: Text("$name removed"),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _text1,
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.yellow,
            onPressed: () async {
              messenger.removeCurrentSnackBar();
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
                  Text("₹${paidTotal.toStringAsFixed(0)}",
                      style: GoogleFonts.syne(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _text1)),
                ],
              ),
              if (base != null && base.offerHint.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: _amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: _amber, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(base.offerHint,
                            style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: _amber,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
              if (base != null && base.flashExpiry > 0) ...[
                const SizedBox(height: 10),
                _buildCountdownTimer(base.flashExpiry),
              ],
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
                                fontWeight: FontWeight.w600)),
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    freeQty > 0
                        ? "$paidQty paid  ·  $freeQty free  =  $totalQty items"
                        : "$totalQty item${totalQty == 1 ? '' : 's'}",
                    style: GoogleFonts.dmSans(fontSize: 11, color: _text2),
                  ),
                  Row(
                    children: [
                      _stepBtn(Icons.remove_rounded, () {
                        if (cart.isCorrectionMode) {
                          _snack(context, "Locked during correction");
                          return;
                        }
                        try {
                          cart.decrement(group.baseKey);
                        } catch (e) {
                          _snack(context, e.toString());
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
                          _snack(context, "Locked during correction");
                          return;
                        }
                        try {
                          await cart.increment(group.baseKey);
                        } catch (e) {
                          _snack(context, e.toString());
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

  Widget _buildCountdownTimer(int expiryMs) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final diff = expiryMs - DateTime.now().millisecondsSinceEpoch;
        if (diff <= 0) return const SizedBox.shrink();
        int h = (diff ~/ 3600000);
        int m = ((diff ~/ 60000) % 60);
        int s = ((diff ~/ 1000) % 60);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _red.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.timer_outlined, color: _red, size: 14),
              const SizedBox(width: 6),
              Text(
                "Ends in ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}",
                style: GoogleFonts.dmSans(
                    fontSize: 12, color: _red, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      },
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

  void _snack(BuildContext context, String msg, {bool isError = true}) {
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
