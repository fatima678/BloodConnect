import 'package:flutter/material.dart';

import 'package:blood_donation_app/theme.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: primaryMaroon,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primaryMaroon.withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.bloodtype,
              color: primaryMaroon,
              size: 42,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Blood Connect',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'A simple and reliable way to connect people who need blood with nearby available donors.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryMaroon.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: primaryMaroon.withOpacity(0.10),
            child: Icon(icon, color: primaryMaroon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: primaryMaroon.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: primaryMaroon.withOpacity(0.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: primaryMaroon,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildFeaturesCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryMaroon.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Main Features',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _buildFeatureChip('Find Donors'),
              _buildFeatureChip('Blood Requests'),
              _buildFeatureChip('Blood Banks'),
              _buildFeatureChip('Contact Donors'),
              _buildFeatureChip('Notifications'),
              _buildFeatureChip('Profile & Blood Type'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryMaroon.withOpacity(0.12)),
      ),
      child: const Text(
        'Important: Blood Connect helps users connect faster, but users should always confirm donor details, hospital requirements, and medical suitability before donation.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.black54,
          fontSize: 13.5,
          height: 1.45,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: const Text('About App'),
        centerTitle: true,
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _buildHeroCard(),
            _buildSectionCard(
              icon: Icons.flag_outlined,
              title: 'Our Mission',
              body:
                  'Blood Connect is built to reduce the time gap between people who urgently need blood and users who are willing to donate.',
            ),
            _buildSectionCard(
              icon: Icons.hub_outlined,
              title: 'How It Works',
              body:
                  'A user submits a blood request with location and blood group. Nearby matching users can receive requests, accept them, and share contact details after consent.',
            ),
            _buildFeaturesCard(),
            _buildSectionCard(
              icon: Icons.security_outlined,
              title: 'Privacy & Safety',
              body:
                  'Contact details are only shown after a request is accepted. Users can manage profile details such as address, phone number, and blood type.',
            ),
            _buildSectionCard(
              icon: Icons.people_alt_outlined,
              title: 'Who Can Use It',
              body:
                  'Anyone who wants to request blood, donate blood, search blood banks, or help others during emergency blood needs can use this app.',
            ),
            _buildSectionCard(
              icon: Icons.system_update_alt,
              title: 'App Version',
              body:
                  'Version 1.0.0. This release focuses on user profiles, blood requests, nearby donors, donor contact flow, and notifications.',
            ),
            _buildFooterCard(),
          ],
        ),
      ),
    );
  }
}