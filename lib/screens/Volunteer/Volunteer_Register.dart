// // lib/screens/Volunteer/Volunteer_Register.dart

// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';

// import '../../theme.dart';
// import '../../../routes.dart';
// import '../Volunteer/Volunteer_Login_Screen.dart';
// import '../../sdk/auth/auth_sdk.dart';
// import '../../sdk/core/sdk_exception.dart';

// class VolunteerRegisterScreen extends StatefulWidget {
//   const VolunteerRegisterScreen({super.key});

//   @override
//   State<VolunteerRegisterScreen> createState() =>
//       _VolunteerRegisterScreenState();
// }

// class _VolunteerRegisterScreenState extends State<VolunteerRegisterScreen> {
//   final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController phoneController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();

//   String? selectedBloodGroup;

//   bool isLoading = false;
//   bool autoValidate = false;
//   bool obscurePassword = true;

//   final List<String> bloodGroups = [
//     'A+',
//     'A-',
//     'B+',
//     'B-',
//     'AB+',
//     'AB-',
//     'O+',
//     'O-',
//   ];

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

//   String? validateName(String? value) {
//     final String text = value?.trim() ?? '';

//     if (text.isEmpty) {
//       return 'Full name is required.';
//     }

//     if (text.length < 2) {
//       return 'Full name must be at least 2 characters.';
//     }

//     return null;
//   }

//   String? validateEmail(String? value) {
//     final String email = value?.trim() ?? '';

//     if (email.isEmpty) {
//       return 'Email is required.';
//     }

//     final RegExp emailRegex = RegExp(
//       r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
//     );

//     if (!emailRegex.hasMatch(email)) {
//       return 'Please enter a valid email address.';
//     }

//     return null;
//   }

//   String? validatePhone(String? value) {
//     final String phone = value?.trim() ?? '';

//     if (phone.isEmpty) {
//       return 'Phone number is required.';
//     }

//     final String cleanedPhone = phone.replaceAll(RegExp(r'[\s-]'), '');

//     final RegExp phoneRegex = RegExp(r'^(03[0-9]{9}|\+923[0-9]{9})$');

//     if (!phoneRegex.hasMatch(cleanedPhone)) {
//       return 'Enter valid Pakistani number: 03001234567 or +923001234567.';
//     }

//     return null;
//   }

//   String? validatePassword(String? value) {
//     final String password = value ?? '';

//     if (password.trim().isEmpty) {
//       return 'Password is required.';
//     }

//     if (password.length < 6) {
//       return 'Password must be at least 6 characters.';
//     }

//     if (password.contains(' ')) {
//       return 'Password should not contain spaces.';
//     }

//     return null;
//   }

//   String? validateBloodGroup(String? value) {
//     if (value == null || value.trim().isEmpty) {
//       return 'Please select a blood type.';
//     }

//     return null;
//   }

//   Future<void> registerVolunteer() async {
//     FocusScope.of(context).unfocus();

//     setState(() {
//       autoValidate = true;
//     });

//     if (!_formKey.currentState!.validate()) {
//       showMessage(message: 'Please correct the highlighted fields.');
//       return;
//     }

//     final String name = nameController.text.trim();
//     final String email = emailController.text.trim().toLowerCase();
//     final String phone = phoneController.text.trim().replaceAll(
//           RegExp(r'[\s-]'),
//           '',
//         );
//     final String password = passwordController.text;

//     try {
//       setState(() => isLoading = true);

//       await AuthSdk.registerUser(
//         name: name,
//         email: email,
//         phone: phone,
//         password: password,
//         role: 'team_volunteer',
//         bloodGroup: selectedBloodGroup,
//       );

//       final firebaseUser = FirebaseAuth.instance.currentUser;

//       if (firebaseUser != null && !firebaseUser.emailVerified) {
//         await firebaseUser.sendEmailVerification();
//       }

//       /*
//         FirebaseAuth registration ke baad user automatically logged-in ho jata hai.
//         Email verification send karne ke baad old flow maintain karne ke liye
//         logout karke volunteer login screen par redirect kar rahe hain.
//       */
//       await AuthSdk.logout();

//       if (!mounted) return;

//       setState(() => isLoading = false);

//       showMessage(
//         message: 'Registration successful. Verification email sent.',
//         backgroundColor: Colors.green,
//       );

//       await Future.delayed(const Duration(milliseconds: 900));

//       if (!mounted) return;

//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => const VolunteerLoginScreen(),
//         ),
//       );
//     } on FirebaseAuthException catch (e) {
//       if (!mounted) return;

//       setState(() => isLoading = false);

//       showMessage(
//         message: e.message ?? 'Failed to send verification email.',
//       );
//     } on SdkException catch (e) {
//       if (!mounted) return;

//       setState(() => isLoading = false);

//       showMessage(message: e.message);
//     } catch (e) {
//       if (!mounted) return;

//       setState(() => isLoading = false);

//       showMessage(
//         message: 'Registration failed. Please try again.',
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
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
//                                   Navigator.pushReplacementNamed(context, '/');
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
//                       "Create New Account",
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
//                           child: GestureDetector(
//                             onTap: isLoading
//                                 ? null
//                                 : () => Navigator.pushReplacementNamed(
//                                       context,
//                                       AppRoutes.volunteerLogin,
//                                     ),
//                             child: Container(
//                               padding: const EdgeInsets.symmetric(vertical: 14),
//                               child: const Text(
//                                 "Login",
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
//                         Expanded(
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             decoration: const BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.horizontal(
//                                 right: Radius.circular(30),
//                               ),
//                             ),
//                             child: const Text(
//                               "Register",
//                               textAlign: TextAlign.center,
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 fontWeight: FontWeight.bold,
//                                 color: primaryMaroon,
//                               ),
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),

//                   const SizedBox(height: 40),

//                   Container(
//                     decoration: BoxDecoration(
//                       color: whiteColor,
//                       borderRadius: BorderRadius.circular(32),
//                     ),
//                     padding: const EdgeInsets.fromLTRB(24, 36, 24, 40),
//                     child: Form(
//                       key: _formKey,
//                       autovalidateMode: autoValidate
//                           ? AutovalidateMode.onUserInteraction
//                           : AutovalidateMode.disabled,
//                       child: Column(
//                         children: [
//                           buildField(
//                             hint: "Full Name",
//                             icon: Icons.person,
//                             controller: nameController,
//                             keyboardType: TextInputType.name,
//                             textInputAction: TextInputAction.next,
//                             validator: validateName,
//                           ),

//                           const SizedBox(height: 20),

//                           buildField(
//                             hint: "Email",
//                             icon: Icons.email,
//                             controller: emailController,
//                             keyboardType: TextInputType.emailAddress,
//                             textInputAction: TextInputAction.next,
//                             validator: validateEmail,
//                           ),

//                           const SizedBox(height: 20),

//                           buildField(
//                             hint: "Phone",
//                             icon: Icons.phone,
//                             controller: phoneController,
//                             keyboardType: TextInputType.phone,
//                             textInputAction: TextInputAction.next,
//                             validator: validatePhone,
//                           ),

//                           const SizedBox(height: 20),

//                           buildField(
//                             hint: "Password",
//                             icon: Icons.lock,
//                             controller: passwordController,
//                             isPass: true,
//                             keyboardType: TextInputType.visiblePassword,
//                             textInputAction: TextInputAction.next,
//                             validator: validatePassword,
//                           ),

//                           const SizedBox(height: 20),

//                           DropdownButtonFormField<String>(
//                             value: selectedBloodGroup,
//                             validator: validateBloodGroup,
//                             decoration: InputDecoration(
//                               filled: true,
//                               fillColor: const Color(0xFFF1F3F6),
//                               prefixIcon: const Icon(
//                                 Icons.bloodtype,
//                                 color: primaryMaroon,
//                               ),
//                               hintText: "Select blood type",
//                               hintStyle: const TextStyle(color: Colors.grey),
//                               errorMaxLines: 2,
//                               border: OutlineInputBorder(
//                                 borderSide: BorderSide.none,
//                                 borderRadius: BorderRadius.circular(15),
//                               ),
//                               enabledBorder: OutlineInputBorder(
//                                 borderSide: BorderSide.none,
//                                 borderRadius: BorderRadius.circular(15),
//                               ),
//                               focusedBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(15),
//                                 borderSide: const BorderSide(
//                                   color: primaryMaroon,
//                                   width: 1.2,
//                                 ),
//                               ),
//                               errorBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(15),
//                                 borderSide: const BorderSide(
//                                   color: Colors.red,
//                                   width: 1.1,
//                                 ),
//                               ),
//                               focusedErrorBorder: OutlineInputBorder(
//                                 borderRadius: BorderRadius.circular(15),
//                                 borderSide: const BorderSide(
//                                   color: Colors.red,
//                                   width: 1.2,
//                                 ),
//                               ),
//                               contentPadding: const EdgeInsets.symmetric(
//                                 horizontal: 16,
//                                 vertical: 18,
//                               ),
//                             ),
//                             icon: const Icon(
//                               Icons.arrow_drop_down,
//                               color: primaryMaroon,
//                             ),
//                             items: bloodGroups.map((String group) {
//                               return DropdownMenuItem<String>(
//                                 value: group,
//                                 child: Text(group),
//                               );
//                             }).toList(),
//                             onChanged: isLoading
//                                 ? null
//                                 : (String? value) {
//                                     setState(() {
//                                       selectedBloodGroup = value;
//                                     });
//                                   },
//                           ),

//                           const SizedBox(height: 25),

//                           Container(
//                             width: double.infinity,
//                             padding: const EdgeInsets.all(16),
//                             decoration: BoxDecoration(
//                               color: primaryMaroon.withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(15),
//                             ),
//                             child: const Text(
//                               "Registering as: Volunteer Team",
//                               style: TextStyle(
//                                 fontSize: 15,
//                                 fontWeight: FontWeight.bold,
//                                 color: primaryMaroon,
//                               ),
//                               textAlign: TextAlign.center,
//                             ),
//                           ),

//                           const SizedBox(height: 35),

//                           SizedBox(
//                             width: double.infinity,
//                             height: 55,
//                             child: ElevatedButton(
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: primaryMaroon,
//                                 disabledBackgroundColor:
//                                     primaryMaroon.withOpacity(0.65),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(15),
//                                 ),
//                               ),
//                               onPressed: isLoading ? null : registerVolunteer,
//                               child: isLoading
//                                   ? const SizedBox(
//                                       width: 24,
//                                       height: 24,
//                                       child: CircularProgressIndicator(
//                                         color: Colors.white,
//                                         strokeWidth: 2.5,
//                                       ),
//                                     )
//                                   : const Text(
//                                       "REGISTER",
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontWeight: FontWeight.bold,
//                                         fontSize: 16,
//                                       ),
//                                     ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 30),

//                   TextButton(
//                     onPressed: isLoading
//                         ? null
//                         : () => Navigator.pushReplacementNamed(
//                               context,
//                               AppRoutes.volunteerLogin,
//                             ),
//                     child: const Text(
//                       "Already have an account? Login",
//                       style: TextStyle(
//                         color: whiteColor,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 30),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget buildField({
//     required String hint,
//     required IconData icon,
//     required TextEditingController controller,
//     required String? Function(String?) validator,
//     bool isPass = false,
//     TextInputType keyboardType = TextInputType.text,
//     TextInputAction textInputAction = TextInputAction.next,
//     void Function(String)? onFieldSubmitted,
//   }) {
//     return TextFormField(
//       controller: controller,
//       obscureText: isPass ? obscurePassword : false,
//       keyboardType: keyboardType,
//       textInputAction: textInputAction,
//       validator: validator,
//       enabled: !isLoading,
//       onFieldSubmitted: onFieldSubmitted,
//       decoration: InputDecoration(
//         filled: true,
//         fillColor: const Color(0xFFF1F3F6),
//         prefixIcon: Icon(icon, color: primaryMaroon),
//         suffixIcon: isPass
//             ? IconButton(
//                 icon: Icon(
//                   obscurePassword ? Icons.visibility_off : Icons.visibility,
//                   color: primaryMaroon,
//                 ),
//                 onPressed: isLoading
//                     ? null
//                     : () {
//                         setState(() {
//                           obscurePassword = !obscurePassword;
//                         });
//                       },
//               )
//             : null,
//         hintText: hint,
//         errorMaxLines: 2,
//         border: OutlineInputBorder(
//           borderSide: BorderSide.none,
//           borderRadius: BorderRadius.circular(15),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderSide: BorderSide.none,
//           borderRadius: BorderRadius.circular(15),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(15),
//           borderSide: const BorderSide(
//             color: primaryMaroon,
//             width: 1.2,
//           ),
//         ),
//         errorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(15),
//           borderSide: const BorderSide(
//             color: Colors.red,
//             width: 1.1,
//           ),
//         ),
//         focusedErrorBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(15),
//           borderSide: const BorderSide(
//             color: Colors.red,
//             width: 1.2,
//           ),
//         ),
//         contentPadding: const EdgeInsets.symmetric(
//           horizontal: 20,
//           vertical: 18,
//         ),
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     nameController.dispose();
//     emailController.dispose();
//     phoneController.dispose();
//     passwordController.dispose();
//     super.dispose();
//   }
// }