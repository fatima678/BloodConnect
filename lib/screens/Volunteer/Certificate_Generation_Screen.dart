// // lib/screens/CertificateGenerationScreen.dart
// import 'package:flutter/material.dart';
// import 'package:blood_donation_app/theme.dart';

// class CertificateGenerationScreen extends StatefulWidget {
//   const CertificateGenerationScreen({super.key});

//   @override
//   State<CertificateGenerationScreen> createState() => _CertificateGenerationScreenState();
// }

// class _CertificateGenerationScreenState extends State<CertificateGenerationScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   String _searchQuery = "";

//   // Sample Donors Data
//   final List<Map<String, dynamic>> donors = [
//     {
//       "name": "Muhammad Ali",
//       "bloodGroup": "O+",
//       "phone": "03001234567",
//       "lastDonation": "12 May 2026",
//       "totalDonations": 5,
//       "eligible": true,
//     },
//     {
//       "name": "Ayesha Khan",
//       "bloodGroup": "A-",
//       "phone": "03335678901",
//       "lastDonation": "05 April 2026",
//       "totalDonations": 3,
//       "eligible": false,
//     },
//     {
//       "name": "Usman Raza",
//       "bloodGroup": "B+",
//       "phone": "03119876543",
//       "lastDonation": "18 May 2026",
//       "totalDonations": 2,
//       "eligible": true,
//     },
//   ];

//   List<Map<String, dynamic>> get filteredDonors {
//     if (_searchQuery.isEmpty) return donors;
//     return donors.where((donor) {
//       return donor["name"]!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
//           donor["phone"]!.contains(_searchQuery);
//     }).toList();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Generate Certificate"),
//         backgroundColor: primaryMaroon,
//         foregroundColor: Colors.white,
//         actions: [
//           IconButton(icon: const Icon(Icons.search), onPressed: () {}),
//         ],
//       ),
//       body: Column(
//         children: [
//           // Search Bar
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: TextField(
//               controller: _searchController,
//               onChanged: (value) => setState(() => _searchQuery = value),
//               decoration: InputDecoration(
//                 hintText: "Search donor by name, phone or blood group...",
//                 prefixIcon: const Icon(Icons.search),
//                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//                 filled: true,
//                 fillColor: Colors.grey[100],
//               ),
//             ),
//           ),

//           // Donor List
//           Expanded(
//             child: filteredDonors.isEmpty
//                 ? const Center(child: Text("No donors found"))
//                 : ListView.builder(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     itemCount: filteredDonors.length,
//                     itemBuilder: (context, index) {
//                       final donor = filteredDonors[index];
//                       return Card(
//                         margin: const EdgeInsets.only(bottom: 12),
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                         child: ListTile(
//                           leading: CircleAvatar(
//                             backgroundColor: primaryMaroon.withOpacity(0.1),
//                             child: Text(donor["bloodGroup"], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
//                           ),
//                           title: Text(donor["name"], style: const TextStyle(fontWeight: FontWeight.bold)),
//                           subtitle: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(donor["phone"]),
//                               Text("Last donated: ${donor["lastDonation"]}"),
//                             ],
//                           ),
//                           trailing: donor["eligible"]
//                               ? const Icon(Icons.check_circle, color: Colors.green)
//                               : const Icon(Icons.warning_amber, color: Colors.orange),
//                           onTap: () => _showDonorDetailBottomSheet(donor),
//                         ),
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showDonorDetailBottomSheet(Map<String, dynamic> donor) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
//       builder: (context) => DraggableScrollableSheet(
//         initialChildSize: 0.85,
//         minChildSize: 0.6,
//         maxChildSize: 0.95,
//         expand: false,
//         builder: (context, scrollController) => SingleChildScrollView(
//           controller: scrollController,
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Center(
//                   child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
//                 ),
//                 const SizedBox(height: 20),

//                 // Donor Info
//                 Row(
//                   children: [
//                     CircleAvatar(radius: 35, backgroundColor: primaryMaroon.withOpacity(0.1), child: Text(donor["bloodGroup"], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
//                     const SizedBox(width: 16),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(donor["name"], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
//                           Text(donor["phone"], style: const TextStyle(fontSize: 16)),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),

//                 const Divider(height: 30),

//                 // Form Fields
//                 const Text("Donation Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                 const SizedBox(height: 16),

//                 TextField(decoration: const InputDecoration(labelText: "Units Donated"), keyboardType: TextInputType.number, controller: TextEditingController(text: "1")),
//                 const SizedBox(height: 16),
//                 TextField(decoration: const InputDecoration(labelText: "Place of Donation (Blood Bank / Hospital)")),
//                 const SizedBox(height: 16),
//                 TextField(decoration: const InputDecoration(labelText: "Remarks (Optional)"), maxLines: 3),

//                 const SizedBox(height: 30),

//                 // Generate Button
//                 SizedBox(
//                   width: double.infinity,
//                   height: 55,
//                   child: ElevatedButton(
//                     style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
//                     onPressed: () {
//                       Navigator.pop(context);
//                       _showCertificatePreview(donor);
//                     },
//                     child: const Text("Generate Certificate", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   void _showCertificatePreview(Map<String, dynamic> donor) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Certificate Preview"),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(border: Border.all(color: primaryMaroon, width: 2), borderRadius: BorderRadius.circular(12)),
//               child: Column(
//                 children: [
//                   const Icon(Icons.bloodtype, size: 60, color: Color(0xFF6B0000)),
//                   const Text("Blood Connect", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
//                   const Text("Certificate of Blood Donation", style: TextStyle(fontSize: 16)),
//                   const SizedBox(height: 20),
//                   Text(donor["name"], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
//                   Text("Blood Group: ${donor["bloodGroup"]}", style: const TextStyle(fontSize: 18)),
//                   const Text("Donated 1 Unit on 18 May 2026"),
//                   const SizedBox(height: 20),
//                   const Icon(Icons.qr_code, size: 100),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(content: Text("Certificate Generated & Saved Successfully!")),
//               );
//             },
//             child: const Text("Confirm & Issue"),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }
// }