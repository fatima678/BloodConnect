// lib/screens/blood_request_nearby.dart
import 'package:flutter/material.dart';
import '../../theme.dart'; // AppTheme ki jagah constants import kiya
 
class BloodRequestsNearbyScreen extends StatelessWidget {
  static const String routeName = '/public_requests';

  const BloodRequestsNearbyScreen({super.key});

  
  static const List<Map<String, String>> requests = [
    {
      "name": "Ayesha Khan",
      "bloodGroup": "B+, 1 Pint, Fresh Blood",
      "location": "Gulshan-e-Iqbal, Karachi",
      "phone": "03001234567",
      "time": "Jun 12, 2024  10:11 pm",
    },
    {
      "name": "Muhammad Ahmed",
      "bloodGroup": "O-, 1 Pint, Fresh Blood",
      "location": "Wapda Town, Lahore",
      "phone": "03111222333",
      "time": "May 2, 2024  09:00 PM",
    },
    {
      "name": "Sara Ali",
      "bloodGroup": "B+, 2 Pints, PCV",
      "location": "Islamabad Highway, Rawalpindi",
      "phone": "03211234567",
      "time": "May 2, 2024  08:38 am",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Blood Requests Nearby",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryMaroon, // Dark Mehroon Theme
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        request["name"]!.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          request["bloodGroup"]!,
                          style: const TextStyle(
                            color: primaryMaroon, // Dark Mehroon
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    request["location"]!,
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(request["phone"]!),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Calling ${request["phone"]}..."),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryMaroon, // Dark Mehroon
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                        ),
                        child: const Text("ACCEPT"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Rejecting request..."),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[400],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: const Text("Reject"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
