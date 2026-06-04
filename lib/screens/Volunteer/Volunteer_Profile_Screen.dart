// lib/screens/VolunteerProfileScreen.dart
import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';

class VolunteerProfileScreen extends StatelessWidget {
  const VolunteerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Volunteer Profile"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              color: primaryMaroon,
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.groups_rounded, size: 60, color: primaryMaroon),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Ahmed Khan",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Text(
                    "Volunteer • Verified",
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoTile(Icons.badge, "Volunteer ID", "VOL-98421"),
                  _buildInfoTile(Icons.bloodtype, "Preferred Blood Group", "O+"),
                  _buildInfoTile(Icons.location_on, "Location", "Rawalpindi, Pakistan"),
                  _buildInfoTile(Icons.phone, "Contact", "+92 300 1234567"),
                  _buildInfoTile(Icons.calendar_today, "Member Since", "March 2025"),

                  const SizedBox(height: 20),

                  // Volunteer Stats
                  Row(
                    children: [
                      _buildStatBox("Requests\nHandled", "47", Colors.green),
                      const SizedBox(width: 12),
                      _buildStatBox("Certificates\nIssued", "23", primaryMaroon),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Action Buttons
                  ListTile(
                    leading: const Icon(Icons.edit, color: primaryMaroon),
                    title: const Text("Edit Profile"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.card_giftcard, color: primaryMaroon),
                    title: const Text("Generate Certificate"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.history, color: primaryMaroon),
                    title: const Text("Donation History"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings, color: primaryMaroon),
                    title: const Text("Settings"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return ListTile(
      leading: Icon(icon, color: primaryMaroon),
      title: Text(title),
      subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}