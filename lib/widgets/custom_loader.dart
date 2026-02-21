import 'package:flutter/material.dart';
import 'dart:math';

class CustomLoader extends StatefulWidget {
  const CustomLoader({super.key});

  @override
  State<CustomLoader> createState() => _CustomLoaderState();
}

class _CustomLoaderState extends State<CustomLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // 😂 Funny Zepto Lines
  final List<String> _messages = [
    "You're the 10/10 of our lives",
    "Loading freshness...",
    "Do you know? You look great today!",
    "Desi Ghee > Olive Oil",
    "Making sure price is right...",
    "Sorting the best apples for you..."
  ];

  late String _randomMessage;

  @override
  void initState() {
    super.initState();
    _randomMessage =
        _messages[Random().nextInt(_messages.length)]; // Pick Random
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean White
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🥤 Bouncing Icon
            ScaleTransition(
              scale: Tween(begin: 1.0, end: 1.2).animate(CurvedAnimation(
                  parent: _controller, curve: Curves.easeInOut)),
              child: const Icon(Icons.local_drink_rounded,
                  size: 60, color: Colors.purple), // Purple Icon
            ),
            const SizedBox(height: 30),

            // 😂 Funny Text
            Text(
              _randomMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
