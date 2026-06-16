// ignore_for_file: camel_case_types, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../theme.dart';
import '../../services/firestore_notification_listener_service.dart';

class login extends StatefulWidget {
  const login({super.key});

  @override
  State<login> createState() => _loginState();
}

class _loginState extends State<login> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  bool _obscurePassword = true;

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

  String _homeRouteFromRole(String role) {
    final String normalizedRole = _normalizeRole(role);

    switch (normalizedRole) {
      case 'patient':
        return AppRoutes.patientHome;
      case 'donor':
        return AppRoutes.donorHome;
      case 'team_volunteer':
        return AppRoutes.volunteerDashboard;
      default:
        throw Exception('Invalid user role.');
    }
  }

  String _deviceType() {
    if (kIsWeb) return 'web';

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'android';
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

  Future<String> _createProfileFromPendingRegistration(User user) async {
    final String uid = user.uid;
    final String now = _now();

    final pendingDoc =
        await _firestore.collection('pending_registrations').doc(uid).get();

    if (!pendingDoc.exists || pendingDoc.data() == null) {
      throw Exception(
        'User role not found. Please complete registration again.',
      );
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

    return role;
  }

  Future<String> _getOrCreateVerifiedUserRole(User user) async {
    final String? existingRole = await _readExistingRole(user.uid);

    if (existingRole != null && existingRole.trim().isNotEmpty) {
      return _normalizeRole(existingRole);
    }

    return _createProfileFromPendingRegistration(user);
  }

  Future<String?> _getFcmToken() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint("FCM Permission: ${settings.authorizationStatus}");

      final String? fcmToken = await FirebaseMessaging.instance.getToken();

      debugPrint("FCM Token: $fcmToken");

      if (fcmToken == null || fcmToken.trim().isEmpty) {
        return null;
      }

      return fcmToken.trim();
    } catch (e) {
      debugPrint("FCM Token Error: $e");
      return null;
    }
  }

  Future<void> _saveFcmToken({
    required String uid,
    required String role,
  }) async {
    final String? fcmToken = await _getFcmToken();

    if (fcmToken == null || fcmToken.isEmpty) {
      return;
    }

    final String normalizedRole = _normalizeRole(role);
    final String collectionName = _roleCollection(normalizedRole);
    final String now = _now();

    final Map<String, dynamic> tokenData = {
      'fcm_token': fcmToken,
      'device_type': _deviceType(),
      'fcm_token_updated_at': now,
      'updated_at': now,
    };

    await _firestore.collection(collectionName).doc(uid).set(
          tokenData,
          SetOptions(merge: true),
        );
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'network-request-failed':
        return 'Network error. Please check your internet.';
      default:
        return e.message ?? 'Login failed. Please try again.';
    }
  }

  Future<void> loginUser() async {
    FocusScope.of(context).unfocus();

    final String email = emailController.text.trim().toLowerCase();
    final String password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      showMessage(message: "Please fill all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? firebaseUser = credential.user ?? _auth.currentUser;

      if (firebaseUser == null) {
        throw Exception('Login session not found.');
      }

      await firebaseUser.reload();

      final User? refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        throw Exception('Login session not found.');
      }

      if (!refreshedUser.emailVerified) {
        try {
          await refreshedUser.sendEmailVerification();
        } catch (_) {}

        await _auth.signOut();

        if (!mounted) return;

        setState(() => isLoading = false);

        showMessage(
          message:
              "Please verify your email first. Verification email sent again.",
          backgroundColor: Colors.orange,
        );
        return;
      }

      await refreshedUser.getIdToken(true);

      final String role = await _getOrCreateVerifiedUserRole(refreshedUser);

      await _saveFcmToken(
        uid: refreshedUser.uid,
        role: role,
      );

      await FirestoreNotificationListenerService.startForCurrentUser();

      if (!mounted) return;

      setState(() => isLoading = false);

      Navigator.pushNamedAndRemoveUntil(
        context,
        _homeRouteFromRole(role),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      showMessage(message: _firebaseErrorMessage(e));
    } catch (e) {
      if (!mounted) return;

      setState(() => isLoading = false);

      debugPrint("Login error: $e");

      showMessage(message: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> forgotPassword() async {
    final String email = emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      showMessage(
        message: "Please enter email address first.",
        backgroundColor: Colors.orange,
      );
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);

      showMessage(
        message: "Password reset email sent.",
        backgroundColor: primaryMaroon,
      );
    } on FirebaseAuthException catch (e) {
      showMessage(message: _firebaseErrorMessage(e));
    } catch (_) {
      showMessage(message: "Unable to send password reset email.");
    }
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
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          children: [
            SizedBox(
              height: topPadding + 570,
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
                      "Welcome Back",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: whiteColor,
                        fontSize: 36,
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
                        38,
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTextField(
                            hint: "Email Address",
                            icon: Icons.alternate_email_rounded,
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: 20),
                          _buildTextField(
                            hint: "Password",
                            icon: Icons.lock_outline_rounded,
                            controller: passwordController,
                            isPassword: true,
                            keyboardType: TextInputType.visiblePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              if (!isLoading) {
                                loginUser();
                              }
                            },
                          ),
                          const SizedBox(height: 26),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: isLoading ? null : forgotPassword,
                              child: const Text(
                                "Forgot Password?",
                                style: TextStyle(
                                  color: Color(0xFF9E9E9E),
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
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
                              onPressed: isLoading ? null : loginUser,
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
                                      "LOGIN",
                                      style: TextStyle(
                                        color: whiteColor,
                                        fontSize: 18,
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
            const SizedBox(height: 54),
            GestureDetector(
              onTap: isLoading
                  ? null
                  : () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.patientPhoneLogin,
                      );
                    },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.phone_iphone_rounded,
                    color: primaryMaroon,
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Text(
                    "Login with Phone",
                    style: TextStyle(
                      color: primaryMaroon,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),
            GestureDetector(
              onTap: isLoading
                  ? null
                  : () {
                      Navigator.pushNamed(context, AppRoutes.register);
                    },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "New user? ",
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 16.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    "Register Now",
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
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
  }) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F1F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        enabled: !isLoading,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          color: blackColor,
          fontSize: 16.5,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: primaryMaroon.withOpacity(0.68),
            size: 27,
          ),
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF9E9E9E),
            fontSize: 16.5,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.4,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 19,
            horizontal: 4,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: primaryMaroon.withOpacity(0.68),
                  ),
                  onPressed: isLoading
                      ? null
                      : () {
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