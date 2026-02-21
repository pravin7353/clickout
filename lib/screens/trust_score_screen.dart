import 'package:flutter/material.dart';

class TrustScoreScreen extends StatelessWidget {
  const TrustScoreScreen({super.key});

  final Color cherryRedDark = const Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Trust Score Policy",
            style: TextStyle(fontFamily: 'DejaVuSansMono')),
        backgroundColor: cherryRedDark,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HERO SECTION
            Center(
              child: Column(
                children: [
                  Icon(Icons.shield_rounded, size: 80, color: cherryRedDark),
                  const SizedBox(height: 10),
                  const Text("What is Trust Score?",
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'DejaVuSansMono')),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Your Trust Score reflects your reliability as a ClickOut shopper. A high score unlocks faster checkouts and exclusive rewards.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 40),

            // RULES
            _buildSection(
                "📈 How to Increase Score",
                [
                  "Complete payments successfully.",
                  "Scan items correctly without mismatch at the gate.",
                  "Regularly use the app for shopping."
                ],
                Colors.green),

            _buildSection(
                "📉 Why Score Decreases",
                [
                  "Items found in bag but not scanned (Theft Attempt).",
                  "Frequent payment failures.",
                  "Misbehavior with security staff."
                ],
                Colors.red),

            _buildSection(
                "🏆 Rewards & Consequences",
                [
                  "Score 100+: Premium Status (No random checks).",
                  "Score < 50: Account flagged for manual checking.",
                  "Score 0: Account permanent ban."
                ],
                Colors.blue),

            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(
                children: [
                  Icon(Icons.info, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                      child: Text(
                          "Note: Trust Score is updated automatically after every order completion.")),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> points, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'DejaVuSansMono')),
          const SizedBox(height: 10),
          ...points.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• ",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(child: Text(p)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
