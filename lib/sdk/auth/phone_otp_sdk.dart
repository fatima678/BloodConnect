import 'package:firebase_auth/firebase_auth.dart';

import '../core/sdk_exception.dart';

class PhoneOtpSdk {
  PhoneOtpSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String normalizePakistaniPhone(String phone) {
    final value = phone.trim().replaceAll(' ', '').replaceAll('-', '');

    if (value.startsWith('+92')) {
      return value;
    }

    if (value.startsWith('03') && value.length == 11) {
      return '+92${value.substring(1)}';
    }

    if (value.startsWith('3') && value.length == 10) {
      return '+92$value';
    }

    if (value.startsWith('0') && value.length == 11) {
      return '+92${value.substring(1)}';
    }

    return value;
  }

  static Future<void> sendOtp({
    required String phone,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String message) onFailed,
    void Function(PhoneAuthCredential credential)? onAutoVerified,
    int? forceResendingToken,
  }) async {
    final cleanPhone = normalizePakistaniPhone(phone);

    if (!cleanPhone.startsWith('+92') || cleanPhone.length != 13) {
      throw const SdkException(
        'Please enter a valid Pakistani phone number. Example: 03001234567',
      );
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: cleanPhone,
        forceResendingToken: forceResendingToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) {
          if (onAutoVerified != null) {
            onAutoVerified(credential);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (e.code == 'invalid-phone-number') {
            onFailed('Invalid phone number.');
            return;
          }

          if (e.code == 'too-many-requests') {
            onFailed('Too many OTP requests. Please try again later.');
            return;
          }

          if (e.code == 'quota-exceeded') {
            onFailed('Firebase SMS quota exceeded. Please try again later.');
            return;
          }

          if (e.code == 'operation-not-allowed') {
            onFailed(
              'Phone authentication is not enabled or SMS region is blocked.',
            );
            return;
          }

          if (e.code == 'app-not-authorized') {
            onFailed(
              'This app is not authorized. Check package name, SHA-1/SHA-256 and google-services.json.',
            );
            return;
          }

          onFailed(e.message ?? 'OTP verification failed. Code: ${e.code}');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to send OTP: $e');
    }
  }

  static Future<UserCredential> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    final cleanOtp = otp.trim();

    if (cleanOtp.length != 6) {
      throw const SdkException('Please enter valid 6 digit OTP.');
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: cleanOtp,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-verification-code') {
        throw const SdkException('Invalid OTP code.');
      }

      if (e.code == 'session-expired') {
        throw const SdkException('OTP expired. Please resend OTP.');
      }

      throw SdkException(e.message ?? 'OTP verification failed.');
    } catch (e) {
      throw SdkException('OTP verification failed: $e');
    }
  }

  static Future<UserCredential> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    try {
      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw SdkException(e.message ?? 'OTP verification failed.');
    } catch (e) {
      throw SdkException('OTP verification failed: $e');
    }
  }
}