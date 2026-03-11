import 'package:flutter/material.dart';
import '../services/cart/cart_service.dart';
import '../models/cart_item.dart'; // ✅ YE LINE MISSING THI (Ab Red Line Jayegi)

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final CartService cart;

  const ProductCard({super.key, required this.product, required this.cart});

  @override
  Widget build(BuildContext context) {
    // Check if item is in cart
    final String currentBarcode = product['barcode'].toString();

    // ✅ Fix Logic: CartItem dhundne ka safe tareeka
    CartItem? existingItem;
    if (cart.items.containsKey(currentBarcode)) {
      existingItem = cart.items[currentBarcode];
    }

    final int quantity = existingItem?.quantity ?? 0;
    final bool isInCart = quantity > 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(product['name'],
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("₹${product['price']}"),
        trailing: isInCart
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => cart.decrement(currentBarcode),
                  ),
                  Text('$quantity',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.green),
                    onPressed: () => cart.increment(currentBarcode),
                  ),
                ],
              )
            : ElevatedButton(
                onPressed: () {
                  // ✅ FIX: Adding with Weight
                  cart.add(
                    barcode: currentBarcode,
                    name: product['name'],
                    price: double.parse(product['price'].toString()),
                    gst: double.parse(product['gst'].toString()),
                    weight: product['weight'] != null
                        ? double.parse(product['weight'].toString())
                        : 0.0,
                  );
                },
                child: const Text("ADD"),
              ),
      ),
    );
  }
}
