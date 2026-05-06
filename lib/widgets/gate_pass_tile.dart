import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/active_gate_pass_screen.dart'; // 🚀 POINT TO NEW ACTIVE SCREEN

class GatePassTile extends StatelessWidget {
  const GatePassTile({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ActiveGatePassScreen())),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.receipt_long_rounded,
                  color: Color(0xFFF59E0B), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Active Gate Passes",
                      style: GoogleFonts.syne(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF111111))),
                  Text("View your pending & active orders",
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: const Color(0xFF9CA3AF))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF9CA3AF), size: 14),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}
