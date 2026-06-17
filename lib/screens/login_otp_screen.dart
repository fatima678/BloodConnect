import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../routes.dart';
import '../../sdk/auth/phone_otp_sdk.dart';
import '../../sdk/core/sdk_exception.dart';
import '../../services/firestore_notification_listener_service.dart';

class LoginOtpScreen extends StatefulWidget {
  final String? uid;
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;

  const LoginOtpScreen({
    super.key,
    this.uid,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  @override
  State<LoginOtpScreen> createState() => _LoginOtpScreenState();
}

class _LoginOtpScreenState extends State<LoginOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  bool _isLoading = false;
  bool _isResending = false;
  bool _isCompletingLogin = false;

  late String _verificationId;
  int? _resendToken;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
  }

  String _otpCode() {
    return _controllers.map((controller) => controller.text.trim()).join();
  }

  String _now() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceFirst('Z', '+00:00');
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

  void _showMessage({
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

  String _firebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return 'Invalid OTP code.';
      case 'session-expired':
        return 'OTP session expired. Please try again.';
      case 'credential-already-in-use':
        return 'This phone number is already linked with another account.';
      case 'network-request-failed':
        return 'Network error. Please check your internet.';
      default:
        return e.message ?? 'OTP verification failed. Please try again.';
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

  Future<void> _verifyOtp() async {
    final otp = _otpCode();

    if (otp.length != 6) {
      _showMessage(message: 'Please enter complete 6 digit OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );

      if (widget.uid != null && widget.uid!.trim().isNotEmpty) {
        await _completePhoneLogin(credential);
      } else {
        await PhoneOtpSdk.verifyOtp(
          verificationId: _verificationId,
          otp: otp,
        );
      }

      if (!mounted) return;

      _showMessage(
        message: 'Phone number verified successfully.',
        backgroundColor: Colors.green,
      );

      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      AppRoutes.replaceWithPatientHome(context);
    } on FirebaseAuthException catch (e) {
      _showMessage(message: _firebaseErrorMessage(e));
    } on SdkException catch (e) {
      _showMessage(message: e.message);
    } catch (e) {
      _showMessage(message: 'OTP verification failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completePhoneLogin(PhoneAuthCredential credential) async {
    if (_isCompletingLogin) return;

    _isCompletingLogin = true;

    try {
      final User? currentUser = _auth.currentUser;

      if (currentUser == null) {
        throw Exception('Login session not found.');
      }

      if (currentUser.uid != widget.uid) {
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

      await _firestore.collection('users').doc(widget.uid).set(
        {
          'is_phone_verified': true,
          'phone_verified_at': now,
          'updated_at': now,
        },
        SetOptions(merge: true),
      );

      await refreshedUser.getIdToken(true);

      await _saveFcmToken(uid: widget.uid!);

      await FirestoreNotificationListenerService.startForCurrentUser();
    } catch (_) {
      _isCompletingLogin = false;
      rethrow;
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      await PhoneOtpSdk.sendOtp(
        phone: widget.phoneNumber,
        forceResendingToken: _resendToken,
        onCodeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;

          _showMessage(
            message: 'OTP resent successfully.',
            backgroundColor: Colors.green,
          );
        },
        onFailed: (message) {
          _showMessage(message: message);
        },
        onAutoVerified: (credential) async {
          try {
            if (widget.uid != null && widget.uid!.trim().isNotEmpty) {
              await _completePhoneLogin(credential);
            } else {
              await PhoneOtpSdk.signInWithCredential(credential);
            }

            if (!mounted) return;

            AppRoutes.replaceWithPatientHome(context);
          } catch (e) {
            _showMessage(message: 'Auto verification failed.');
          }
        },
      );
    } on SdkException catch (e) {
      _showMessage(message: e.message);
    } catch (e) {
      _showMessage(message: 'Failed to resend OTP.');
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }

    for (var node in _focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isButtonDisabled = _isLoading || _isResending;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryMaroon),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Image.asset(
                'lib/assets/otp.jpg',
                height: 180,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 40),
              const Text(
                "Verify OTP",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter your received OTP here",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 6),
              Text(
                widget.phoneNumber,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: primaryMaroon,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) => _buildOtpField(index)),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't get the OTP? ",
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                  GestureDetector(
                    onTap: isButtonDisabled ? null : _resendOtp,
                    child: Text(
                      _isResending ? "SENDING..." : "RESEND OTP",
                      style: TextStyle(
                        color: isButtonDisabled ? Colors.grey : primaryMaroon,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  onPressed: isButtonDisabled ? null : _verifyOtp,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "VERIFY",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    return SizedBox(
      width: 48,
      height: 58,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        enabled: !_isLoading && !_isResending,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryMaroon, width: 2),
          ),
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }

          if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }

          if (index == 5 && _otpCode().length == 6) {
            FocusScope.of(context).unfocus();
          }
        },
      ),
    );
  }
}