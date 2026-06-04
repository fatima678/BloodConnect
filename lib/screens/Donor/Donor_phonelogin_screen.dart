// import 'package:flutter/material.dart';
// import 'package:country_code_picker/country_code_picker.dart';
// import '../../../constants.dart';
// import '../../../routes.dart';

// class PhoneLoginPage extends StatefulWidget {
//   final String role;
//   const PhoneLoginPage({super.key, required this.role});

//   @override
//   State<PhoneLoginPage> createState() => _PhoneLoginPageState();
// }

// class _PhoneLoginPageState extends State<PhoneLoginPage>
//     with TickerProviderStateMixin {
//   late AnimationController _fadeInController;
//   late AnimationController _jerkController;
//   late Animation<double> _fadeIn;
//   late Animation<Offset> _jerkAnimation;

//   // Add a controller to capture the phone number input
//   final TextEditingController _phoneController = TextEditingController();

//   @override
//   void initState() {
//     super.initState();

//     _fadeInController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );
//     _fadeIn = CurvedAnimation(parent: _fadeInController, curve: Curves.easeIn);
//     _fadeInController.forward();

//     _jerkController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 1500),
//     )..repeat(reverse: true);

//     _jerkAnimation =
//         Tween<Offset>(
//           begin: const Offset(-0.05, 0),
//           end: const Offset(0.05, 0),
//         ).animate(
//           CurvedAnimation(parent: _jerkController, curve: Curves.easeInOutSine),
//         );
//   }

//   @override
//   void dispose() {
//     _fadeInController.dispose();
//     _jerkController.dispose();
//     _phoneController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         elevation: 0,
//         backgroundColor: primaryMaroon,
//         title: Text(
//           "Login ${widget.role}",
//           style: const TextStyle(color: Colors.white),
//         ),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: FadeTransition(
//         opacity: _fadeIn,
//         child: SingleChildScrollView(
//           child: Column(
//             children: [
//               const SizedBox(height: 40),

//               SlideTransition(
//                 position: _jerkAnimation,
//                 child: Center(
//                   child: Image.asset(
//                     'lib/assets/Login-pana.png',
//                     height: 220,
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 30),
//               const Text(
//                 "Login with phone number",
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 30),

//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 10),
//                   decoration: BoxDecoration(
//                     border: Border.all(color: Colors.grey.shade300),
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Row(
//                     children: [
//                       CountryCodePicker(
//                         onChanged: (country) {
//                           // Handle selection
//                         },
//                         initialSelection: 'PK',
//                         favorite: const ['PK', 'AE', 'SA'],
//                         showCountryOnly: false,
//                         showOnlyCountryWhenClosed: false,
//                         alignLeft: false,
//                         padding: EdgeInsets.zero,
//                       ),
//                       const Text(
//                         "|",
//                         style: TextStyle(color: Colors.grey, fontSize: 25),
//                       ),
//                       Expanded(
//                         child: TextField(
//                           controller: _phoneController,
//                           keyboardType: TextInputType.phone,
//                           decoration: const InputDecoration(
//                             hintText: "300 1234567",
//                             border: InputBorder.none,
//                             contentPadding: EdgeInsets.only(left: 10),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 40),

//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 24),
//                 child: SizedBox(
//                   width: double.infinity,
//                   height: 55,
//                   child: ElevatedButton(
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: primaryMaroon,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                     ),
//                     onPressed: () {
//                       // 👉 YAHAN CHANGE KIYA HAI: Direct routes.dart wala function call kiya
//                       AppRoutes.goToOtp(context, _phoneController.text);
//                     },
//                     child: const Text(
//                       "SEND OTP",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
