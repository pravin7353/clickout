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
  int _start = 15; // 🧠 FAST UX: 15 seconds cooldown
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

    // 🚀 THE MAGIC: JAISE HI 6 DIGIT KA OTP AAYEGA, YE KHUD LOGIN DABA DEGA!
    if (otpController.text.length == 6 && _verificationId != null) {
      _verifyOtp();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    cancel(); // Cancel SMS listener
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _start = 15;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _start--;
        });
      }
    });
  }

  void _sendOtp() async {
    if (phoneController.text.length != 10) {
      _showError("Please enter a valid 10-digit number");
      return;
    }

    setState(() => loading = true);

    await UnifiedAuthService.sendPhoneOtp(
      phone: "+91${phoneController.text}",
      onCodeSent: (id) {
        setState(() {
          _verificationId = id;
          isOtpSent = true;
          loading = false;
        });
        _startTimer();
      },
      onError: (err) {
        setState(() => loading = false);
        _showError(err);
      },
      onAutoLoginSuccess: () async {
        // 🚀 THE FIX: Firebase ko data save karne ke liye 500ms do
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (route) => false,
          );
        }
      },
    );
  }

  void _verifyOtp() async {
    String code = otpController.text.trim();
    if (code.length != 6) {
      _showError("Please enter the 6-digit OTP");
      return;
    }

    setState(() => loading = true);

    await UnifiedAuthService.verifyManualOTP(
      verificationId: _verificationId!,
      otp: code,
      onSuccess: () async {
        // 🚀 THE FIX: Memory aur DB save hone ka wait karo
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (route) => false,
          );
        }
      },
      onError: (err) {
        setState(() {
          loading = false;
          otpController.clear();
        });
        _showError(err);
      },
    );
  }

  void _resendOtp() async {
    if (!_canResend) return;

    setState(() => loading = true);

    await UnifiedAuthService.sendPhoneOtp(
      phone: "+91${phoneController.text}",
      onCodeSent: (id) {
        setState(() {
          _verificationId = id;
          loading = false;
        });
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("OTP Resent Successfully",
                  style: TextStyle(color: Colors.white)),
              backgroundColor: Color.fromARGB(255, 255, 255, 255)),
        );
      },
      onError: (err) {
        setState(() => loading = false);
        _showError(err);
      },
      onAutoLoginSuccess: () {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthWrapper()),
            (route) => false,
          );
        }
      },
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔴 SOLID BACKGROUND GRADIENT MATCHING SCREENSHOT
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cherryRedLight, cherryRedDark],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 🛒 WHITE LOGO CIRCLE
                    Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ]),
                      child: Icon(Icons.shopping_cart,
                          size: 55, color: cherryRedDark),
                    ),
                    const SizedBox(height: 25),

                    // 🏷️ BRAND NAME
                    const Text("CLICKOUT",
                        style: TextStyle(
                            fontFamily: 'DejaVuSansMono',
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 6)),
                    const SizedBox(height: 50),

                    // 🍔 FLOATING MENU + TAGLINES
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Column(
                            children: [
                              const Text("Zero Queue.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontFamily: 'DejaVuSansMono',
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(height: 8),
                              const Text("Fastest Checkout.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontFamily: 'DejaVuSansMono',
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                              const SizedBox(height: 20),
                              Text("Login to start shopping",
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                      fontFamily: 'DejaVuSansMono')),
                            ],
                          ),
                        ),
                        // THE FLOATING LEFT MENU BUTTON
                        Positioned(
                          left: -45, // Hugging the left edge
                          top: 25,
                          child: InkWell(
                            onTap: () {
                              // Support / Contact action here later
                            },
                            child: Container(
                              height: 55,
                              width: 55,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5))
                                  ]),
                              child: const Center(
                                child: Icon(Icons.menu,
                                    color: Colors.black87, size: 28),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    // 📱 INPUT FIELDS
                    if (!isOtpSent) _buildPhoneInput(),
                    if (isOtpSent) _buildOtpInput(),
                    const SizedBox(height: 25),

                    // 🔘 ACTION BUTTON (WHITE BG, RED TEXT)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        onPressed: loading
                            ? null
                            : (isOtpSent ? _verifyOtp : _sendOtp),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: cherryRedDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                          shadowColor: Colors.black.withOpacity(0.3),
                        ),
                        child: loading
                            ? CircularProgressIndicator(color: cherryRedDark)
                            : Text(isOtpSent ? "VERIFY SECURELY" : "GET OTP",
                                style: const TextStyle(
                                    fontFamily: 'DejaVuSansMono',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2)),
                      ),
                    ),

                    // 🔄 RESEND LOGIC UI
                    if (isOtpSent) ...[
                      const SizedBox(height: 25),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Didn't receive code? ",
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8))),
                          GestureDetector(
                            onTap: _canResend ? _resendOtp : null,
                            child: Text(
                                _canResend ? "Resend Now" : "Wait ${_start}s",
                                style: TextStyle(
                                    color: _canResend
                                        ? Colors.white
                                        : Colors.white54,
                                    fontWeight: FontWeight.bold,
                                    decoration: _canResend
                                        ? TextDecoration.underline
                                        : TextDecoration.none)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            isOtpSent = false;
                            otpController.clear();
                            _timer?.cancel();
                          });
                        },
                        child: const Text("Change Mobile Number",
                            style: TextStyle(
                                color: Colors.white70,
                                decoration: TextDecoration.underline)),
                      )
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 📞 PHONE INPUT WIDGET
  Widget _buildPhoneInput() {
    return Container(
      height: 65,
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.4), width: 1)),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          const Text("+91",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'DejaVuSansMono')),
          const SizedBox(width: 15),
          Container(width: 1, height: 30, color: Colors.white.withOpacity(0.4)),
          const SizedBox(width: 15),
          Expanded(
            child: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontFamily: 'DejaVuSansMono',
                  letterSpacing: 2),
              decoration: InputDecoration(
                hintText: 'Phone Number',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.5),
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

  // 🔑 OTP INPUT WIDGET
  Widget _buildOtpInput() {
    return Container(
      height: 65,
      key: const ValueKey('otp'),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white, width: 2)),
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
        ),
        maxLength: 6,
        onChanged: (val) {
          if (val.length == 6) {
            FocusScope.of(context).unfocus();
            _verifyOtp();
          }
        },
      ),
    );
  }
}
