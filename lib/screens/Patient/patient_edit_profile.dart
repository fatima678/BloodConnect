// lib/screens/edit_profile_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

class PatientEditProfileScreen extends StatefulWidget {
  const PatientEditProfileScreen({super.key});

  @override
  State<PatientEditProfileScreen> createState() => _PatientEditProfileScreenState();
}

class _PatientEditProfileScreenState extends State<PatientEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String? _selectedBloodGroup;
  DateTime? _lastDonatedDate;
  bool _isSaving = false;
  
  // Status variable for toggle state tracking
  bool _isActive = true;

  final List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  void _loadCurrentProfile() {
    final cachedUser = AuthTokenService.getUser();
    if (cachedUser != null) {
      setState(() {
        _nameController.text = cachedUser['name'] ?? "";
        _phoneController.text = cachedUser['phone'] ?? "";
        _locationController.text = cachedUser['location'] ?? "";
        _selectedBloodGroup = cachedUser['blood_group'];
        if (cachedUser['last_donated_date'] != null) {
          try {
            _lastDonatedDate = DateTime.parse(cachedUser['last_donated_date']);
          } catch (_) {}
        }
      });
    }
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return "$year-$month-$day";
  }

  Future<void> _selectLastDonatedDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastDonatedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _lastDonatedDate = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final response = await AuthTokenService.authorizedPut(
        '/profile',
        {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'location': _locationController.text.trim(),
          'blood_group': _selectedBloodGroup,
          'last_donated_date': _formatDate(_lastDonatedDate),
          // Ready to pass to backend once your endpoint is modified to accept user updates
          // 'status': _isActive ? 'active' : 'inactive', 
        },
      );

      if (!mounted) return;

      Map<String, dynamic> responseBody = {};

      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = {};
      }

      if (response.statusCode == 200 && responseBody['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully.'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseBody['message'] ?? 'Failed to update profile.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 10),
              
              // Profile Image Upload Container Interface Frame
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: Colors.grey[200],
                      child: Icon(Icons.person, size: 65, color: Colors.grey[500]),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: primaryMaroon,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Profile picture uploading will be enabled with backend storage support.")),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Name is required'
                        : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Phone number is required'
                        : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedBloodGroup,
                decoration: const InputDecoration(
                  labelText: 'Blood Group',
                  prefixIcon: Icon(Icons.bloodtype),
                  border: OutlineInputBorder(),
                ),
                items: bloodGroups
                    .map(
                      (group) => DropdownMenuItem(
                        value: group,
                        child: Text(group),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedBloodGroup = value);
                },
              ),
              const SizedBox(height: 16),

              InkWell(
                onTap: _selectLastDonatedDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Last Donated Date',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _lastDonatedDate == null
                        ? 'Select Last Donated Date'
                        : '${_lastDonatedDate!.day}/${_lastDonatedDate!.month}/${_lastDonatedDate!.year}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Status Toggle Button Layer Container Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: Colors.grey[700]),
                        const SizedBox(width: 12),
                        Text(
                          "User Status: ${_isActive ? 'Active' : 'Inactive'}",
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isActive,
                      activeColor: primaryMaroon,
                      onChanged: (value) {
                        setState(() {
                          _isActive = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Save Profile',
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
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}