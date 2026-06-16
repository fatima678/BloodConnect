// // lib/screens/role_screen.dart
// import 'package:flutter/material.dart';
// import '../theme.dart';
// import '../routes.dart';

// class RoleSelectionScreen extends StatefulWidget {
//   const RoleSelectionScreen({super.key});

//   @override
//   State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
// }

// class _RoleSelectionScreenState extends State<RoleSelectionScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<double> _fadeAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(milliseconds: 1200),
//       vsync: this,
//     );
//     _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
//       CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
//     );
//     _controller.forward();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: const BoxDecoration(gradient: splashGradient),
//         child: SafeArea(
//           child: FadeTransition(
//             opacity: _fadeAnimation,
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 24.0),
//               child: Column(
//                 children: [
//                   const SizedBox(height: 40),

//                   // Header
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const SizedBox(width: 12),
//                       const Text(
//                         appName,
//                         style: TextStyle(
//                           fontSize: 28,
//                           fontWeight: FontWeight.bold,
//                           color: whiteColor,
//                           letterSpacing: 1,
//                           height: 5,
//                         ),
//                       ),
//                     ],
//                   ),

//                   const SizedBox(height: 3),
//                   const Text(
//                     continueAs,
//                     style: TextStyle(fontSize: 20, color: whiteColor70, fontWeight: FontWeight.w500),
//                   ),

//                   const SizedBox(height: 40),

//                   // Role Cards
//                   Expanded(
//                     child: Center(
//                       child: SingleChildScrollView(
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             // Patient Role Card
//                             _buildRoleCard(
//                               icon: Icons.personal_injury_rounded,
//                               title: "Patient",
//                               subtitle: "Request blood and find nearby donors quickly.",
//                               color: primaryMaroon,
//                               onTap: () => Navigator.pushNamed(
//                                 context,
//                                 AppRoutes.patientLogin, // ← Routes explicitly to Patient Flow
//                               ),
//                             ),

//                             const SizedBox(height: 16),

//                             // Donor Role Card
//                             _buildRoleCard(
//                               icon: Icons.volunteer_activism_rounded,
//                               title: "Donor",
//                               subtitle: "Donate blood, earn rewards, and save lives.",
//                               color: primaryMaroon,
//                               onTap: () => Navigator.pushNamed(
//                                 context,
//                                 AppRoutes.donorLogin, // ← Routes explicitly to Donor Flow
//                               ),  
//                             ),

//                             const SizedBox(height: 16),

//                             // Volunteer Role Card
//                             _buildRoleCard(
//                               icon: Icons.group_rounded,
//                               title: "Volunteer",
//                               subtitle: "Help coordinate blood drives and support the community.",
//                               color: primaryMaroon,
//                               onTap: () => Navigator.pushNamed(
//                                 context,
//                                 AppRoutes.volunteerLogin, // ← Routes explicitly to Volunteer Flow
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 20),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildRoleCard({
//     required IconData icon,
//     required String title,
//     required String subtitle,
//     required Color color,
//     required VoidCallback onTap,
//   }) {
//     return TweenAnimationBuilder<double>(
//       tween: Tween<double>(begin: 0, end: 1),
//       duration: const Duration(milliseconds: 800),
//       curve: Curves.easeOutBack,
//       builder: (context, double value, child) {
//         return Transform.scale(
//           scale: value,
//           child: Container(
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(24),
//               border: Border.all(color: color.withOpacity(0.15), width: 1.5),
//               boxShadow: [
//                 BoxShadow(
//                   color: color.withOpacity(0.12),
//                   blurRadius: 20,
//                   spreadRadius: -2,
//                   offset: const Offset(0, 10),
//                 ),
//               ],
//             ),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 onTap: onTap,
//                 borderRadius: BorderRadius.circular(24),
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
//                   child: Row(
//                     children: [
//                       Container(
//                         height: 60,
//                         width: 60,
//                         decoration: BoxDecoration(
//                           gradient: LinearGradient(
//                             colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
//                             begin: Alignment.topLeft,
//                             end: Alignment.bottomRight,
//                           ),
//                           borderRadius: BorderRadius.circular(16),
//                         ),
//                         child: Icon(icon, size: 30, color: color),
//                       ),
//                       const SizedBox(width: 20),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               title,
//                               style: const TextStyle(
//                                 fontSize: 19,
//                                 fontWeight: FontWeight.w800,
//                                 color: Colors.black87,
//                               ),
//                             ),
//                             const SizedBox(height: 6),
//                             Text(
//                               subtitle,
//                               style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.3),
//                             ),
//                           ],
//                         ),
//                       ),
//                       Container(
//                         padding: const EdgeInsets.all(8),
//                         decoration: BoxDecoration(
//                           color: color.withOpacity(0.08),
//                           shape: BoxShape.circle,
//                         ),
//                         child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }