// lib/screens/Donor/Donor_Login_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../theme.dart';
import '../../../routes.dart';
import '../../../services/auth_token_service.dart';

class DonorLoginScreen extends StatefulWidget {
  final String role;

  const DonorLoginScreen({super.key, required this.role});

  @override
  State<DonorLoginScreen> createState() => _DonorLoginScreenState();
}

class _DonorLoginScreenState extends State<DonorLoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;

  Future<String?> _getFcmToken() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint("DONOR FCM Permission: ${settings.authorizationStatus}");

      await FirebaseMessaging.instance.setAutoInitEnabled(true);

      String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken == null || fcmToken.trim().isEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        fcmToken = await FirebaseMessaging.instance.getToken();
      }

      debugPrint("DONOR FCM Token: $fcmToken");

      if (fcmToken == null || fcmToken.trim().isEmpty) {
        return null;
      }

      return fcmToken;
    } catch (e) {
      debugPrint("DONOR FCM Token Error: $e");
      return null;
    }
  }

  Future<void> loginUser() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final String? fcmToken = await _getFcmToken();

      final Map<String, dynamic> loginBody = {
        'email': email,
        'password': password,
        'role': 'donor',
        'device_type': 'android',
      };

      if (fcmToken != null && fcmToken.isNotEmpty) {
        loginBody['fcm_token'] = fcmToken;
      }

      debugPrint("DONOR LOGIN HAS FCM TOKEN: ${fcmToken != null && fcmToken.isNotEmpty}");
      debugPrint("DONOR LOGIN ROLE: donor");

      final response = await http
          .post(
            Uri.parse('${AuthTokenService.baseUrl}/login'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode(loginBody),
          )
          .timeout(const Duration(seconds: 20));

      debugPrint("Donor Login Status: ${response.statusCode}");
      debugPrint("Donor Login Response: ${response.body}");

      Map<String, dynamic> data = {};

      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = {};
      }

      if (!mounted) return;

      if (response.statusCode != 200 || data['success'] != true) {
        setState(() => isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? "Invalid Email or Password"),
          ),
        );
        return;
      }

      final String? token = data['token']?.toString();
      final String? refreshToken = data['refresh_token']?.toString();

      final Map<String, dynamic>? userData =
          data['data'] is Map<String, dynamic>
              ? data['data'] as Map<String, dynamic>
              : null;

      if (token == null || refreshToken == null || userData == null) {
        setState(() => isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login data incomplete")),
        );
        return;
      }

      await AuthTokenService.saveSession(
        token: token,
        refreshToken: refreshToken,
        expiresIn: int.tryParse('${data['expires_in'] ?? 3600}') ?? 3600,
        user: userData,
      );

      final bool fcmTokenSaved = data['fcm_token_saved'] == true;

      debugPrint("DONOR LOGIN SUCCESS");
      debugPrint("DONOR FCM TOKEN SAVED: $fcmTokenSaved");

      if (!mounted) return;

      setState(() => isLoading = false);

      if (!fcmTokenSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Login successful, but notification token was not saved.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }

      final String role = (userData['role'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      if (role == "donor" || role == "patient_donor") {
        Navigator.pushReplacementNamed(context, AppRoutes.donorHome);
      } else if (role == "team_volunteer" || role == "volunteer") {
        Navigator.pushReplacementNamed(context, AppRoutes.volunteerDashboard);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid donor role")),
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("DONOR LOGIN SCREEN BUILD RUNNING");

    return Scaffold(
      backgroundColor: const Color(0xFF8B0000),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF6B0000), Color(0xFF8B0000)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.roleSelection,
                            );
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      "Donor",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(30),
                                ),
                              ),
                              child: const Text(
                                "Login",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF6B0000),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.donorRegister,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: const Text(
                                "Register",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Login Input Fields Card Panel
                  Container(
                    decoration: BoxDecoration(
                      color: whiteColor,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTextField(
                          hint: "Email Address",
                          icon: Icons.alternate_email,
                          controller: emailController,
                        ),

                        const SizedBox(height: 16),

                        _buildTextField(
                          hint: "Password",
                          icon: Icons.lock_outline,
                          controller: passwordController,
                          isPassword: true,
                        ),

                        const SizedBox(height: 8),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pushNamed(
                              context,
                              AppRoutes.donorForgetPassword,
                            ),
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(
                                color: primaryMaroon,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryMaroon,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: isLoading ? null : loginUser,
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: whiteColor,
                                  )
                                : const Text(
                                    "LOGIN",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: whiteColor,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.donorPhoneLogin,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.phone_android, color: whiteColor, size: 24),
                        SizedBox(width: 10),
                        Text(
                          "Login with Phone",
                          style: TextStyle(
                            fontSize: 16.5,
                            color: whiteColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primaryMaroon),
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 4,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: primaryMaroon,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}