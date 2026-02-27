import 'dart:async';
import 'package:clickout/screens/auth_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';
import '../core/unified_auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with CodeAutoFill {
  final phoneController = TextEditingController();
  final otpController = TextEditingController();

  // 🔥 Cherry Colors
  final Color cherryRedLight = const Color(0xFFEF5350);
  final Color cherryRedDark = const Color(0xFFC62828);

  bool isOtpSent = false;
  bool loading = false;
  String? _verificationId;

  // ⏱️ Resend Timer Logic
  Timer? _timer;
  int _start = 60; // 🧠 Changed to 60s to match Unified Service cooldown
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    listenForCode();
  }

  @override
  void codeUpdated() {
    setState(() {
      otpController.text = code ?? "";
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _start = 60;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _timer?.cancel();
          _canResend = true;
        });
      } else {
        setState(() => _start--);
      }
    });
  }

  void _resendOtp() async {
    if (!_canResend) return;

    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Resending OTP...")),
    );

    await UnifiedAuthService.sendPhoneOtp(
      phone: '+91${phoneController.text}',
      onCodeSent: (verificationId) {
        setState(() => _verificationId = verificationId);
        listenForCode();
      },
      onError: (error) => _showError(error),
    );
  }

  // ⚡ 🧠 UNIFIED LOGIC
  void _handleButtonPress() async {
    if (isOtpSent) {
      // ---> VERIFY
      if (otpController.text.length != 6) {
        _showError('Please enter 6 digit OTP');
        return;
      }
      setState(() => loading = true);

      try {
        await UnifiedAuthService.verifyOtpAndLogin(
          verificationId: _verificationId!,
          smsCode: otpController.text,
          roleCollection: 'users',
          initialData: {
            'trustScore': 100,
            'totalVisits': 0
          }, // Auto-create data
        );

        setState(() => loading = false);
        _timer?.cancel();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (route) => false,
          );
        }
      } catch (e) {
        setState(() => loading = false);
        _showError(e.toString());
      }
    } else {
      // ---> SEND OTP
      if (phoneController.text.length != 10) {
        _showError('Enter valid 10 digit number');
        return;
      }
      setState(() => loading = true);

      await UnifiedAuthService.sendPhoneOtp(
        phone: '+91${phoneController.text}',
        onCodeSent: (verificationId) {
          setState(() {
            loading = false;
            isOtpSent = true;
            _verificationId = verificationId;
          });
          _startTimer();
          listenForCode();
        },
        onError: (error) {
          setState(() => loading = false);
          _showError(error);
        },
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(msg, style: const TextStyle(fontFamily: 'DejaVuSansMono')),
          backgroundColor: Colors.black87),
    );
  }

  // UI REMAINS EXACTLY THE SAME (Untouched)
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cherryRedLight, cherryRedDark],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10))
                      ],
                    ),
                    child: Icon(Icons.shopping_cart_rounded,
                        color: cherryRedDark, size: 50),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'CLICKOUT',
                    style: TextStyle(
                      fontFamily: 'DejaVuSansMono',
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      isOtpSent
                          ? 'Verify OTP'
                          : 'Zero Queue.\nFastest Checkout.',
                      key: ValueKey(isOtpSent),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'DejaVuSansMono',
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isOtpSent
                        ? "Enter code sent to +91 ${phoneController.text}"
                        : "Login to start shopping",
                    style: TextStyle(
                        fontFamily: 'DejaVuSansMono',
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12),
                  ),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: isOtpSent ? _buildOtpInput() : _buildPhoneInput(),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: cherryRedDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 5,
                      ),
                      onPressed: loading ? null : _handleButtonPress,
                      child: loading
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                  color: cherryRedDark, strokeWidth: 3))
                          : Text(
                              isOtpSent ? 'VERIFY & LOGIN' : 'GET OTP',
                              style: const TextStyle(
                                fontFamily: 'DejaVuSansMono',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                  if (isOtpSent)
                    Padding(
                      padding: const EdgeInsets.only(top: 25),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                isOtpSent = false;
                                otpController.clear();
                                _timer?.cancel();
                              });
                            },
                            child: const Text(
                              "Change Number",
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontFamily: 'DejaVuSansMono',
                                  decoration: TextDecoration.underline),
                            ),
                          ),
                          Container(
                              height: 15,
                              width: 1,
                              color: Colors.white30,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 10)),
                          TextButton(
                            onPressed: _canResend ? _resendOtp : null,
                            child: Text(
                              _canResend ? "Resend OTP" : "Resend in $_start s",
                              style: TextStyle(
                                  color: _canResend
                                      ? Colors.white
                                      : Colors.white30,
                                  fontFamily: 'DejaVuSansMono',
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneInput() {
    return Container(
      key: const ValueKey('phone'),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          const Text('+91',
              style: TextStyle(
                  fontFamily: 'DejaVuSansMono',
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Container(height: 24, width: 1, color: Colors.white30),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              style: const TextStyle(
                  fontFamily: 'DejaVuSansMono',
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Mobile Number',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontFamily: 'DejaVuSansMono'),
                border: InputBorder.none,
                counterText: "",
              ),
              maxLength: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpInput() {
    return Container(
      key: const ValueKey('otp'),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: TextField(
        controller: otpController,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        autofillHints: const [AutofillHints.oneTimeCode],
        style: const TextStyle(
            fontFamily: 'DejaVuSansMono',
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: '------',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
          border: InputBorder.none,
          counterText: "",
        ),
        maxLength: 6,
      ),
    );
  }
}
