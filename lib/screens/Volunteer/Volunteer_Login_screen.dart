// lib/screens/Volunteer/Volunteer_Login_Screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../theme.dart';
import '../../../routes.dart';
import '../../../services/auth_token_service.dart';

class VolunteerLoginScreen extends StatefulWidget {
  const VolunteerLoginScreen({super.key});

  @override
  State<VolunteerLoginScreen> createState() => _VolunteerLoginScreenState();
}

class _VolunteerLoginScreenState extends State<VolunteerLoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;

  Future<bool> _saveFcmTokenToBackend() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();

      debugPrint("FCM Permission: ${settings.authorizationStatus}");

      final String? fcmToken = await FirebaseMessaging.instance.getToken();

      debugPrint("FCM Token: $fcmToken");

      if (fcmToken == null || fcmToken.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("FCM token not found.")));
        }
        return false;
      }

      final response = await AuthTokenService.authorizedPost('/fcm-token', {
        'fcm_token': fcmToken,
        'device_type': 'android',
      });

      debugPrint("FCM Save Status: ${response.statusCode}");
      debugPrint("FCM Save Body: ${response.body}");

      Map<String, dynamic> responseBody = {};

      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = {};
      }

      if (response.statusCode == 200 && responseBody['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("FCM token saved successfully."),
              backgroundColor: Colors.green,
            ),
          );
        }
        return true;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseBody['message'] ?? "Failed to save FCM token.",
            ),
          ),
        );
      }

      return false;
    } catch (e) {
      debugPrint("FCM Save Error: $e");

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("FCM save error: $e")));
      }

      return false;
    }
  }

  Future<void> loginVolunteer() async {
    final String email = emailController.text.trim();
    final String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('${AuthTokenService.baseUrl}/login'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);

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

      final String? token = data['token'];
      final String? refreshToken = data['refresh_token'];
      final Map<String, dynamic>? userData = data['data'];

      if (token == null || refreshToken == null || userData == null) {
        setState(() => isLoading = false);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Login data incomplete")));
        return;
      }

      await AuthTokenService.saveSession(
        token: token,
        refreshToken: refreshToken,
        expiresIn: int.tryParse('${data['expires_in'] ?? 3600}') ?? 3600,
        user: userData,
      );

      debugPrint("LOGIN SUCCESS - NOW SAVING FCM TOKEN");

      final bool fcmSaved = await _saveFcmTokenToBackend();

      debugPrint("FCM FUNCTION COMPLETED: $fcmSaved");

      if (!mounted) return;

      setState(() => isLoading = false);

      if (!fcmSaved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Login successful, but FCM token was not saved."),
          ),
        );
      }

      final String role = (userData['role'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      if (role == "patient" || role == "donor" || role == "patient_donor") {
        Navigator.pushReplacementNamed(context, AppRoutes.patientHome);
      } else if (role == "team_volunteer" || role == "volunteer") {
        Navigator.pushReplacementNamed(context, AppRoutes.volunteerDashboard);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Invalid user role")));
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Connection Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("LOGIN SCREEN BUILD RUNNING");

    return Scaffold(
      body: Container(
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
                children: [
                  const SizedBox(height: 20),

                  // Back Button to Role Selection Screen
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
                      "Logging in as Volunteer",
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
                              AppRoutes.volunteerRegister,
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

                  Container(
                    decoration: BoxDecoration(
                      color: whiteColor,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 40),
                    child: Column(
                      children: [
                        const Text(
                          "SECURE LOGIN",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 32),

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
                              AppRoutes.volunteerSettings, // Assuming dynamic catch destination helper maps here
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
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: isLoading ? null : loginVolunteer,
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
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.helpSupport), // Preservation of navigation line
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

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "New user? ",
                        style: TextStyle(fontSize: 15.5, color: whiteColor70),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.volunteerRegister,
                        ),
                        child: const Text(
                          "Register",
                          style: TextStyle(
                            fontSize: 15.5,
                            color: whiteColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
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