// lib/screens/Volunteer/Volunteer_Register.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../theme.dart';
import '../../../routes.dart';
import '../Volunteer/Volunteer_Login_Screen.dart';

class VolunteerRegisterScreen extends StatefulWidget {
  const VolunteerRegisterScreen({super.key});

  @override
  State<VolunteerRegisterScreen> createState() => _VolunteerRegisterScreenState();
}

class _VolunteerRegisterScreenState extends State<VolunteerRegisterScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  final String registerUrl = "https://manliness-smugness-qualm.ngrok-free.dev/api/register";

  Future<void> registerVolunteer() async {
    final String name = nameController.text.trim();
    final String email = emailController.text.trim();
    final String phone = phoneController.text.trim();
    final String password = passwordController.text.trim();

    if (name.isEmpty || email.isEmpty || phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      final response = await http.post(
        Uri.parse(registerUrl),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'role': 'team_volunteer',
        }),
      );

      final data = jsonDecode(response.body);
      setState(() => isLoading = false);

      if (response.statusCode == 201 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registration Successful"), backgroundColor: Colors.green),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VolunteerLoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? "Registration Failed"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  const SizedBox(height: 60),

                  const Text(
                    "Welcome Back",
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      "Create New Account",
                      style: TextStyle(color: Colors.white, fontSize: 16.5),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Toggle Buttons
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.volunteerLogin),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: const Text("Login", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
                              ),
                              child: Text("Register", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryMaroon)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  Container(
                    decoration: BoxDecoration(color: whiteColor, borderRadius: BorderRadius.circular(32)),
                    padding: const EdgeInsets.fromLTRB(24, 36, 24, 40),
                    child: Column(
                      children: [
                        buildField(hint: "Full Name", icon: Icons.person, controller: nameController),
                        const SizedBox(height: 20),
                        buildField(hint: "Email", icon: Icons.email, controller: emailController),
                        const SizedBox(height: 20),
                        buildField(hint: "Phone", icon: Icons.phone, controller: phoneController),
                        const SizedBox(height: 20),
                        buildField(hint: "Password", icon: Icons.lock, controller: passwordController, isPass: true),

                        const SizedBox(height: 25),

                        // Volunteer Info
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primaryMaroon.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          // child: const Text(
                          //   "Registering as: Volunteer Team",
                          //   style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryMaroon),
                          //   textAlign: TextAlign.center,
                          // ),
                        ),

                        const SizedBox(height: 35),

                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                            onPressed: isLoading ? null : registerVolunteer,
                            child: isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("REGISTER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.volunteerLogin),
                    child: const Text("Already have an account? Login", style: TextStyle(color: whiteColor, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildField({required String hint, required IconData icon, required TextEditingController controller, bool isPass = false}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF1F3F6), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: primaryMaroon),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}