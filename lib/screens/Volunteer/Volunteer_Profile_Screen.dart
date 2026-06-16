// lib/screens/Volunteer/Volunteer_Profile_Screen.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_donation_app/theme.dart';
import 'Volunteer_Edit_Profile.dart';

class VolunteerProfileScreen extends StatefulWidget {
  const VolunteerProfileScreen({super.key});

  @override
  State<VolunteerProfileScreen> createState() => _VolunteerProfileScreenState();
}

class _VolunteerProfileScreenState extends State<VolunteerProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isCheckingProfile = true;
  bool _profileMissing = false;
  String? _errorMessage;

  String _name = '';
  String _phone = '';
  String _location = '';
  String _bloodGroup = '-';
  String _volunteerId = '';
  String _memberSince = '';
  String _createdAtRaw = '';
  String _status = 'Verified';
  String? _photoUrl;

  int _requestsHandled = 0;
  int _certificatesIssued = 0;

  @override
  void initState() {
    super.initState();
    _loadProfileOnStart();
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

  String _cacheKey(String uid) {
    return 'cached_volunteer_profile_$uid';
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

  Map<String, dynamic> _sanitizeForCache(Map<String, dynamic> data) {
    final sanitized = <String, dynamic>{};

    data.forEach((key, value) {
      if (value is Timestamp) {
        sanitized[key] = value.toDate().toIso8601String();
      } else {
        sanitized[key] = value;
      }
    });

    return sanitized;
  }

  bool _isProfileMade(Map<String, dynamic> user) {
    final dynamic profileCompleted =
        user['profile_completed'] ?? user['is_profile_completed'];

    if (profileCompleted == true) {
      return true;
    }

    final name = _readString(user, ['name', 'full_name']);
    final phone = _readString(user, ['phone', 'phone_number']);
    final location = _readString(user, ['location', 'address', 'city']);

    return name.isNotEmpty && phone.isNotEmpty && location.isNotEmpty;
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

      if (cachedData == null || cachedData.trim().isEmpty) {
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
      debugPrint('Load cached volunteer profile error: $e');
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
        jsonEncode(_sanitizeForCache(userData)),
      );

      await prefs.remove('cached_volunteer_profile');
    } catch (e) {
      debugPrint('Cache volunteer profile error: $e');
    }
  }

  Future<void> _clearCachedProfile(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_cacheKey(uid));
      await prefs.remove('cached_volunteer_profile');
    } catch (e) {
      debugPrint('Clear volunteer profile cache error: $e');
    }
  }

  Future<void> _fetchProfileFromFirestore(String uid) async {
    final docRef = _volunteerDoc;

    if (docRef == null) {
      if (!mounted) return;

      setState(() {
        _clearUiData();
        _profileMissing = true;
        _errorMessage = null;
      });

      return;
    }

    try {
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
      debugPrint('Fetch volunteer profile error: $e');

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
    _phone = '';
    _location = '';
    _bloodGroup = '-';
    _volunteerId = '';
    _memberSince = '';
    _createdAtRaw = '';
    _status = 'Verified';
    _photoUrl = null;
    _requestsHandled = 0;
    _certificatesIssued = 0;
  }

  void _applyProfileData(Map<String, dynamic> user) {
    final bloodGroup = _readString(
      user,
      ['preferred_blood_group', 'blood_group', 'bloodGroup'],
    );

    final status = _readString(user, ['status']);
    final createdAt = _readString(user, ['created_at', 'createdAt']);

    setState(() {
      _name = _readString(user, ['name', 'full_name']);
      _phone = _readString(user, ['phone', 'phone_number']);
      _location = _readString(user, ['location', 'address', 'city']);
      _bloodGroup = bloodGroup.isNotEmpty ? bloodGroup : '-';
      _volunteerId = _readString(user, ['volunteer_id', 'volunteerId']);
      _createdAtRaw = createdAt;
      _memberSince = _formatMemberSince(createdAt);
      _status = status.isNotEmpty ? status : 'Verified';
      _photoUrl = _readString(
        user,
        ['photo_url', 'photoUrl', 'profile_image', 'profileImage'],
      );
      _requestsHandled = _readInt(user, ['requests_handled', 'requestsHandled']);
      _certificatesIssued =
          _readInt(user, ['certificates_issued', 'certificatesIssued']);
      _profileMissing = false;
      _errorMessage = null;
    });
  }

  String _formatMemberSince(String value) {
    if (value.trim().isEmpty) return 'Not available';

    try {
      final date = DateTime.parse(value).toLocal();

      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      return '${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return value;
    }
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

  Map<String, dynamic> _currentProfileMap() {
    return {
      'uid': _currentUid,
      'role': 'team_volunteer',
      'name': _name,
      'phone': _phone,
      'location': _location,
      'preferred_blood_group': _bloodGroup == '-' ? '' : _bloodGroup,
      'blood_group': _bloodGroup == '-' ? '' : _bloodGroup,
      'volunteer_id': _volunteerId,
      'status': _status,
      'photo_url': _photoUrl ?? '',
      'photoUrl': _photoUrl ?? '',
      'requests_handled': _requestsHandled,
      'certificates_issued': _certificatesIssued,
      'created_at': _createdAtRaw,
      'profile_completed': true,
      'is_profile_completed': true,
    };
  }

  Future<void> _openProfileEditor() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerEditProfileScreen(
          initialData: _profileMissing ? null : _currentProfileMap(),
        ),
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
              ? _buildErrorView()
              : _profileMissing
                  ? _buildProfileMissingView()
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildHeader(context),
                          _buildStatsCard(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildErrorView() {
    return Center(
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
    );
  }

  Widget _buildProfileMissingView() {
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
                'Your volunteer profile is not created yet. Click the button below to add your profile details.',
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
      padding: const EdgeInsets.only(top: 50, bottom: 40, left: 20, right: 20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
              const Text(
                'Your Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: _openProfileEditor,
              ),
            ],
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 47,
              backgroundColor: Colors.grey[200],
              backgroundImage: hasPhoto ? NetworkImage(_photoUrl!) : null,
              child: hasPhoto
                  ? null
                  : Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.grey[500],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _name.isEmpty ? 'Volunteer' : _name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),
          _buildInfoRow(
            Icons.location_on,
            _location.isEmpty ? 'Not available' : _location,
            hasRefresh: true,
          ),
          _buildInfoRow(
            Icons.badge,
            _volunteerId.isEmpty ? 'Not available' : 'Volunteer ID: $_volunteerId',
          ),
          _buildInfoRow(
            Icons.phone,
            _phone.isEmpty ? 'Not available' : _phone,
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
              style: const TextStyle(color: Colors.white, fontSize: 14),
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
              _buildStatItem(_bloodGroup, 'Blood Group'),
              const VerticalDivider(color: Colors.grey, thickness: 1),
              _buildStatItem(_requestsHandled.toString(), 'Requests'),
              const VerticalDivider(color: Colors.grey, thickness: 1),
              _buildStatItem(
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

  Widget _buildStatItem(
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
            fontSize: 18,
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
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}