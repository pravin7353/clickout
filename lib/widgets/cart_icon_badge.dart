import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cart/cart_service.dart';
import '../theme/app_theme.dart'; // Brand colors ke liye

class CartIconBadge extends StatelessWidget {
  final Widget icon; // ✅ Ab ye Icon lega (Flexible)
  final VoidCallback? onTap;

  const CartIconBadge({
    super.key,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 🔥 Provider se count suno (Watch)
    final cartItemCount =
        context.select<CartService, int>((service) => service.totalItems);

    Widget badgeContent = Stack(
      clipBehavior: Clip.none,
      children: [
        icon, // Jo icon tum pass karoge (Outlined ya Filled)

        if (cartItemCount > 0)
          Positioned(
            right: -4, // Thoda bahar nikalo
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppTheme.accentOrange, // 🔥 Brand Color
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Center(
                child: Text(
                  cartItemCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );

    // Agar onTap diya hai to clickable banao, nahi to sirf icon dikhao
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: badgeContent,
        ),
      );
    }

    return badgeContent;
  }
}
