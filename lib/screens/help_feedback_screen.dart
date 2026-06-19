import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_donation_app/theme.dart';

class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  final TextEditingController _messageController = TextEditingController();

  String _selectedCategory = 'General Help';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'General Help',
    'Blood Request Issue',
    'Donor Contact Issue',
    'Notification Issue',
    'Profile Issue',
    'Other Feedback',
  ];

  String _now() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceFirst('Z', '+00:00');
  }

  void _showMessage({
    required String message,
    Color backgroundColor = primaryMaroon,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveFeedbackLocally(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final String key = 'local_help_feedback_$uid';

    final String? oldData = prefs.getString(key);
    final List<dynamic> list = oldData == null ? [] : jsonDecode(oldData);

    list.add(data);

    await prefs.setString(key, jsonEncode(list));
  }

  Future<void> _submitFeedback() async {
    FocusScope.of(context).unfocus();

    final String message = _messageController.text.trim();

    if (message.isEmpty) {
      _showMessage(
        message: 'Please write your message first.',
        backgroundColor: Colors.red,
      );
      return;
    }

    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final User? user = FirebaseAuth.instance.currentUser;

    final Map<String, dynamic> data = {
      'user_uid': user?.uid ?? '',
      'user_phone': user?.phoneNumber ?? '',
      'category': _selectedCategory,
      'message': message,
      'status': 'open',
      'source': 'mobile_app',
      'created_at': _now(),
      'updated_at': _now(),
    };

    try {
      await FirebaseFirestore.instance.collection('app_feedback').add(data);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _messageController.clear();
        _selectedCategory = 'General Help';
      });

      _showMessage(
        message: 'Feedback submitted successfully.',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      await _saveFeedbackLocally(data);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
        _messageController.clear();
      });

      _showMessage(
        message: 'Feedback saved on this device.',
        backgroundColor: Colors.green,
      );
    }
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryMaroon.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.055),
            blurRadius: 10,
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
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackForm() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 24),
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
            'Send Feedback',
            style: TextStyle(
              color: primaryMaroon,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: primaryMaroon,
                  width: 1.5,
                ),
              ),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: _isSubmitting
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedCategory = value;
                    });
                  },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _messageController,
            enabled: !_isSubmitting,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Tell us what happened or how we can improve...',
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: primaryMaroon,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitFeedback,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.2,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white, size: 19),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit Feedback',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
                disabledBackgroundColor: primaryMaroon.withOpacity(0.65),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyNote() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryMaroon.withOpacity(0.16)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: primaryMaroon),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'For urgent medical emergencies, contact the hospital or local emergency service directly. This app helps connect users but does not replace medical advice.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: const Text('Help & Feedback'),
        centerTitle: true,
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            _buildEmergencyNote(),
            _buildInfoCard(
              icon: Icons.person_outline,
              title: 'Complete Your Profile',
              body:
                  'Add your address and blood type so nearby users can find you correctly when they need blood.',
            ),
            _buildInfoCard(
              icon: Icons.bloodtype_outlined,
              title: 'Sending Blood Requests',
              body:
                  'Fill the blood request form with accurate hospital, location, blood group, and case details.',
            ),
            _buildInfoCard(
              icon: Icons.notifications_none,
              title: 'Notifications',
              body:
                  'You will receive notifications when someone sends you a request or accepts your request.',
            ),
            _buildInfoCard(
              icon: Icons.call_outlined,
              title: 'Contact Donors',
              body:
                  'Donor contact details become visible only after the donor accepts your request and gives consent.',
            ),
            _buildFeedbackForm(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}