// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  bool isResending = false;

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

  String _normalizeRole(String role) {
    final String value = role.trim().toLowerCase();

    if (value == 'patient') return 'patient';
    if (value == 'donor') return 'donor';
    if (value == 'volunteer' || value == 'team_volunteer') {
      return 'team_volunteer';
    }

    throw Exception('Invalid user role.');
  }

  String _roleCollection(String role) {
    final String normalizedRole = _normalizeRole(role);

    switch (normalizedRole) {
      case 'patient':
        return 'patients';
      case 'donor':
        return 'donors';
      case 'team_volunteer':
        return 'team_volunteers';
      default:
        throw Exception('Invalid user role.');
    }
  }

  Future<String?> _readExistingRole(String uid) async {
    final Map<String, String> roleCollections = {
      'patient': 'patients',
      'donor': 'donors',
      'team_volunteer': 'team_volunteers',
    };

    for (final entry in roleCollections.entries) {
      final roleDoc = await _firestore.collection(entry.value).doc(uid).get();

      if (roleDoc.exists) {
        final data = roleDoc.data();
        final dynamic roleValue = data?['role'];

        if (roleValue != null && roleValue.toString().trim().isNotEmpty) {
          return _normalizeRole(roleValue.toString());
        }

        return entry.key;
      }
    }

    return null;
  }

  Future<void> _createVerifiedUserProfile(User user) async {
    final String uid = user.uid;
    final String now = _now();

    final pendingDoc =
        await _firestore.collection('pending_registrations').doc(uid).get();

    if (!pendingDoc.exists || pendingDoc.data() == null) {
      final String? existingRole = await _readExistingRole(uid);

      if (existingRole == null) {
        throw Exception(
          'Registration data not found. Please register again.',
        );
      }

      final String collectionName = _roleCollection(existingRole);

      await _firestore.collection(collectionName).doc(uid).set(
        {
          'is_email_verified': true,
          'email_verified_at': now,
          'updated_at': now,
        },
        SetOptions(merge: true),
      );

      return;
    }

    final Map<String, dynamic> data = pendingDoc.data()!;

    final String role = _normalizeRole(data['role'].toString());
    final String collectionName = _roleCollection(role);

    final Map<String, dynamic> userData = {
      'uid': uid,
      'name': data['name']?.toString() ?? user.displayName ?? '',
      'email': data['email']?.toString() ?? user.email ?? '',
      'phone': data['phone']?.toString() ?? '',
      'role': role,
      'role_display': data['role_display']?.toString() ?? '',
      'status': 'active',
      'is_email_verified': true,
      'email_verified_at': now,
      'created_at': data['created_at']?.toString() ?? now,
      'updated_at': now,
    };

    await _firestore.collection(collectionName).doc(uid).set(
          userData,
          SetOptions(merge: true),
        );
  }

  Future<void> resendVerificationEmail() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      showMessage(message: 'Session not found. Please register again.');
      return;
    }

    setState(() => isResending = true);

    try {
      await user.sendEmailVerification();

      if (!mounted) return;

      setState(() => isResending = false);

      showMessage(
        message: 'Verification email sent again.',
        backgroundColor: primaryMaroon,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() => isResending = false);

      showMessage(message: 'Unable to send verification email.');
    }
  }

  Future<void> checkVerificationStatus() async {
    final User? user = _auth.currentUser;

    if (user == null) {
      showMessage(message: 'Session not found. Please register again.');
      return;
    }

    setState(() => isLoading = true);

    try {
      await user.reload();

      final User? refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        throw Exception('Session not found. Please register again.');
      }

      if (!refreshedUser.emailVerified) {
        if (!mounted) return;

        setState(() => isLoading = false);

        showMessage(
          message: 'Email is not verified yet. Please check your inbox.',
          backgroundColor: Colors.orange,
        );
        return;
      }

      await refreshedUser.getIdToken(true);

      await _createVerifiedUserProfile(refreshedUser);

      await _auth.signOut();

      if (!mounted) return;

      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email verified successfully. Please login now.'),
          backgroundColor: primaryMaroon,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      showMessage(message: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> backToLogin() async {
    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double screenWidth = MediaQuery.of(context).size.width;

    final double horizontalPadding = screenWidth <= 390 ? 24 : 38;
    final double cardPadding = screenWidth <= 390 ? 26 : 36;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      body: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: topPadding + 585,
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
                      onTap: isLoading || isResending ? null : backToLogin,
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
                      "Verify Email",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: whiteColor,
                        fontSize: 34,
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
                        36,
                        cardPadding,
                        34,
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
                        children: [
                          Container(
                            width: 78,
                            height: 78,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F1F5),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.mark_email_unread_outlined,
                              color: primaryMaroon,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 26),
                          const Text(
                            "A verification link has been sent to your email. Verify your email first, then tap the button below.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF8E8E8E),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            height: 58,
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
                              onPressed: isLoading || isResending
                                  ? null
                                  : checkVerificationStatus,
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
                                      "I HAVE VERIFIED",
                                      style: TextStyle(
                                        color: whiteColor,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: isLoading || isResending
                                ? null
                                : resendVerificationEmail,
                            child: Text(
                              isResending
                                  ? "Sending..."
                                  : "Resend Verification Email",
                              style: const TextStyle(
                                color: primaryMaroon,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                                decorationColor: primaryMaroon,
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
            const SizedBox(height: 34),
            GestureDetector(
              onTap: isLoading || isResending ? null : backToLogin,
              child: const Text(
                "Back to Login",
                style: TextStyle(
                  color: primaryMaroon,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: primaryMaroon,
                ),
              ),
            ),
            SizedBox(height: bottomPadding + 30),
          ],
        ),
      ),
    );
  }
}