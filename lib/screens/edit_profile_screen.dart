import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_wrapper.dart'; // Ensure this import points to your login screen wrapper

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // 📝 Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  final User? user = FirebaseAuth.instance.currentUser;

  // 🎨 ClickOut Theme Colors
  final Color primaryColor = const Color(0xFFC62828); // Cherry Red
  final Color inputFillColor = const Color(0xFFF5F5F5); // Light Grey
  final Color labelColor = const Color(0xFF2C3E50); // Dark Blue-Grey

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user != null) {
      _phoneController.text = user!.phoneNumber ?? '';
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _nameController.text = data['name'] ?? '';
              // ✅ UI Source of truth: Always prefer Firestore email over stale Auth email
              _emailController.text = data['email'] ?? user!.email ?? '';
              _addressController.text = data['address'] ?? '';
            });
          }
        }
      } catch (e) {
        debugPrint("Error: $e");
      }
    }
  }

  // 🔍 DUPLICATE CHECK
  Future<bool> _isEmailTaken(String email) async {
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .get();

    if (query.docs.isNotEmpty) {
      for (var doc in query.docs) {
        if (doc.id != user!.uid) return true;
      }
    }
    return false;
  }

  // 💾 SAVE PROFILE
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String newEmail = _emailController.text.trim();
      String cleanPhone = _phoneController.text.trim();
      if (!cleanPhone.startsWith('+')) cleanPhone = "+91$cleanPhone";

      // 1. Duplicate Check
      bool isTaken = await _isEmailTaken(newEmail);
      if (isTaken) {
        _showSnack("❌ Email already exists!", isError: true);
        setState(() => _isLoading = false);
        return;
      }

      // 🛡️ 2. Auth Email Update (FIXED: No more silent failures)
      if (newEmail != user!.email && newEmail.isNotEmpty) {
        try {
          await user!.verifyBeforeUpdateEmail(newEmail);
          _showSnack("ℹ️ Verification link sent to new email.");
        } on FirebaseAuthException catch (e) {
          // If session is too old, Firebase blocks email changes for security.
          if (e.code == 'requires-recent-login') {
            _showSnack(
                "⚠️ Security: Please Log Out & Login again to change email.",
                isError: true);
            setState(() => _isLoading = false);
            return; // 🛑 Block Firestore update if Auth update fails
          } else {
            _showSnack("Auth Error: ${e.message}", isError: true);
          }
        } catch (e) {
          debugPrint("Minor Auth Error: $e");
        }
      }

      // 3. Save to Firestore (Single Source of Truth)
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': _nameController.text.trim(),
        'email': newEmail, // ✅ Synced directly to DB
        'address': _addressController.text.trim(),
        'phone': cleanPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _showSnack("✅ Profile Updated Successfully!");
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack("Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🛑 DELETE ACCOUNT LOGIC (Secure & Compliant)
  Future<void> _deleteCustomerAccount() async {
    if (user == null) return;

    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      String uid = user!.uid;
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': 'Deleted User',
        'email': 'deleted_${timestamp}_$uid@clickout.void',
        'phone': 'del_${timestamp}_$uid',
        'address': '',
        'trustScore': 0,
        'fcmToken': FieldValue.delete(),
        'isDeleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      await user!.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Account deleted successfully."),
              backgroundColor: Colors.grey),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        _showSnack(
            "⚠️ Security: Please Log Out and Login again to delete account.",
            isError: true);
      } else {
        _showSnack("Error: ${e.message}", isError: true);
      }
    } catch (e) {
      _showSnack("System Error: $e", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🗑️ SHOW CONFIRMATION DIALOG
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Delete Account?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "This will permanently remove your profile, wallet, and personal data.\n\nPast orders will be anonymized for audit purposes.\n\nThis action cannot be undone.",
          style: TextStyle(color: Colors.black87),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: _deleteCustomerAccount,
            child: const Text("Yes, Delete",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Profile",
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Name *"),
              _buildInputField(
                  _nameController, "Enter your name", Icons.person_outline),
              const SizedBox(height: 20),
              _buildLabel("Mobile Number *"),
              _buildInputField(_phoneController, "", Icons.lock_outline,
                  isReadOnly: true),
              const SizedBox(height: 20),
              _buildLabel("Email Address *"),
              _buildInputField(
                  _emailController, "Enter email", Icons.email_outlined),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 5),
                child: Text(
                  "We promise not to spam you",
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),
              _buildLabel("Address"),
              _buildInputField(_addressController, "Enter your full address",
                  Icons.home_outlined,
                  maxLines: 3),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5)),
                            SizedBox(width: 10),
                            Text("Saving...",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ],
                        )
                      : const Text("Submit",
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 20),
              Text("Delete Account",
                  style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 10),
              Text(
                "Deleting your account will remove all your orders, wallet amount and any active referral.",
                style: TextStyle(
                    color: Colors.grey[600], fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text("Delete Account"),
                  onPressed: _isLoading ? null : _showDeleteConfirmation,
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: labelColor),
      ),
    );
  }

  Widget _buildInputField(
      TextEditingController controller, String hint, IconData icon,
      {bool isReadOnly = false, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: isReadOnly
            ? Colors.grey.shade200
            : inputFillColor, // 🚀 Grey out disabled fields
        borderRadius: BorderRadius.circular(12),
        border: isReadOnly ? Border.all(color: Colors.grey.shade300) : null,
      ),
      child: TextFormField(
        controller: controller,
        readOnly: isReadOnly,
        maxLines: maxLines,
        style: TextStyle(
            color: isReadOnly ? Colors.grey[600] : Colors.black,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon:
              Icon(icon, color: isReadOnly ? Colors.grey : primaryColor),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: (val) {
          if (!isReadOnly && (val == null || val.isEmpty)) {
            return "Required field";
          }
          return null;
        },
      ),
    );
  }
}
