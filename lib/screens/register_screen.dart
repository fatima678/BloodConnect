// ignore_for_file: camel_case_types, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../theme.dart';

class register extends StatefulWidget {
  const register({super.key});

  @override
  State<register> createState() => _registerState();
}

class _registerState extends State<register> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void showMessage({
    required String message,
    Color backgroundColor = Colors.red,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _now() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceFirst('Z', '+00:00');
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Please check your internet.';
      default:
        return e.message ?? 'Registration failed. Please try again.';
    }
  }

  Future<void> registerUser() async {
    FocusScope.of(context).unfocus();

    final String name = nameController.text.trim();
    final String email = emailController.text.trim().toLowerCase();
    final String phone = phoneController.text.trim();
    final String password = passwordController.text.trim();
    final String confirmPassword = confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage(message: "Please fill all fields");
      return;
    }

    if (password.length < 6) {
      showMessage(message: "Password should be at least 6 characters.");
      return;
    }

    if (password != confirmPassword) {
      showMessage(message: "Passwords do not match.");
      return;
    }

    setState(() => isLoading = true);

    User? createdUser;

    try {
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      createdUser = credential.user;

      if (createdUser == null) {
        throw Exception('Registration session not found.');
      }

      await createdUser.updateDisplayName(name);

      final String uid = createdUser.uid;
      final String now = _now();

      // Direct write to global 'users' collection with default structural flags
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'created_at': now,
        'updated_at': now,
        'status': 'active', // Default status for general user access
        'blood_group': '',   // Initial empty profile state (to be selected inside app)
        'points': 0,
      });

      await createdUser.sendEmailVerification();

      await _auth.signOut();

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration successful.',
          ),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      showMessage(message: _firebaseErrorMessage(e));
    } catch (e) {
      if (createdUser != null && !createdUser.emailVerified) {
        try {
          await createdUser.delete();
        } catch (_) {}
      }

      if (!mounted) return;

      setState(() => isLoading = false);

      debugPrint("Register error: $e");

      showMessage(message: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double screenWidth = MediaQuery.of(context).size.width;

    final double horizontalPadding = screenWidth <= 390 ? 24 : 38;
    final double cardPadding = screenWidth <= 390 ? 24 : 34;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            SizedBox(
              height: topPadding + 690, // Reduced height dynamically as role selection dropdown is removed
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: topPadding + 310,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: primaryMaroon,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(62),
                          bottomRight: Radius.circular(62),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: topPadding + 22,
                    left: 22,
                    child: GestureDetector(
                      onTap: isLoading
                          ? null
                          : () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              } else {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.login,
                                  (route) => false,
                                );
                              }
                            },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: whiteColor.withOpacity(0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: whiteColor,
                          size: 27,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: topPadding + 95,
                    left: 0,
                    right: 0,
                    child: const Text(
                      "Create Account",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: whiteColor,
                        fontSize: 33,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Positioned(
                    top: topPadding + 153,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: whiteColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(35),
                          border: Border.all(
                            color: whiteColor.withOpacity(0.28),
                            width: 1.1,
                          ),
                        ),
                        child: const Text(
                          "Blood Connect",
                          style: TextStyle(
                            color: whiteColor,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: topPadding + 230,
                    left: horizontalPadding,
                    right: horizontalPadding,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(
                        cardPadding,
                        32,
                        cardPadding,
                        30,
                      ),
                      decoration: BoxDecoration(
                        color: whiteColor,
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [
                          BoxShadow(
                            color: blackColor.withOpacity(0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTextField(
                            hint: "Full Name",
                            icon: Icons.person_outline_rounded,
                            controller: nameController,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hint: "Email Address",
                            icon: Icons.alternate_email_rounded,
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hint: "Phone Number",
                            icon: Icons.phone_iphone_rounded,
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hint: "Password",
                            icon: Icons.lock_outline_rounded,
                            controller: passwordController,
                            isPassword: true,
                            isConfirmPassword: false,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hint: "Confirm Password",
                            icon: Icons.lock_outline_rounded,
                            controller: confirmPasswordController,
                            isPassword: true,
                            isConfirmPassword: true,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!isLoading) {
                                registerUser();
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: primaryMaroon,
                                disabledBackgroundColor:
                                    primaryMaroon.withOpacity(0.65),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: isLoading ? null : registerUser,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: whiteColor,
                                        strokeWidth: 2.4,
                                      ),
                                    )
                                  : const Text(
                                      "REGISTER",
                                      style: TextStyle(
                                        color: whiteColor,
                                        fontSize: 17.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: isLoading
                  ? null
                  : () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.login,
                        (route) => false,
                      );
                    },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 16.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    "Login Now",
                    style: TextStyle(
                      color: primaryMaroon,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      decorationColor: primaryMaroon,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: bottomPadding + 30),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool isPassword = false,
    bool isConfirmPassword = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
  }) {
    final bool obscureText = isPassword
        ? isConfirmPassword
            ? _obscureConfirmPassword
            : _obscurePassword
        : false;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        enabled: !isLoading,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          color: blackColor,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: primaryMaroon.withOpacity(0.68),
            size: 26,
          ),
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.4,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 17,
            horizontal: 4,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: primaryMaroon.withOpacity(0.68),
                  ),
                  onPressed: isLoading
                      ? null
                      : () {
                          setState(() {
                            if (isConfirmPassword) {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            } else {
                              _obscurePassword = !_obscurePassword;
                            }
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
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}