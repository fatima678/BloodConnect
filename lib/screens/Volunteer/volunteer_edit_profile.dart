// lib/screens/Volunteer/Volunteer_Edit_Profile.dart

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:blood_donation_app/theme.dart';

class VolunteerEditProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const VolunteerEditProfileScreen({
    super.key,
    this.initialData,
  });

  @override
  State<VolunteerEditProfileScreen> createState() =>
      _VolunteerEditProfileScreenState();
}

class _VolunteerEditProfileScreenState
    extends State<VolunteerEditProfileScreen> {
  static const String _cloudinaryCloudName = 'dckvdiawp';

  // IMPORTANT:
  // Yahan apna exact Cloudinary UNSIGNED upload preset name rakho.
  static const String _cloudinaryUploadPreset = 'blood_connect_unsigned';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();

  bool _isSavingProfile = false;
  bool _isUploadingImage = false;

  File? _selectedImageFile;
  String? _photoUrl;

  String _volunteerId = '';
  String _createdAtRaw = '';
  String _status = 'Verified';
  int _requestsHandled = 0;
  int _certificatesIssued = 0;

  @override
  void initState() {
    super.initState();
    _fillInitialData();
  }

  String? get _currentUid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _volunteerDoc {
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      return null;
    }

    return _firestore
        .collection('users')
        .doc('roles')
        .collection('team_volunteers')
        .doc(uid);
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is Timestamp) {
        return value.toDate().toIso8601String();
      }

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  int _readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is int) return value;
      if (value is num) return value.toInt();

      final parsed = int.tryParse(value.toString());

      if (parsed != null) return parsed;
    }

    return 0;
  }

  void _fillInitialData() {
    final data = widget.initialData ?? <String, dynamic>{};

    final bloodGroup = _readString(
      data,
      ['preferred_blood_group', 'blood_group', 'bloodGroup'],
    );

    _nameController.text = _readString(data, ['name', 'full_name']);
    _phoneController.text = _readString(data, ['phone', 'phone_number']);

    if (_phoneController.text.trim().isEmpty) {
      _phoneController.text = _auth.currentUser?.phoneNumber ?? '';
    }

    _locationController.text = _readString(
      data,
      ['location', 'address', 'city'],
    );

    _bloodGroupController.text = bloodGroup == '-' ? '' : bloodGroup;

    _volunteerId = _readString(data, ['volunteer_id', 'volunteerId']);
    _createdAtRaw = _readString(data, ['created_at', 'createdAt']);
    _status = _readString(data, ['status']).isNotEmpty
        ? _readString(data, ['status'])
        : 'Verified';

    _photoUrl = _readString(
      data,
      ['photo_url', 'photoUrl', 'profile_image', 'profileImage'],
    );

    _requestsHandled = _readInt(data, ['requests_handled', 'requestsHandled']);
    _certificatesIssued =
        _readInt(data, ['certificates_issued', 'certificatesIssued']);
  }

  ImageProvider? _profileImageProvider() {
    if (_selectedImageFile != null) {
      return FileImage(_selectedImageFile!);
    }

    if (_photoUrl != null && _photoUrl!.trim().isNotEmpty) {
      return NetworkImage(_photoUrl!);
    }

    return null;
  }

  void _showImageSourceSheet() {
    if (_isSavingProfile || _isUploadingImage) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library, color: primaryMaroon),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickProfileImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: primaryMaroon),
                  title: const Text('Take Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickProfileImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 900,
        maxHeight: 900,
      );

      if (pickedImage == null) return;

      if (!mounted) return;

      setState(() {
        _selectedImageFile = File(pickedImage.path);
      });
    } catch (e) {
      debugPrint('Pick volunteer profile image error: $e');
      _showSnackBar('Failed to pick image. Please try again.');
    }
  }

  Future<String> _uploadImageToCloudinary(File imageFile) async {
    if (_cloudinaryUploadPreset.trim().isEmpty ||
        _cloudinaryUploadPreset == 'YOUR_UNSIGNED_UPLOAD_PRESET') {
      throw Exception(
        'Cloudinary upload preset missing. Please add your unsigned upload preset name in code.',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri);

    request.fields['upload_preset'] = _cloudinaryUploadPreset;

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200 && response.statusCode != 201) {
      debugPrint('Cloudinary volunteer upload failed: $responseBody');

      String cloudinaryMessage = 'Cloudinary image upload failed.';

      try {
        final decoded = jsonDecode(responseBody);

        if (decoded is Map &&
            decoded['error'] is Map &&
            decoded['error']['message'] != null) {
          cloudinaryMessage = decoded['error']['message'].toString();
        }
      } catch (_) {}

      throw Exception(cloudinaryMessage);
    }

    final decoded = jsonDecode(responseBody);

    final secureUrl = decoded['secure_url']?.toString() ?? '';

    if (secureUrl.trim().isEmpty) {
      throw Exception('Cloudinary secure URL not received.');
    }

    return secureUrl;
  }

  Future<void> _saveProfile() async {
    final uid = _currentUid;
    final docRef = _volunteerDoc;

    if (uid == null || uid.isEmpty || docRef == null) {
      _showSnackBar('Session not found. Please login again.');
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final location = _locationController.text.trim();
    final bloodGroup = _bloodGroupController.text.trim();

    if (name.isEmpty || phone.isEmpty || location.isEmpty) {
      _showSnackBar('Please fill name, phone and location.');
      return;
    }

    setState(() {
      _isSavingProfile = true;
      _isUploadingImage = _selectedImageFile != null;
    });

    try {
      String finalPhotoUrl = _photoUrl ?? '';

      if (_selectedImageFile != null) {
        finalPhotoUrl = await _uploadImageToCloudinary(_selectedImageFile!);
      }

      final now = DateTime.now().toUtc().toIso8601String();

      final generatedVolunteerId = _volunteerId.isNotEmpty
          ? _volunteerId
          : 'VOL-${uid.substring(0, 6).toUpperCase()}';

      final createdAt = _createdAtRaw.trim().isNotEmpty ? _createdAtRaw : now;

      final userData = <String, dynamic>{
        'uid': uid,
        'role': 'team_volunteer',
        'name': name,
        'phone': phone,
        'location': location,
        'preferred_blood_group': bloodGroup,
        'blood_group': bloodGroup,
        'volunteer_id': generatedVolunteerId,
        'status': _status.isNotEmpty ? _status : 'Verified',
        'requests_handled': _requestsHandled,
        'certificates_issued': _certificatesIssued,
        'photo_url': finalPhotoUrl,
        'photoUrl': finalPhotoUrl,
        'profile_completed': true,
        'is_profile_completed': true,
        'created_at': createdAt,
        'updated_at': now,
      };

      await docRef.set(userData, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pop(context, userData);
    } catch (e) {
      debugPrint('Save volunteer profile error: $e');

      final String errorText = e
          .toString()
          .replaceFirst('Exception:', '')
          .trim();

      _showSnackBar(
        errorText.isNotEmpty
            ? errorText
            : 'Failed to save profile. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
          _isUploadingImage = false;
        });
      }
    }
  }

  void _showSnackBar(
    String message, {
    Color backgroundColor = Colors.red,
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

  Widget _buildProfileImagePicker() {
    final imageProvider = _profileImageProvider();

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 55,
              backgroundColor: primaryMaroon.withOpacity(0.12),
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? const Icon(
                      Icons.person,
                      size: 58,
                      color: primaryMaroon,
                    )
                  : null,
            ),
            InkWell(
              onTap: _showImageSourceSheet,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: primaryMaroon,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
            if (_isUploadingImage)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap camera icon to add profile picture',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: !_isSavingProfile,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: primaryMaroon),
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryMaroon, width: 1.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialData != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Profile' : 'Create Profile'),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                top: 28,
                bottom: 28,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: primaryMaroon,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: _buildProfileImagePicker(),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _buildInputField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                  _buildInputField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 14),
                  _buildInputField(
                    controller: _locationController,
                    label: 'Location',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildInputField(
                    controller: _bloodGroupController,
                    label: 'Preferred Blood Group',
                    icon: Icons.bloodtype,
                    hint: 'Example: O+',
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSavingProfile ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryMaroon,
                        disabledBackgroundColor:
                            primaryMaroon.withOpacity(0.65),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSavingProfile
                          ? const SizedBox(
                              width: 23,
                              height: 23,
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
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bloodGroupController.dispose();
    super.dispose();
  }
}