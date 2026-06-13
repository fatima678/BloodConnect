import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../../routes.dart';
import '../../sdk/auth/phone_otp_sdk.dart';
import '../../sdk/core/sdk_exception.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
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

  late String _verificationId;
  int? _resendToken;

  @override
  void initState() {
    super.initState();

    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
  }

  String _otpCode() {
    return _controllers.map((controller) => controller.text.trim()).join();
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
      await PhoneOtpSdk.verifyOtp(
        verificationId: _verificationId,
        otp: otp,
      );

      if (!mounted) return;

      _showMessage(
        message: 'Phone number verified successfully.',
        backgroundColor: Colors.green,
      );

      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      AppRoutes.replaceWithPatientHome(context);
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
            await PhoneOtpSdk.signInWithCredential(credential);

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