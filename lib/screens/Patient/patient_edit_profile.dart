// lib/screens/patient_edit_profile.dart

import 'dart:convert';
import 'dart:io';

import 'package:blood_donation_app/services/cloudinary_upload_service.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PatientEditProfileScreen extends StatefulWidget {
  const PatientEditProfileScreen({super.key});

  @override
  State<PatientEditProfileScreen> createState() =>
      _PatientEditProfileScreenState();
}

class _PatientEditProfileScreenState extends State<PatientEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedBloodGroup;
  DateTime? _lastDonatedDate;
  bool _isSaving = false;
  bool _isLoadingProfile = true;
  bool _isActive = true;

  String? _photoUrl;
  File? _selectedImage;

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

  String? get _currentUid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _patientDoc {
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return _firestore
        .collection('users')
        .doc('roles')
        .collection('patients')
        .doc(uid);
  }

  String _cacheKey(String uid) {
    return 'cached_patient_profile_$uid';
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  DateTime? _readDate(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString());
  }

  Future<void> _loadCurrentProfile() async {
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      if (!mounted) return;

      setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey(uid));

      if (cachedData != null) {
        final cachedUser = Map<String, dynamic>.from(jsonDecode(cachedData));
        _applyDataToFields(cachedUser);
      }

      final docRef = _patientDoc;

      if (docRef != null) {
        final snapshot = await docRef.get();

        if (snapshot.exists && snapshot.data() != null) {
          final data = Map<String, dynamic>.from(snapshot.data()!);
          data['uid'] = data['uid'] ?? uid;

          _applyDataToFields(data);
        }
      }
    } catch (e) {
      debugPrint('Load patient profile error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  void _applyDataToFields(Map<String, dynamic> data) {
    _nameController.text = _readString(data, ['name']);
    _phoneController.text = _readString(data, ['phone']);
    _locationController.text = _readString(data, ['location', 'address']);

    final bloodGroup = _readString(data, ['blood_group', 'bloodGroup']);

    _selectedBloodGroup = bloodGroup.isNotEmpty ? bloodGroup : null;

    final lastDonatedDate = _readDate(
      data['last_donated_date'] ?? data['lastDonatedDate'],
    );

    if (lastDonatedDate != null) {
      _lastDonatedDate = lastDonatedDate;
    }

    _photoUrl = _readString(data, ['photo_url', 'photoUrl']);

    final status = _readString(data, ['status']);

    if (status.isNotEmpty) {
      _isActive = status.toLowerCase() != 'inactive';
    }
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  Future<void> _cacheProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _cacheKey(uid),
      jsonEncode(data),
    );

    await prefs.remove('cached_patient_profile');
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

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();

      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (picked == null) return;

      setState(() {
        _selectedImage = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image pick failed: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = _currentUid;
    final docRef = _patientDoc;

    if (uid == null || uid.isEmpty || docRef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session not found. Please login again.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? finalPhotoUrl = _photoUrl;

      if (_selectedImage != null) {
        finalPhotoUrl = await CloudinaryUploadService.uploadProfileImage(
          imageFile: _selectedImage!,
          uid: uid,
        );
      }

      final now = DateTime.now().toIso8601String();

      final profileData = <String, dynamic>{
        'uid': uid,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'blood_group': _selectedBloodGroup,
        'last_donated_date': _formatDate(_lastDonatedDate),
        'photo_url': finalPhotoUrl,
        'status': _isActive ? 'active' : 'inactive',
        'profile_completed': true,
        'is_profile_completed': true,
        'updated_at': now,
      };

      await docRef.set(
        profileData,
        SetOptions(merge: true),
      );

      await _cacheProfile(
        uid: uid,
        data: profileData,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, profileData);
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

  ImageProvider? _profileImageProvider() {
    if (_selectedImage != null) {
      return FileImage(_selectedImage!);
    }

    if (_photoUrl != null && _photoUrl!.trim().isNotEmpty) {
      return NetworkImage(_photoUrl!);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _profileImageProvider();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingProfile
          ? const Center(
              child: CircularProgressIndicator(color: primaryMaroon),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: imageProvider,
                            child: imageProvider == null
                                ? Icon(
                                    Icons.person,
                                    size: 65,
                                    color: Colors.grey[500],
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: primaryMaroon,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(
                                  Icons.camera_alt,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                onPressed: _isSaving ? null : _pickImage,
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
                      validator: (value) => value == null || value.trim().isEmpty
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
                      validator: (value) => value == null || value.trim().isEmpty
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
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Location is required'
                          : null,
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
                      onChanged: _isSaving
                          ? null
                          : (value) {
                              setState(() => _selectedBloodGroup = value);
                            },
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Blood group is required'
                              : null,
                    ),

                    const SizedBox(height: 16),

                    InkWell(
                      onTap: _isSaving ? null : _selectLastDonatedDate,
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

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.shield_outlined,
                                  color: Colors.grey[700]),
                              const SizedBox(width: 12),
                              Text(
                                'User Status: ${_isActive ? 'Active' : 'Inactive'}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isActive,
                            activeColor: primaryMaroon,
                            onChanged: _isSaving
                                ? null
                                : (value) {
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
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
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