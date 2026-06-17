// ignore_for_file: camel_case_types, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../routes.dart';
import '../../theme.dart';
import '../../services/firestore_notification_listener_service.dart';
import '../../sdk/auth/phone_otp_sdk.dart';
import '../../sdk/core/sdk_exception.dart';

class login extends StatefulWidget {
  const login({super.key});

  @override
  State<login> createState() => _loginState();
}

class _loginState extends State<login> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  bool _obscurePassword = true;
  bool _isCompletingPhoneLogin = false;

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

  String _phoneForOtp(String phone) {
    final String rawPhone = phone.trim().replaceAll(' ', '').replaceAll('-', '');

    if (rawPhone.startsWith('+')) {
      return rawPhone;
    }

    if (rawPhone.startsWith('0')) {
      return '+92${rawPhone.substring(1)}';
    }

    return '+92$rawPhone';
  }

  bool _isPhoneAlreadyVerified({
    required User user,
    required String phone,
  }) {
    final String phoneForOtp = _phoneForOtp(phone);

    return user.phoneNumber != null &&
        user.phoneNumber!.trim().isNotEmpty &&
        user.phoneNumber == phoneForOtp;
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
  }) async {
    final String? fcmToken = await _getFcmToken();

    if (fcmToken == null || fcmToken.isEmpty) {
      return;
    }

    final String now = _now();

    final Map<String, dynamic> tokenData = {
      'fcm_token': fcmToken,
      'device_type': _deviceType(),
      'fcm_token_updated_at': now,
      'updated_at': now,
    };

    await _firestore.collection('users').doc(uid).set(
          tokenData,
          SetOptions(merge: true),
        );
  }

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'Please enter a valid phone number.';
      case 'invalid-verification-code':
        return 'Invalid OTP code.';
      case 'session-expired':
        return 'OTP session expired. Please try again.';
      case 'quota-exceeded':
        return 'OTP limit exceeded. Please try again later.';
      case 'user-not-found':
        return 'No account found with this phone number.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid phone number or password.';
      case 'network-request-failed':
        return 'Network error. Please check your internet.';
      default:
        return e.message ?? 'Login failed. Please try again.';
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getUserByPhone(
    String phone,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('users')
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('No account found with this phone number.');
    }

    return snapshot.docs.first;
  }

  Future<void> _completePhoneLogin({
    required String uid,
    required PhoneAuthCredential credential,
  }) async {
    if (_isCompletingPhoneLogin) return;

    _isCompletingPhoneLogin = true;

    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        throw Exception('Login session not found.');
      }

      if (currentUser.uid != uid) {
        throw Exception('Invalid login session.');
      }

      await currentUser.reload();

      final User? refreshedUser = _auth.currentUser;

      if (refreshedUser == null) {
        throw Exception('Login session not found.');
      }

      try {
        if (refreshedUser.phoneNumber == null ||
            refreshedUser.phoneNumber!.trim().isEmpty) {
          await refreshedUser.linkWithCredential(credential);
        } else {
          await refreshedUser.reauthenticateWithCredential(credential);
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'provider-already-linked') {
          await refreshedUser.reauthenticateWithCredential(credential);
        } else if (e.code == 'credential-already-in-use') {
          throw Exception(
            'This phone number is already linked with another account.',
          );
        } else {
          rethrow;
        }
      }

      final String now = _now();

      await _firestore.collection('users').doc(uid).set(
        {
          'is_phone_verified': true,
          'phone_verified_at': now,
          'updated_at': now,
        },
        SetOptions(merge: true),
      );

      await refreshedUser.getIdToken(true);

      await _saveFcmToken(uid: uid);

      await FirestoreNotificationListenerService.startForCurrentUser();

      if (!mounted) return;

      setState(() => isLoading = false);

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
    } catch (_) {
      _isCompletingPhoneLogin = false;
      rethrow;
    }
  }

  Future<void> _sendOtp({
    required String uid,
    required String phone,
  }) async {
    final String phoneForOtp = _phoneForOtp(phone);

    try {
      await PhoneOtpSdk.sendOtp(
        phone: phoneForOtp,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted || _isCompletingPhoneLogin) return;

          setState(() => isLoading = false);

          Navigator.pushNamed(
            context,
            AppRoutes.loginOtp,
            arguments: {
              'uid': uid,
              'phoneNumber': phoneForOtp,
              'verificationId': verificationId,
              'resendToken': resendToken,
            },
          );
        },
        onFailed: (message) async {
          await _auth.signOut();

          if (!mounted) return;

          setState(() => isLoading = false);

          showMessage(message: message);
        },
        onAutoVerified: (credential) async {
          try {
            await _completePhoneLogin(
              uid: uid,
              credential: credential,
            );
          } on FirebaseAuthException catch (e) {
            await _auth.signOut();

            if (!mounted) return;

            setState(() => isLoading = false);

            showMessage(message: _firebaseErrorMessage(e));
          } catch (e) {
            await _auth.signOut();

            if (!mounted) return;

            setState(() => isLoading = false);

            showMessage(message: e.toString().replaceFirst('Exception: ', ''));
          }
        },
      );
    } on SdkException catch (e) {
      await _auth.signOut();

      if (!mounted) return;

      setState(() => isLoading = false);

      showMessage(message: e.message);
    } catch (e) {
      await _auth.signOut();

      if (!mounted) return;

      setState(() => isLoading = false);

      debugPrint('Send OTP error: $e');

      showMessage(message: 'Failed to send OTP. Please try again.');
    }
  }

  Future<void> _goToHomeAfterVerifiedLogin({
    required String uid,
  }) async {
    final String now = _now();

    await _firestore.collection('users').doc(uid).set(
      {
        'is_phone_verified': true,
        'updated_at': now,
      },
      SetOptions(merge: true),
    );

    await _auth.currentUser?.getIdToken(true);

    await _saveFcmToken(uid: uid);

    await FirestoreNotificationListenerService.startForCurrentUser();

    if (!mounted) return;

    setState(() => isLoading = false);

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  Future<void> loginUser() async {
    FocusScope.of(context).unfocus();

    final String phone = phoneController.text.trim();
    final String password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      showMessage(message: "Please fill all fields");
      return;
    }

    if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
      showMessage(message: "Phone number must be exactly 11 digits.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await _getUserByPhone(phone);

      final Map<String, dynamic>? data = userDoc.data();

      if (data == null) {
        throw Exception('User data not found.');
      }

      final String email = data['email']?.toString().trim().toLowerCase() ?? '';

      if (email.isEmpty) {
        throw Exception('User email not found.');
      }

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

      if (refreshedUser.uid != userDoc.id) {
        await _auth.signOut();
        throw Exception('Invalid phone number or password.');
      }

      if (_isPhoneAlreadyVerified(user: refreshedUser, phone: phone)) {
        await _goToHomeAfterVerifiedLogin(uid: refreshedUser.uid);
        return;
      }

      await _sendOtp(
        uid: refreshedUser.uid,
        phone: phone,
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
                            hint: "Phone Number",
                            icon: Icons.phone_iphone_rounded,
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            maxLength: 11,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
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
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
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
        maxLength: maxLength,
        inputFormatters: inputFormatters,
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
          counterText: "",
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
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}