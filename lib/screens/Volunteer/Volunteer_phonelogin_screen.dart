import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';

import '../../theme.dart';
import '../../routes.dart';
import '../../sdk/auth/phone_otp_sdk.dart';
import '../../sdk/core/sdk_exception.dart';
import 'Volunteer_otp_screen.dart';

class VolunteerPhoneLoginPage extends StatefulWidget {
  final String role;

  const VolunteerPhoneLoginPage({
    super.key,
    this.role = 'Volunteer',
  });

  @override
  State<VolunteerPhoneLoginPage> createState() =>
      _VolunteerPhoneLoginPageState();
}

class _VolunteerPhoneLoginPageState extends State<VolunteerPhoneLoginPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeInController;
  late AnimationController _jerkController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _jerkAnimation;

  final TextEditingController _phoneController = TextEditingController();

  String _selectedDialCode = '+92';
  bool _isSendingOtp = false;

  @override
  void initState() {
    super.initState();

    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeIn = CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeIn,
    );

    _fadeInController.forward();

    _jerkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _jerkAnimation = Tween<Offset>(
      begin: const Offset(-0.05, 0),
      end: const Offset(0.05, 0),
    ).animate(
      CurvedAnimation(
        parent: _jerkController,
        curve: Curves.easeInOutSine,
      ),
    );
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

  String _buildFullPhoneNumber() {
    final rawPhone = _phoneController.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '');

    if (rawPhone.startsWith('+')) {
      return rawPhone;
    }

    if (rawPhone.startsWith('0')) {
      return '$_selectedDialCode${rawPhone.substring(1)}';
    }

    return '$_selectedDialCode$rawPhone';
  }

  Future<void> _sendOtp() async {
    FocusScope.of(context).unfocus();

    if (_phoneController.text.trim().isEmpty) {
      _showMessage(message: 'Please enter phone number.');
      return;
    }

    final String phone = _buildFullPhoneNumber();
    final String normalizedPhone = PhoneOtpSdk.normalizePakistaniPhone(phone);

    setState(() {
      _isSendingOtp = true;
    });

    try {
      await PhoneOtpSdk.sendOtp(
        phone: normalizedPhone,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;

          setState(() {
            _isSendingOtp = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VolunteerOtpScreen(
                phoneNumber: normalizedPhone,
                verificationId: verificationId,
                resendToken: resendToken,
              ),
            ),
          );
        },
        onFailed: (message) {
          if (!mounted) return;

          setState(() {
            _isSendingOtp = false;
          });

          _showMessage(message: message);
        },
        onAutoVerified: (credential) async {
          try {
            await PhoneOtpSdk.signInWithCredential(credential);

            if (!mounted) return;

            setState(() {
              _isSendingOtp = false;
            });

            AppRoutes.replaceWithVolunteerDashboard(context);
          } catch (e) {
            if (!mounted) return;

            setState(() {
              _isSendingOtp = false;
            });

            _showMessage(message: 'Auto verification failed.');
          }
        },
      );
    } on SdkException catch (e) {
      if (!mounted) return;

      setState(() {
        _isSendingOtp = false;
      });

      _showMessage(message: e.message);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSendingOtp = false;
      });

      debugPrint('Volunteer send OTP error: $e');

      _showMessage(message: 'Failed to send OTP. Please try again.');
    }
  }

  @override
  void dispose() {
    _fadeInController.dispose();
    _jerkController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryMaroon,
        title: Text(
          "Login ${widget.role}",
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _isSendingOtp ? null : () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),

              SlideTransition(
                position: _jerkAnimation,
                child: Center(
                  child: Image.asset(
                    'lib/assets/Login-pana.png',
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                "Login with phone number",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 30),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CountryCodePicker(
                        onChanged: (country) {
                          _selectedDialCode = country.dialCode ?? '+92';
                        },
                        initialSelection: 'PK',
                        favorite: const ['PK', 'AE', 'SA'],
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        padding: EdgeInsets.zero,
                      ),

                      const Text(
                        "|",
                        style: TextStyle(color: Colors.grey, fontSize: 25),
                      ),

                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !_isSendingOtp,
                          decoration: const InputDecoration(
                            hintText: "300 1234567",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(left: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryMaroon,
                      disabledBackgroundColor: primaryMaroon.withOpacity(0.65),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isSendingOtp ? null : _sendOtp,
                    child: _isSendingOtp
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "SEND OTP",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}