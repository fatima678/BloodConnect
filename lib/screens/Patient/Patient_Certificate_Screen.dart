// // lib/screens/certificate_screen.dart
// import 'package:flutter/material.dart';
// import 'package:blood_donation_app/theme.dart';

// class PatientCertificateScreen extends StatelessWidget {
//   static const String routeName = '/certificate';

//   const PatientCertificateScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Donation Certificate"),
//         flexibleSpace: Container(
//           decoration: const BoxDecoration(color: primaryMaroon),
//         ),
//       ),
//       body: Center(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             children: [
//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(30),
//                 decoration: BoxDecoration(
//                   border: Border.all(color: primaryMaroon, width: 3),
//                   borderRadius: BorderRadius.circular(20),
//                   color: Colors.white,
//                 ),
//                 child: Column(
//                   children: [
//                     const Icon(Icons.verified, size: 80, color: Colors.green),
//                     const SizedBox(height: 20),
//                     Text(
//                       "Certificate of Appreciation",
//                       style: TextStyle(
//                         fontSize: 22,
//                         fontWeight: FontWeight.bold,
//                         color: primaryMaroon,
//                       ),
//                     ),
//                     const SizedBox(height: 30),

//                     const Text("This is to certify that", style: TextStyle(fontSize: 16)),
//                     const SizedBox(height: 10),
//                     const Text(
//                       "John Doe", // Replace with dynamic name later
//                       style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                     ),
//                     const SizedBox(height: 20),

//                     const Text(
//                       "has donated blood on",
//                       style: TextStyle(fontSize: 16),
//                     ),
//                     const Text(
//                       "12 May 2026",
//                       style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
//                     ),
//                     const SizedBox(height: 30),

//                     const Text(
//                       "Thank you for saving lives!",
//                       style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
//                     ),
//                     const SizedBox(height: 40),

//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
//                       decoration: BoxDecoration(
//                         border: Border.all(color: Colors.red),
//                         borderRadius: BorderRadius.circular(30),
//                       ),
//                       child: const Text(
//                         "Blood Connect • Nepal",
//                         style: TextStyle(fontWeight: FontWeight.bold),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),

//               const SizedBox(height: 30),

//               ElevatedButton.icon(
//                 onPressed: () {
//                   ScaffoldMessenger.of(context).showSnackBar(
//                     const SnackBar(content: Text("Certificate Downloaded!")),
//                   );
//                 },
//                 icon: const Icon(Icons.download),
//                 label: const Text("Download Certificate"),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: primaryMaroon,
//                   padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }