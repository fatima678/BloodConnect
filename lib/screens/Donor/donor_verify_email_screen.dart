// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter/material.dart';

// import '../../routes.dart';
// import '../../sdk/auth/auth_sdk.dart';
// import '../../sdk/core/sdk_exception.dart';
// import '../../theme.dart';

// class DonorVerifyEmailScreen extends StatefulWidget {
//   const DonorVerifyEmailScreen({super.key});

//   @override
//   State<DonorVerifyEmailScreen> createState() => _DonorVerifyEmailScreenState();
// }

// class _DonorVerifyEmailScreenState extends State<DonorVerifyEmailScreen> {
//   bool _isChecking = false;
//   bool _isResending = false;

//   void _showMessage({
//     required String message,
//     Color backgroundColor = Colors.red,
//   }) {
//     if (!mounted) return;

//     ScaffoldMessenger.of(context).clearSnackBars();
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: backgroundColor,
//         behavior: SnackBarBehavior.floating,
//       ),
//     );
//   }

//   Future<String?> _getFcmToken() async {
//     try {
//       final settings = await FirebaseMessaging.instance.requestPermission(
//         alert: true,
//         badge: true,
//         sound: true,
//       );

//       debugPrint("DONOR VERIFY FCM Permission: ${settings.authorizationStatus}");

//       await FirebaseMessaging.instance.setAutoInitEnabled(true);

//       String? fcmToken = await FirebaseMessaging.instance.getToken();

//       if (fcmToken == null || fcmToken.trim().isEmpty) {
//         await Future.delayed(const Duration(seconds: 2));
//         fcmToken = await FirebaseMessaging.instance.getToken();
//       }

//       debugPrint("DONOR VERIFY FCM Token: $fcmToken");

//       if (fcmToken == null || fcmToken.trim().isEmpty) {
//         return null;
//       }

//       return fcmToken.trim();
//     } catch (e) {
//       debugPrint("DONOR VERIFY FCM Token Error: $e");
//       return null;
//     }
//   }

//   Future<void> _resendVerificationEmail() async {
//     final user = FirebaseAuth.instance.currentUser;

//     if (user == null) {
//       _showMessage(message: 'Session not found. Please login again.');
//       Navigator.pushReplacementNamed(context, AppRoutes.donorLogin);
//       return;
//     }

//     setState(() => _isResending = true);

//     try {
//       await user.sendEmailVerification();

//       if (!mounted) return;

//       _showMessage(
//         message: 'Verification email sent again. Please check your inbox.',
//         backgroundColor: Colors.green,
//       );
//     } on FirebaseAuthException catch (e) {
//       _showMessage(message: e.message ?? 'Failed to resend email.');
//     } catch (_) {
//       _showMessage(message: 'Failed to resend verification email.');
//     } finally {
//       if (mounted) {
//         setState(() => _isResending = false);
//       }
//     }
//   }

//   Future<void> _checkVerification() async {
//     final firebaseUser = FirebaseAuth.instance.currentUser;

//     if (firebaseUser == null) {
//       _showMessage(message: 'Session not found. Please login again.');
//       Navigator.pushReplacementNamed(context, AppRoutes.donorLogin);
//       return;
//     }

//     setState(() => _isChecking = true);

//     try {
//       await firebaseUser.reload();

//       final refreshedUser = FirebaseAuth.instance.currentUser;

//       if (refreshedUser == null) {
//         throw const SdkException('Session not found. Please login again.');
//       }

//       if (!refreshedUser.emailVerified) {
//         _showMessage(
//           message: 'Email is not verified yet. Please open the email link first.',
//           backgroundColor: Colors.orange,
//         );
//         return;
//       }

//       final appUser = await AuthSdk.currentAppUser(expectedRole: 'donor');

//       if (appUser == null) {
//         throw const SdkException('Donor profile not found. Please login again.');
//       }

//       final fcmToken = await _getFcmToken();

//       if (fcmToken != null && fcmToken.isNotEmpty) {
//         await AuthSdk.saveFcmTokenForUser(
//           user: appUser,
//           fcmToken: fcmToken,
//           deviceType: 'android',
//         );
//       }

//       if (!mounted) return;

//       _showMessage(
//         message: 'Email verified successfully.',
//         backgroundColor: Colors.green,
//       );

//       await Future.delayed(const Duration(milliseconds: 500));

//       if (!mounted) return;

//       Navigator.pushReplacementNamed(context, AppRoutes.donorHome);
//     } on SdkException catch (e) {
//       _showMessage(message: e.message);
//     } catch (_) {
//       _showMessage(message: 'Failed to check verification. Please try again.');
//     } finally {
//       if (mounted) {
//         setState(() => _isChecking = false);
//       }
//     }
//   }

//   Future<void> _logout() async {
//     await AuthSdk.logout();

//     if (!mounted) return;

//     Navigator.pushReplacementNamed(context, AppRoutes.donorLogin);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final userEmail = FirebaseAuth.instance.currentUser?.email ?? 'your email';

//     return Scaffold(
//       backgroundColor: const Color(0xFF8B0000),
//       body: Container(
//         width: double.infinity,
//         height: double.infinity,
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [Color(0xFF6B0000), Color(0xFF8B0000)],
//           ),
//         ),
//         child: SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 24),
//             child: Center(
//               child: Container(
//                 padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
//                 decoration: BoxDecoration(
//                   color: whiteColor,
//                   borderRadius: BorderRadius.circular(32),
//                 ),
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(
//                       Icons.mark_email_unread_rounded,
//                       color: primaryMaroon,
//                       size: 74,
//                     ),
//                     const SizedBox(height: 18),
//                     const Text(
//                       'Verify Your Email',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         color: primaryMaroon,
//                         fontSize: 24,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 12),
//                     Text(
//                       'We sent a verification link to:',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         color: Colors.grey.shade700,
//                         fontSize: 15,
//                       ),
//                     ),
//                     const SizedBox(height: 6),
//                     Text(
//                       userEmail,
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                         color: Colors.black87,
//                         fontSize: 16,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                     const SizedBox(height: 18),
//                     Text(
//                       'Open your email, click the verification link, then come back and press the button below.',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         color: Colors.grey.shade700,
//                         fontSize: 14.5,
//                         height: 1.45,
//                       ),
//                     ),
//                     const SizedBox(height: 28),
//                     SizedBox(
//                       width: double.infinity,
//                       height: 55,
//                       child: ElevatedButton(
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: primaryMaroon,
//                           disabledBackgroundColor:
//                               primaryMaroon.withOpacity(0.65),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(15),
//                           ),
//                         ),
//                         onPressed: _isChecking || _isResending
//                             ? null
//                             : _checkVerification,
//                         child: _isChecking
//                             ? const SizedBox(
//                                 width: 24,
//                                 height: 24,
//                                 child: CircularProgressIndicator(
//                                   color: Colors.white,
//                                   strokeWidth: 2.5,
//                                 ),
//                               )
//                             : const Text(
//                                 'I HAVE VERIFIED',
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 16,
//                                 ),
//                               ),
//                       ),
//                     ),
//                     const SizedBox(height: 14),
//                     TextButton(
//                       onPressed: _isChecking || _isResending
//                           ? null
//                           : _resendVerificationEmail,
//                       child: Text(
//                         _isResending
//                             ? 'Sending...'
//                             : 'Resend Verification Email',
//                         style: const TextStyle(
//                           color: primaryMaroon,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ),
//                     TextButton(
//                       onPressed: _isChecking || _isResending ? null : _logout,
//                       child: const Text(
//                         'Back to Login',
//                         style: TextStyle(
//                           color: Colors.black54,
//                           fontWeight: FontWeight.w600,
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }