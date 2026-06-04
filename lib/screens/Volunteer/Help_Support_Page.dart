// lib/screens/HelpSupportScreen.dart
import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support"), backgroundColor: primaryMaroon),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.support_agent, size: 100, color: Colors.grey),
            SizedBox(height: 20),
            Text("Help & Support", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text("24/7 Volunteer Support Available"),
          ],
        ),
      ),
    );
  }
}