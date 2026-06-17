// lib/screens/edit_profile_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:blood_donation_app/services/cloudinary_upload_service.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _PlaceSuggestion {
  final String placeId;
  final String description;

  const _PlaceSuggestion({
    required this.placeId,
    required this.description,
  });
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  static const String _googleMapsApiKey = 'AIzaSyCIm0pDpMsEePYylMAZBuZfj8q3cUn3eHc';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedBloodGroup;
  DateTime? _lastDonatedDate;
  bool _isSaving = false;
  bool _isLoadingProfile = true;
  bool _isActive = true;
  bool _isSearchingLocations = false;
  bool _isSelectingLocation = false;

  String? _photoUrl;
  File? _selectedImage;

  double? _latitude;
  double? _longitude;
  String _city = '';
  String _lastConfirmedLocation = '';
  String? _selectedPlaceId;

  Timer? _locationDebounce;
  List<_PlaceSuggestion> _locationSuggestions = [];

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

  String _now() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceFirst('Z', '+00:00');
  }

  String _cacheKey(String uid) {
    return 'cached_patient_profile_$uid';
  }

  void _showMessage({
    required String message,
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

  List<String> _phoneCandidates(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      return [];
    }

    final String rawPhone =
        phoneNumber.trim().replaceAll(' ', '').replaceAll('-', '');

    final Set<String> values = {};

    values.add(rawPhone);

    if (rawPhone.startsWith('+92') && rawPhone.length > 3) {
      values.add('0${rawPhone.substring(3)}');
    }

    if (rawPhone.startsWith('92') && rawPhone.length > 2) {
      values.add('0${rawPhone.substring(2)}');
    }

    if (rawPhone.startsWith('0') && rawPhone.length == 11) {
      values.add('+92${rawPhone.substring(1)}');
    }

    return values.toList();
  }

  Future<DocumentReference<Map<String, dynamic>>?> _resolveUserDoc() async {
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      return null;
    }

    final directRef = _firestore.collection('users').doc(uid);
    final directSnapshot = await directRef.get();

    if (directSnapshot.exists) {
      return directRef;
    }

    final authUidSnapshot = await _firestore
        .collection('users')
        .where('auth_uid', isEqualTo: uid)
        .limit(1)
        .get();

    if (authUidSnapshot.docs.isNotEmpty) {
      final data = Map<String, dynamic>.from(authUidSnapshot.docs.first.data());

      await directRef.set(
        {
          ...data,
          'uid': uid,
          'auth_uid': uid,
          'updated_at': _now(),
        },
        SetOptions(merge: true),
      );

      return directRef;
    }

    final List<String> phoneValues =
        _phoneCandidates(_auth.currentUser?.phoneNumber);

    for (final phone in phoneValues) {
      final phoneSnapshot = await _firestore
          .collection('users')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (phoneSnapshot.docs.isNotEmpty) {
        final data = Map<String, dynamic>.from(phoneSnapshot.docs.first.data());

        await directRef.set(
          {
            ...data,
            'uid': uid,
            'auth_uid': uid,
            'is_phone_verified': true,
            'updated_at': _now(),
          },
          SetOptions(merge: true),
        );

        return directRef;
      }
    }

    await directRef.set(
      {
        'uid': uid,
        'auth_uid': uid,
        'name': _auth.currentUser?.displayName ?? '',
        'email': '',
        'phone': phoneValues.isNotEmpty ? phoneValues.first : '',
        'address': '',
        'location': '',
        'city': '',
        'latitude': null,
        'longitude': null,
        'blood_group': '',
        'blood_type': '',
        'status': 'active',
        'points': 0,
        'is_phone_verified': true,
        'profile_completed': false,
        'is_profile_completed': false,
        'created_at': _now(),
        'updated_at': _now(),
      },
      SetOptions(merge: true),
    );

    return directRef;
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

  double? _readDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is num) {
        return value.toDouble();
      }

      final parsed = double.tryParse(value.toString().trim());

      if (parsed != null) {
        return parsed;
      }
    }

    return null;
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

      final docRef = await _resolveUserDoc();

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
    final String savedLocation = _readString(data, ['address', 'location']);

    _nameController.text = _readString(data, ['name']);
    _emailController.text = _readString(data, ['email']);
    _phoneController.text = _readString(data, ['phone']);
    _addressController.text = savedLocation;
    _lastConfirmedLocation = savedLocation;
    _selectedPlaceId = _readString(data, ['place_id', 'google_place_id']);

    _city = _readString(data, ['city', 'current_city', 'currentCity']);

    _latitude = _readDouble(
      data,
      ['latitude', 'lat', 'current_latitude', 'currentLatitude'],
    );

    _longitude = _readDouble(
      data,
      ['longitude', 'lng', 'current_longitude', 'currentLongitude'],
    );

    final bloodGroup = _readString(
      data,
      ['blood_group', 'bloodType', 'blood_type'],
    );

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

      _showMessage(message: 'Image pick failed: $e');
    }
  }

  void _onLocationChanged(String value) {
    if (_isSelectingLocation) return;

    final String query = value.trim();

    if (query != _lastConfirmedLocation) {
      _selectedPlaceId = null;
      _latitude = null;
      _longitude = null;
      _city = '';
    }

    _locationDebounce?.cancel();

    if (query.length < 3) {
      setState(() {
        _locationSuggestions = [];
        _isSearchingLocations = false;
      });
      return;
    }

    _locationDebounce = Timer(
      const Duration(milliseconds: 450),
      () {
        _searchLocations(query);
      },
    );
  }

  Future<void> _searchLocations(String query) async {
    if (_googleMapsApiKey == 'PASTE_YOUR_GOOGLE_MAPS_API_KEY_HERE') {
      _showMessage(message: 'Please add Google Maps API key.');
      return;
    }

    if (!mounted) return;

    setState(() => _isSearchingLocations = true);

    try {
      final uri = Uri.parse(
        'https://places.googleapis.com/v1/places:autocomplete',
      );

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleMapsApiKey,
          'X-Goog-FieldMask':
              'suggestions.placePrediction.placeId,suggestions.placePrediction.text',
        },
        body: jsonEncode(
          {
            'input': query,
            'includedRegionCodes': ['pk'],
          },
        ),
      );

      if (response.statusCode != 200) {
        debugPrint('Google places autocomplete error: ${response.body}');
        if (!mounted) return;

        setState(() {
          _locationSuggestions = [];
          _isSearchingLocations = false;
        });
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = body['suggestions'];

      final List<_PlaceSuggestion> loadedSuggestions = [];

      if (suggestions is List) {
        for (final item in suggestions) {
          if (item is! Map) continue;

          final prediction = item['placePrediction'];

          if (prediction is! Map) continue;

          final placeId = prediction['placeId']?.toString() ?? '';
          final textData = prediction['text'];

          String description = '';

          if (textData is Map) {
            description = textData['text']?.toString() ?? '';
          }

          if (placeId.isNotEmpty && description.isNotEmpty) {
            loadedSuggestions.add(
              _PlaceSuggestion(
                placeId: placeId,
                description: description,
              ),
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _locationSuggestions = loadedSuggestions;
        _isSearchingLocations = false;
      });
    } catch (e) {
      debugPrint('Search locations error: $e');

      if (!mounted) return;

      setState(() {
        _locationSuggestions = [];
        _isSearchingLocations = false;
      });
    }
  }

  String _cityFromAddressComponents(dynamic components) {
    if (components is! List) return '';

    String administrativeArea = '';

    for (final item in components) {
      if (item is! Map) continue;

      final types = item['types'];
      final longText = item['longText']?.toString() ?? '';

      if (types is! List || longText.trim().isEmpty) continue;

      if (types.contains('locality')) {
        return longText.trim();
      }

      if (types.contains('administrative_area_level_2') &&
          administrativeArea.isEmpty) {
        administrativeArea = longText.trim();
      }

      if (types.contains('administrative_area_level_1') &&
          administrativeArea.isEmpty) {
        administrativeArea = longText.trim();
      }
    }

    return administrativeArea;
  }

  Future<void> _selectLocation(_PlaceSuggestion suggestion) async {
    if (_googleMapsApiKey == 'PASTE_YOUR_GOOGLE_MAPS_API_KEY_HERE') {
      _showMessage(message: 'Please add Google Maps API key.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSelectingLocation = true;
      _isSearchingLocations = true;
    });

    try {
      final uri = Uri.parse(
        'https://places.googleapis.com/v1/places/${suggestion.placeId}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _googleMapsApiKey,
          'X-Goog-FieldMask':
              'id,formattedAddress,location,addressComponents',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('Google place details error: ${response.body}');
        _showMessage(message: 'Failed to select location.');
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      final String formattedAddress =
          body['formattedAddress']?.toString().trim().isNotEmpty == true
              ? body['formattedAddress'].toString().trim()
              : suggestion.description;

      final location = body['location'];

      double? latitude;
      double? longitude;

      if (location is Map) {
        final latValue = location['latitude'];
        final lngValue = location['longitude'];

        if (latValue is num) {
          latitude = latValue.toDouble();
        } else {
          latitude = double.tryParse(latValue?.toString() ?? '');
        }

        if (lngValue is num) {
          longitude = lngValue.toDouble();
        } else {
          longitude = double.tryParse(lngValue?.toString() ?? '');
        }
      }

      if (latitude == null || longitude == null) {
        _showMessage(message: 'Selected location coordinates not found.');
        return;
      }

      final String city = _cityFromAddressComponents(
        body['addressComponents'],
      );

      if (!mounted) return;

      setState(() {
        _selectedPlaceId = suggestion.placeId;
        _latitude = latitude;
        _longitude = longitude;
        _city = city;
        _lastConfirmedLocation = formattedAddress;
        _addressController.text = formattedAddress;
        _locationSuggestions = [];
      });

      _showMessage(
        message: 'Location selected successfully.',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      debugPrint('Select location error: $e');
      _showMessage(message: 'Failed to select location.');
    } finally {
      if (mounted) {
        setState(() {
          _isSelectingLocation = false;
          _isSearchingLocations = false;
        });
      }
    }
  }

  bool _isSelectedGoogleLocationValid() {
    final String address = _addressController.text.trim();

    if (address.isEmpty) {
      return false;
    }

    if (_latitude == null || _longitude == null) {
      return false;
    }

    if (_selectedPlaceId == null || _selectedPlaceId!.trim().isEmpty) {
      return false;
    }

    return address == _lastConfirmedLocation;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isSelectedGoogleLocationValid()) {
      _showMessage(
        message: 'Please select a valid location from Google Maps suggestions.',
      );
      return;
    }

    final uid = _currentUid;
    final docRef = await _resolveUserDoc();

    if (uid == null || uid.isEmpty || docRef == null) {
      _showMessage(message: 'Session not found. Please login again.');
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
      final String bloodType = _selectedBloodGroup ?? '';
      final String address = _addressController.text.trim();

      final profileData = <String, dynamic>{
        'uid': uid,
        'auth_uid': uid,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'phone': _phoneController.text.trim(),
        'address': address,
        'location': address,
        'city': _city,
        'latitude': _latitude,
        'longitude': _longitude,
        'place_id': _selectedPlaceId,
        'google_place_id': _selectedPlaceId,
        'blood_group': bloodType,
        'blood_type': bloodType,
        'last_donated_date': _formatDate(_lastDonatedDate),
        'photo_url': finalPhotoUrl,
        'status': _isActive ? 'active' : 'inactive',
        'profile_completed': true,
        'is_profile_completed': true,
        'is_donor_available': bloodType.isNotEmpty,
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

      _showMessage(
        message: 'Profile saved successfully.',
        backgroundColor: Colors.green,
      );

      Navigator.pop(context, profileData);
    } catch (e) {
      if (!mounted) return;

      _showMessage(message: 'Error: $e');
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

  Widget _buildLocationSuggestions() {
    if (_locationSuggestions.isEmpty && !_isSearchingLocations) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isSearchingLocations
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryMaroon,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('Searching locations...'),
                ],
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _locationSuggestions.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              itemBuilder: (context, index) {
                final suggestion = _locationSuggestions[index];

                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: primaryMaroon,
                  ),
                  title: Text(
                    suggestion.description,
                    style: const TextStyle(fontSize: 14),
                  ),
                  onTap: _isSaving
                      ? null
                      : () {
                          _selectLocation(suggestion);
                        },
                );
              },
            ),
    );
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
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Email address is required'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (value) {
                        final phone = value?.trim() ?? '';

                        if (phone.isEmpty) {
                          return 'Phone number is required';
                        }

                        if (!RegExp(r'^\d{11}$').hasMatch(phone)) {
                          return 'Phone number must be exactly 11 digits';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _addressController,
                      onChanged: _onLocationChanged,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        hintText: 'Search and select your location',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        suffixIcon: _addressController.text.trim().isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _isSaving
                                    ? null
                                    : () {
                                        setState(() {
                                          _addressController.clear();
                                          _selectedPlaceId = null;
                                          _latitude = null;
                                          _longitude = null;
                                          _city = '';
                                          _lastConfirmedLocation = '';
                                          _locationSuggestions = [];
                                        });
                                      },
                              )
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Location is required';
                        }

                        if (!_isSelectedGoogleLocationValid()) {
                          return 'Select location from suggestions';
                        }

                        return null;
                      },
                    ),

                    _buildLocationSuggestions(),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedBloodGroup,
                      decoration: const InputDecoration(
                        labelText: 'Blood Type',
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
                              ? 'Blood type is required'
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
                              Icon(
                                Icons.shield_outlined,
                                color: Colors.grey[700],
                              ),
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
    _locationDebounce?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}