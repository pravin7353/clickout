import 'package:flutter/material.dart';

class TrustScoreScreen extends StatelessWidget {
  const TrustScoreScreen({super.key});

  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);
  final Color goldAccent = const Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text("Trust Score Policy",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        backgroundColor: cherryRedDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 🌟 VIP HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cherryRedDark, cherryRedLight],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.shield, size: 80, color: Colors.amber),
                  const SizedBox(height: 15),
                  const Text(
                    "The ClickOut Trust System",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'DejaVuSansMono'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "We start every citizen with a tremendous score of 80/100. Keep it high for VIP benefits. Play games, and your score will drop.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.5),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // 🏆 TIER SYSTEM CARD
                  _buildSectionCard(
                    title: "Status Tiers & Benefits",
                    icon: Icons.workspace_premium,
                    iconColor: Colors.amber,
                    children: [
                      _buildTierRow(
                          Icons.verified_user,
                          "VIP Green Channel (90 - 100)",
                          "Lightning-fast exits. Zero random bag checks.",
                          Colors.green),
                      _buildTierRow(
                          Icons.check_circle,
                          "Standard Citizen (60 - 89)",
                          "Standard scanning and normal security checks.",
                          Colors.blue),
                      _buildTierRow(
                          Icons.warning_amber_rounded,
                          "The Watchlist (30 - 59)",
                          "Account flagged. 100% full bag security audits.",
                          Colors.orange),
                      _buildTierRow(
                          Icons.block,
                          "Blacklisted (0 - 29)",
                          "Mobile checkout disabled. Wait in the physical line.",
                          Colors.red),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // 📈 REWARDS CARD
                  _buildSectionCard(
                    title: "How to Win (Rewards)",
                    icon: Icons.trending_up,
                    iconColor: Colors.green,
                    children: [
                      _buildBullet("Clear Exit (+2 Pts):",
                          "Complete your payment and pass the gate smoothly."),
                      _buildBullet("The Climb is Hard:",
                          "If your score drops below 60, recovering points becomes 50% slower. Below 40? It takes tremendous effort to win our trust back."),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // 📉 PENALTIES CARD
                  _buildSectionCard(
                    title: "The Penalties (Tariffs)",
                    icon: Icons.trending_down,
                    iconColor: Colors.red,
                    children: [
                      _buildBullet("Minor Mismatch (-8 Pts):",
                          "Small scanning errors caught at the gate."),
                      _buildBullet("Medium Mismatch (-15 Pts):",
                          "Multiple wrong items or missing barcodes."),
                      _buildBullet("Confirmed Theft (-25 Pts):",
                          "Intentional concealment of unpaid items."),
                      _buildBullet("Abandoned Cart (-5 Pts):",
                          "Generating a Gate Pass but ghosting the system for 8 hours."),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // 💡 INFO BANNER
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            "The Trust Score updates automatically in real-time. Our system is watching, so make shopping great again!",
                            style: TextStyle(
                                color: Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title,
      required IconData icon,
      required Color iconColor,
      required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ],
          ),
          const Divider(height: 25, thickness: 1, color: Color(0xFFEEEEEE)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTierRow(
      IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: color)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String boldText, String normalText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 8, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    color: Colors.black87, fontSize: 13, height: 1.5),
                children: [
                  TextSpan(
                      text: "$boldText ",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(
                      text: normalText,
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
