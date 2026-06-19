import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_donation_app/theme.dart';

class RateUsScreen extends StatefulWidget {
  const RateUsScreen({super.key});

  @override
  State<RateUsScreen> createState() => _RateUsScreenState();
}

class _RateUsScreenState extends State<RateUsScreen> {
  final TextEditingController _reviewController = TextEditingController();

  int _selectedRating = 0;
  bool _isSubmitting = false;

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

  Future<void> _saveRatingLocally(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';

    await prefs.setString(
      'local_app_rating_$uid',
      jsonEncode(data),
    );
  }

  Future<void> _submitRating() async {
    FocusScope.of(context).unfocus();

    if (_selectedRating == 0) {
      _showMessage(
        message: 'Please select a rating first.',
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
      'rating': _selectedRating,
      'review': _reviewController.text.trim(),
      'source': 'mobile_app',
      'created_at': _now(),
      'updated_at': _now(),
    };

    try {
      await FirebaseFirestore.instance.collection('app_ratings').add(data);

      if (!mounted) return;

      _showMessage(
        message: 'Thank you for rating Blood Connect.',
        backgroundColor: Colors.green,
      );

      setState(() {
        _isSubmitting = false;
      });

      Navigator.pop(context);
    } catch (e) {
      await _saveRatingLocally(data);

      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showMessage(
        message: 'Rating saved on this device.',
        backgroundColor: Colors.green,
      );
    }
  }

  Widget _buildStar(int index) {
    final bool selected = index <= _selectedRating;

    return IconButton(
      onPressed: _isSubmitting
          ? null
          : () {
              setState(() {
                _selectedRating = index;
              });
            },
      icon: Icon(
        selected ? Icons.star_rounded : Icons.star_border_rounded,
        color: selected ? Colors.amber : Colors.grey,
        size: 40,
      ),
    );
  }

  Widget _buildRatingText() {
    String text = 'Tap a star to rate us';

    if (_selectedRating == 1) text = 'Poor';
    if (_selectedRating == 2) text = 'Fair';
    if (_selectedRating == 3) text = 'Good';
    if (_selectedRating == 4) text = 'Very Good';
    if (_selectedRating == 5) text = 'Excellent';

    return Text(
      text,
      style: const TextStyle(
        color: primaryMaroon,
        fontSize: 17,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: const Text('Rate Us'),
        centerTitle: true,
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: primaryMaroon.withOpacity(0.10),
                    child: const Icon(
                      Icons.favorite,
                      color: primaryMaroon,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'How was your experience?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your rating helps us improve Blood Connect and make blood donation support better for everyone.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (index) => _buildStar(index + 1),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRatingText(),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _reviewController,
                    enabled: !_isSubmitting,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Write your feedback here...',
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
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryMaroon,
                        disabledBackgroundColor:
                            primaryMaroon.withOpacity(0.65),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.3,
                              ),
                            )
                          : const Text(
                              'Submit Rating',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }
}