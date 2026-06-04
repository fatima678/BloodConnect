import 'package:flutter/material.dart';
import '../../theme.dart'; // AppTheme ki jagah constants import kiya

class FindVolunteerScreen extends StatelessWidget {
  static const String routeName = '/find_volunteer';

  // Constructor ko const bana diya
  const FindVolunteerScreen({super.key});

  // List ko static const kar diya taake const constructor kaam kare
  static const List<Map<String, String>> volunteers = [
    {
      "name": "Ahmed Raza",
      "location": "Karachi (Gulshan-e-Iqbal)",
      "phone": "+92 300 1234567",
      "bloodGroup": "A+",
    },

    {
      "name": "Hina Shaikh",
      "location": "Lahore (Wapda Town)",
      "phone": "+92 311 1122334",
      "bloodGroup": "O+",
    },
    {
      "name": "Bilal Qureshi",
      "location": "Rawalpindi (Satellite Town)",
      "phone": "+92 321 1234567",
      "bloodGroup": "B+",
    },
    {
      "name": "Fatima Khan",
      "location": "Islamabad (F-8)",
      "phone": "+92 333 1234567",
      "bloodGroup": "AB+",
    },
    {
      "name": "Usman Tariq",
      "location": "Faisalabad (Madina Town)",
      "phone": "+92 41 1122334",
      "bloodGroup": "A+",
    },
    {
      "name": "Zain Ali",
      "location": "Multan (Cantonment)",
      "phone": "+92 61 1122233",
      "bloodGroup": "O-",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Nearest Volunteer",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryMaroon, // Dark Mehroon theme
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.search),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: volunteers.length,
        itemBuilder: (context, index) {
          final volunteer = volunteers[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Profile Picture
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[200],
                    child: const Icon(
                      Icons.person,
                      size: 32,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          volunteer["name"]!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          volunteer["location"]!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          volunteer["phone"]!,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  // Call Button
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Calling ${volunteer["phone"]}..."),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.phone,
                        color: Colors.green,
                        size: 28,
                      ),
                    ),
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
