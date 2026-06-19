// lib/screens/profile_tab.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';
import '../screens/edit_profile_screen.dart';

class ProfileTabContent extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const ProfileTabContent({
    super.key,
    this.onBackToHome,
  });

  @override
  State<ProfileTabContent> createState() => _ProfileTabContentState();
}

class _ProfileTabContentState extends State<ProfileTabContent> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isCheckingProfile = true;
  bool _profileMissing = false;
  String? _errorMessage;

  String _name = '';
  String _email = '';
  String _phone = '';
  String _address = '';
  String _bloodGroup = '-';
  String _lastDonated = '';
  String? _photoUrl;
  String _status = 'Active';

  @override
  void initState() {
    super.initState();
    _loadProfileOnStart();
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

  bool _isProfileMade(Map<String, dynamic> user) {
    final name = _readString(user, ['name']);
    final email = _readString(user, ['email']);
    final phone = _readString(user, ['phone']);
    final address = _readString(user, ['address', 'location']);
    final bloodGroup = _readString(
      user,
      ['blood_group', 'bloodType', 'blood_type'],
    );
    final photoUrl = _readString(user, ['photo_url', 'photoUrl']);

    return name.isNotEmpty ||
        email.isNotEmpty ||
        phone.isNotEmpty ||
        address.isNotEmpty ||
        bloodGroup.isNotEmpty ||
        photoUrl.isNotEmpty;
  }

  Future<void> _loadProfileOnStart() async {
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isCheckingProfile = false;
        _profileMissing = true;
        _errorMessage = 'Session not found. Please login again.';
      });

      return;
    }

    final bool cachedProfileLoaded = await _loadCachedProfile(uid);

    if (cachedProfileLoaded && mounted) {
      setState(() {
        _isCheckingProfile = false;
      });
    }

    await _fetchProfileFromFirestore(uid);

    if (mounted) {
      setState(() {
        _isCheckingProfile = false;
      });
    }
  }

  Future<bool> _loadCachedProfile(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_cacheKey(uid));

      if (cachedData == null) {
        return false;
      }

      final user = Map<String, dynamic>.from(jsonDecode(cachedData));

      if (_isProfileMade(user)) {
        _applyProfileData(user);
        return true;
      }

      await _clearCachedProfile(uid);
      return false;
    } catch (e) {
      debugPrint('Load cached profile error: $e');
      return false;
    }
  }

  Future<void> _cacheProfile({
    required String uid,
    required Map<String, dynamic> userData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _cacheKey(uid),
        jsonEncode(userData),
      );

      await prefs.remove('cached_patient_profile');
    } catch (e) {
      debugPrint('Cache profile error: $e');
    }
  }

  Future<void> _clearCachedProfile(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_cacheKey(uid));
      await prefs.remove('cached_patient_profile');
    } catch (e) {
      debugPrint('Clear cached profile error: $e');
    }
  }

  Future<void> _fetchProfileFromFirestore(String uid) async {
    try {
      final docRef = await _resolveUserDoc();

      if (docRef == null) {
        if (!mounted) return;

        setState(() {
          _clearUiData();
          _profileMissing = true;
          _errorMessage = null;
        });

        return;
      }

      final snapshot = await docRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        await _clearCachedProfile(uid);

        if (!mounted) return;

        setState(() {
          _clearUiData();
          _profileMissing = true;
          _errorMessage = null;
        });

        return;
      }

      final user = Map<String, dynamic>.from(snapshot.data()!);
      user['uid'] = user['uid'] ?? uid;

      if (!_isProfileMade(user)) {
        await _clearCachedProfile(uid);

        if (!mounted) return;

        setState(() {
          _clearUiData();
          _profileMissing = true;
          _errorMessage = null;
        });

        return;
      }

      _applyProfileData(user);

      await _cacheProfile(
        uid: uid,
        userData: user,
      );
    } catch (e) {
      debugPrint('Fetch profile error: $e');

      if (!mounted) return;

      if (_name.isEmpty) {
        setState(() {
          _errorMessage = 'Failed to load profile.';
          _profileMissing = false;
        });
      }
    }
  }

  void _clearUiData() {
    _name = '';
    _email = '';
    _phone = '';
    _address = '';
    _bloodGroup = '-';
    _lastDonated = '';
    _photoUrl = null;
    _status = 'Active';
  }

  void _applyProfileData(Map<String, dynamic> user) {
    final bloodGroup = _readString(
      user,
      ['blood_group', 'bloodType', 'blood_type'],
    );
    final lastDonatedDate = _readString(
      user,
      ['last_donated_date', 'lastDonatedDate'],
    );
    final status = _readString(user, ['status']);

    setState(() {
      _name = _readString(user, ['name']);
      _email = _readString(user, ['email']);
      _phone = _readString(user, ['phone']);
      _address = _readString(user, ['address', 'location']);
      _bloodGroup = bloodGroup.isNotEmpty ? bloodGroup : '-';
      _lastDonated = lastDonatedDate.isNotEmpty
          ? 'Last Donated: $lastDonatedDate'
          : 'Not Donated yet';
      _photoUrl = _readString(user, ['photo_url', 'photoUrl']);
      _status = status.toLowerCase() == 'inactive' ? 'Inactive' : 'Active';
      _profileMissing = false;
      _errorMessage = null;
    });
  }

  Future<void> _refreshProfile() async {
    final uid = _currentUid;

    if (uid == null || uid.isEmpty) return;

    setState(() {
      _isCheckingProfile = true;
    });

    await _fetchProfileFromFirestore(uid);

    if (mounted) {
      setState(() {
        _isCheckingProfile = false;
      });
    }
  }

  Future<void> _openProfileEditor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditProfileScreen(),
      ),
    );

    if (result is Map<String, dynamic>) {
      final uid = _currentUid;

      if (uid != null && uid.isNotEmpty) {
        await _cacheProfile(
          uid: uid,
          userData: result,
        );
      }

      _applyProfileData(result);
      return;
    }

    await _refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isCheckingProfile && _name.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: primaryMaroon),
            )
          : _errorMessage != null && _name.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryMaroon,
                          ),
                          child: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _profileMissing
                  ? _buildProfileMissingView(context)
                  : RefreshIndicator(
                      onRefresh: _refreshProfile,
                      color: primaryMaroon,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildHeader(context),
                            _buildStatsCard(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _buildProfileMissingView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primaryMaroon.withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 72,
                color: Colors.brown[800],
              ),
              const SizedBox(height: 16),
              const Text(
                'Create your profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryMaroon,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your profile is not created yet. Click the button below to add your profile details.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _openProfileEditor,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Create Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  Widget _buildHeader(BuildContext context) {
    final bool hasPhoto = _photoUrl != null && _photoUrl!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 34, bottom: 28, left: 20, right: 20),
      decoration: const BoxDecoration(
        color: primaryMaroon,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 48,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (widget.onBackToHome != null) {
                      widget.onBackToHome!();
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: _openProfileEditor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CircleAvatar(
            radius: 43,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[200],
              backgroundImage: hasPhoto ? NetworkImage(_photoUrl!) : null,
              child: hasPhoto
                  ? null
                  : Icon(
                      Icons.person,
                      size: 42,
                      color: Colors.grey[500],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _name.isEmpty ? 'User' : _name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _buildInfoRow(
            Icons.location_on_outlined,
            _address.isEmpty ? 'Location not available' : _address,
            hasRefresh: true,
          ),
          _buildInfoRow(
            Icons.email_outlined,
            _email.isEmpty ? 'Email not available' : _email,
          ),
          _buildInfoRow(
            Icons.calendar_month,
            _lastDonated.isEmpty ? 'Not Donated yet' : _lastDonated,
          ),
          _buildInfoRow(
            Icons.phone,
            _phone.isEmpty ? 'Phone not available' : _phone,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {bool hasRefresh = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 30),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 13.5),
            ),
          ),
          if (hasRefresh)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
              onPressed: _refreshProfile,
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildThemeStatItem(_bloodGroup, 'Blood Type'),
              const VerticalDivider(color: Colors.grey, thickness: 1),
              _buildThemeStatItem('0', 'Donated times'),
              const VerticalDivider(color: Colors.grey, thickness: 1),
              _buildThemeStatItem(
                _status,
                'Status',
                isStatus: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeStatItem(
    String value,
    String label, {
    bool isStatus = false,
  }) {
    final bool inactive = value.toLowerCase() == 'inactive';

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isStatus
                ? inactive
                    ? Colors.red
                    : Colors.green
                : Colors.brown[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}