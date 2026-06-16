// // lib/screens/Donor/Donor_Login_screen.dart

// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

// import '../../theme.dart';
// import '../../routes.dart';
// import '../../sdk/auth/auth_sdk.dart';
// import '../../sdk/core/sdk_exception.dart';

// class DonorLoginScreen extends StatefulWidget {
//   final String role;

//   const DonorLoginScreen({
//     super.key,
//     required this.role,
//   });

//   @override
//   State<DonorLoginScreen> createState() => _DonorLoginScreenState();
// }

// class _DonorLoginScreenState extends State<DonorLoginScreen> {
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();

//   bool isLoading = false;
//   bool _obscurePassword = true;

//   void showMessage({
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

//       debugPrint("DONOR FCM Permission: ${settings.authorizationStatus}");

//       await FirebaseMessaging.instance.setAutoInitEnabled(true);

//       String? fcmToken = await FirebaseMessaging.instance.getToken();

//       if (fcmToken == null || fcmToken.trim().isEmpty) {
//         await Future.delayed(const Duration(seconds: 2));
//         fcmToken = await FirebaseMessaging.instance.getToken();
//       }

//       debugPrint("DONOR FCM Token: $fcmToken");

//       if (fcmToken == null || fcmToken.trim().isEmpty) {
//         return null;
//       }

//       return fcmToken.trim();
//     } catch (e) {
//       debugPrint("DONOR FCM Token Error: $e");
//       return null;
//     }
//   }

//   Future<void> loginUser() async {
//     FocusScope.of(context).unfocus();

//     final String email = emailController.text.trim().toLowerCase();
//     final String password = passwordController.text.trim();

//     if (email.isEmpty || password.isEmpty) {
//       showMessage(message: "Please fill all fields");
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       final user = await AuthSdk.login(
//         email: email,
//         password: password,
//         expectedRole: 'donor',
//       );

//       final firebaseUser = FirebaseAuth.instance.currentUser;

//       if (firebaseUser == null) {
//         throw const SdkException('Login session not found.');
//       }

//       await firebaseUser.reload();

//       final refreshedUser = FirebaseAuth.instance.currentUser;

//       if (refreshedUser == null) {
//         throw const SdkException('Login session not found.');
//       }

//       if (!refreshedUser.emailVerified) {
//         try {
//           await refreshedUser.sendEmailVerification();
//         } catch (_) {}

//         if (!mounted) return;

//         setState(() => isLoading = false);

//         showMessage(
//           message: 'Please verify your email first. Verification email sent.',
//           backgroundColor: Colors.orange,
//         );

//         await Future.delayed(const Duration(milliseconds: 700));

//         if (!mounted) return;

//         Navigator.pushReplacementNamed(context, AppRoutes.donorVerifyEmail);
//         return;
//       }

//       final String? fcmToken = await _getFcmToken();

//       bool fcmTokenSaved = false;

//       if (fcmToken != null && fcmToken.isNotEmpty) {
//         await AuthSdk.saveFcmTokenForUser(
//           user: user,
//           fcmToken: fcmToken,
//           deviceType: 'android',
//         );

//         fcmTokenSaved = true;
//       }

//       debugPrint("DONOR LOGIN SUCCESS");
//       debugPrint("DONOR FCM TOKEN SAVED: $fcmTokenSaved");

//       if (!mounted) return;

//       setState(() => isLoading = false);

//       if (!fcmTokenSaved) {
//         showMessage(
//           message: "Login successful, but notification token was not saved.",
//           backgroundColor: Colors.orange,
//         );

//         await Future.delayed(const Duration(milliseconds: 500));
//       }

//       if (!mounted) return;

//       Navigator.pushReplacementNamed(context, AppRoutes.donorHome);
//     } on SdkException catch (e) {
//       if (!mounted) return;

//       setState(() => isLoading = false);

//       showMessage(message: e.message);
//     } on FirebaseAuthException catch (e) {
//       if (!mounted) return;

//       setState(() => isLoading = false);

//       showMessage(message: e.message ?? 'Login failed. Please try again.');
//     } catch (e) {
//       if (!mounted) return;

//       setState(() => isLoading = false);

//       debugPrint("Donor login unknown error: $e");

//       showMessage(message: "Login failed. Please try again.");
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     debugPrint("DONOR LOGIN SCREEN BUILD RUNNING");

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
//           child: SingleChildScrollView(
//             keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 24),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.center,
//                 children: [
//                   const SizedBox(height: 20),

//                   Align(
//                     alignment: Alignment.centerLeft,
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: Colors.white.withOpacity(0.15),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: IconButton(
//                         icon: const Icon(
//                           Icons.arrow_back_ios_new_rounded,
//                           color: Colors.white,
//                           size: 20,
//                         ),
//                         onPressed: isLoading
//                             ? null
//                             : () {
//                                 if (Navigator.canPop(context)) {
//                                   Navigator.pop(context);
//                                 } else {
//                                   Navigator.pushReplacementNamed(
//                                     context,
//                                     AppRoutes.roleSelection,
//                                   );
//                                 }
//                               },
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 20),

//                   const Text(
//                     "Welcome Back",
//                     style: TextStyle(
//                       fontSize: 34,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.white,
//                     ),
//                   ),

//                   const SizedBox(height: 12),

//                   Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 28,
//                       vertical: 10,
//                     ),
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.18),
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                     child: const Text(
//                       "Donor",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 16.5,
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 40),

//                   Container(
//                     decoration: BoxDecoration(
//                       color: Colors.white.withOpacity(0.15),
//                       borderRadius: BorderRadius.circular(30),
//                     ),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             decoration: const BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.horizontal(
//                                 left: Radius.circular(30),
//                               ),
//                             ),
//                             child: const Text(
//                               "Login",
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                                 color: Color(0xFF6B0000),
//                               ),
//                             ),
//                           ),
//                         ),
//                         Expanded(
//                           child: GestureDetector(
//                             onTap: isLoading
//                                 ? null
//                                 : () => Navigator.pushReplacementNamed(
//                                       context,
//                                       AppRoutes.donorRegister,
//                                     ),
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(vertical: 14),
//                               child: const Text(
//                                 "Register",
//                                 textAlign: TextAlign.center,
//                                 style: TextStyle(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                   color: Colors.white,
//                                 ),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   const SizedBox(height: 30),

//                   Container(
//                     decoration: BoxDecoration(
//                       color: whiteColor,
//                       borderRadius: BorderRadius.circular(32),
//                     ),
//                     padding: const EdgeInsets.fromLTRB(24, 36, 24, 40),
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         _buildTextField(
//                           hint: "Email Address",
//                           icon: Icons.alternate_email,
//                           controller: emailController,
//                           keyboardType: TextInputType.emailAddress,
//                           textInputAction: TextInputAction.next,
//                         ),

//                         const SizedBox(height: 16),

//                         _buildTextField(
//                           hint: "Password",
//                           icon: Icons.lock_outline,
//                           controller: passwordController,
//                           isPassword: true,
//                           keyboardType: TextInputType.visiblePassword,
//                           textInputAction: TextInputAction.done,
//                           onSubmitted: (_) {
//                             if (!isLoading) {
//                               loginUser();
//                             }
//                           },
//                         ),

//                         const SizedBox(height: 8),

//                         Align(
//                           alignment: Alignment.centerRight,
//                           child: TextButton(
//                             onPressed: isLoading
//                                 ? null
//                                 : () => Navigator.pushNamed(
//                                       context,
//                                       AppRoutes.donorForgetPassword,
//                                     ),
//                             child: const Text(
//                               "Forgot Password?",
//                               style: TextStyle(
//                                 color: primaryMaroon,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                           ),
//                         ),

//                         const SizedBox(height: 20),

//                         SizedBox(
//                           width: double.infinity,
//                           height: 58,
//                           child: ElevatedButton(
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: primaryMaroon,
//                               disabledBackgroundColor:
//                                   primaryMaroon.withOpacity(0.65),
//                               shape: RoundedRectangleBorder(
//                                 borderRadius: BorderRadius.circular(18),
//                               ),
//                             ),
//                             onPressed: isLoading ? null : loginUser,
//                             child: isLoading
//                                 ? const SizedBox(
//                                     width: 24,
//                                     height: 24,
//                                     child: CircularProgressIndicator(
//                                       color: whiteColor,
//                                       strokeWidth: 2.5,
//                                     ),
//                                   )
//                                 : const Text(
//                                     "LOGIN",
//                                     style: TextStyle(
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.bold,
//                                       color: whiteColor,
//                                     ),
//                                   ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   const SizedBox(height: 40),

//                   GestureDetector(
//                     onTap: isLoading
//                         ? null
//                         : () => Navigator.pushNamed(
//                               context,
//                               AppRoutes.donorPhoneLogin,
//                             ),
//                     child: const Row(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Icon(Icons.phone_android, color: whiteColor, size: 24),
//                         SizedBox(width: 10),
//                         Text(
//                           "Login with Phone",
//                           style: TextStyle(
//                             fontSize: 16.5,
//                             color: whiteColor,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   const SizedBox(height: 24),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField({
//     required String hint,
//     required IconData icon,
//     required TextEditingController controller,
//     bool isPassword = false,
//     TextInputType keyboardType = TextInputType.text,
//     TextInputAction textInputAction = TextInputAction.next,
//     void Function(String)? onSubmitted,
//   }) {
//     return Container(
//       decoration: BoxDecoration(
//         color: const Color(0xFFF8F8F8),
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: TextField(
//         controller: controller,
//         obscureText: isPassword && _obscurePassword,
//         keyboardType: keyboardType,
//         textInputAction: textInputAction,
//         enabled: !isLoading,
//         onSubmitted: onSubmitted,
//         decoration: InputDecoration(
//           prefixIcon: Icon(icon, color: primaryMaroon),
//           hintText: hint,
//           hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
//           border: InputBorder.none,
//           contentPadding: const EdgeInsets.symmetric(
//             vertical: 18,
//             horizontal: 4,
//           ),
//           suffixIcon: isPassword
//               ? IconButton(
//                   icon: Icon(
//                     _obscurePassword
//                         ? Icons.visibility_off
//                         : Icons.visibility,
//                     color: primaryMaroon,
//                   ),
//                   onPressed: isLoading
//                       ? null
//                       : () {
//                           setState(() {
//                             _obscurePassword = !_obscurePassword;
//                           });
//                         },
//                 )
//               : null,
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     emailController.dispose();
//     passwordController.dispose();
//     super.dispose();
//   }
// }