import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_profile_screen.dart';
import 'trust_score_screen.dart';
import 'order_history_screen.dart';
import 'auth_wrapper.dart';
import 'home_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);

  final String supportEmail = "support@clickout.com";
  final String supportPhone = "+919876543210";

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SingleChildScrollView(
        child: Stack(
          children: [
            Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cherryRedDark, cherryRedLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 10, bottom: 20),
                          child: Text(
                            "My Profile",
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'DejaVuSansMono',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // User Info Stream
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user?.uid)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final data =
                                snapshot.data?.data() as Map<String, dynamic>?;
                            final name = data?['name'] ?? 'ClickOut User';
                            final phone = user?.phoneNumber ?? '';
                            // ✅ FIX: Extract email from Firestore Stream
                            final email = data?['email'] ??
                                user?.email ??
                                'No email added';
                            final trustScore = data?['trustScore'] ?? 100;

                            return Column(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.white,
                                  child: Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : "U",
                                    style: TextStyle(
                                        fontSize: 30,
                                        color: cherryRedDark,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(name,
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'DejaVuSansMono')),
                                Text(phone,
                                    style:
                                        const TextStyle(color: Colors.white70)),

                                // ✅ FIX: Added the missing Email UI Display
                                Text(email,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12)),

                                const SizedBox(height: 15),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 15, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.shield,
                                          color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Text("Trust Score: $trustScore",
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // MENU OPTIONS
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _sectionTitle("Account"),
                      _menuItem(
                          context,
                          Icons.person,
                          "Edit Profile",
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen()))),

                      _menuItem(
                          context,
                          Icons.history,
                          "Order History",
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const OrderHistoryScreen()))),

                      const SizedBox(height: 10),
                      _sectionTitle("Trust & Safety"),
                      _menuItem(
                          context,
                          Icons.verified_user,
                          "Trust Score Policy",
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TrustScoreScreen()))),

                      const SizedBox(height: 10),
                      _sectionTitle("General"),
                      _menuItem(
                          context, Icons.notifications, "Notifications", () {}),
                      _menuItem(context, Icons.help, "Help & Support",
                          () => _showSupportOptions(context)),

                      const SizedBox(height: 20),

                      // LOGOUT BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cherryRedDark,
                            side: BorderSide(color: cherryRedDark),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AuthWrapper()),
                                (route) => false);
                          },
                          child: const Text("Log Out"),
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, top: 10),
                  child: CircleAvatar(
                    backgroundColor: Colors.black12,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text("How can we help?",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.chat, color: Colors.green),
              ),
              title: const Text("Chat on WhatsApp"),
              subtitle: const Text("Quickest response"),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
              onTap: () {
                Navigator.pop(context);
                _launchUri(
                    Uri.parse(
                        "https://wa.me/$supportPhone?text=Hi, I need help with ClickOut."),
                    context);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.email, color: Colors.blue),
              ),
              title: const Text("Email Us"),
              subtitle: const Text("For detailed queries"),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 16, color: Colors.grey),
              onTap: () {
                Navigator.pop(context);
                _launchUri(
                    Uri.parse(
                        "mailto:$supportEmail?subject=ClickOut Support Request"),
                    context);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUri(Uri uri, BuildContext context) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $uri';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Could not open app: $e"),
            backgroundColor: Colors.red),
      );
    }
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 10),
        child: Text(title,
            style: const TextStyle(
                color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  Widget _menuItem(
      BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: const Color(0xFFC62828)),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        trailing:
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
