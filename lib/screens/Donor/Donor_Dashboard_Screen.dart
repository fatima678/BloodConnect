// import 'package:flutter/material.dart';
// import 'package:blood_donation_app/constants.dart';

// class DashboardScreen extends StatelessWidget {
//   const DashboardScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Dashboard'),
//         backgroundColor: primaryMaroon,
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.logout),
//             onPressed: () {
//               // Direct navigation to splash/login screen
//               Navigator.of(
//                 context,
//               ).pushNamedAndRemoveUntil('/splash', (route) => false);
//             },
//           ),
//         ],
//       ),
//       body: Container(
//         decoration: const BoxDecoration(gradient: splashGradient),
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Text(
//                 'Admin Dashboard',
//                 style: TextStyle(
//                   fontSize: 28,
//                   fontWeight: FontWeight.bold,
//                   color: whiteColor,
//                 ),
//               ),
//               const SizedBox(height: 30),
//               GridView.count(
//                 shrinkWrap: true,
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 15,
//                 mainAxisSpacing: 15,
//                 children: [
//                   _DashboardCard(
//                     icon: Icons.people,
//                     title: 'Users',
//                     count: '1,234',
//                   ),
//                   _DashboardCard(
//                     icon: Icons.bloodtype,
//                     title: 'Blood Requests',
//                     count: '56',
//                   ),
//                   _DashboardCard(
//                     icon: Icons.local_hospital,
//                     title: 'Blood Banks',
//                     count: '12',
//                   ),
//                   _DashboardCard(
//                     icon: Icons.directions_car,
//                     title: 'Ambulances',
//                     count: '8',
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// class _DashboardCard extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String count;

//   const _DashboardCard({
//     required this.icon,
//     required this.title,
//     required this.count,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Card(
//       elevation: 5,
//       child: Container(
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(icon, size: 40, color: primaryMaroon),
//             const SizedBox(height: 10),
//             Text(
//               title,
//               style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//             const SizedBox(height: 10),
//             Text(
//               count,
//               style: const TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: primaryMaroon,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
