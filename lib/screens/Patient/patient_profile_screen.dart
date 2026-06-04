// lib/screens/profile_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Cache ke liye import kiya
import '../../theme.dart';
import '../../../routes.dart';
import 'patient_edit_profile.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

class PatientProfileTabContent extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const PatientProfileTabContent({
    super.key,
    this.onBackToHome,
  });

  @override
  State<PatientProfileTabContent> createState() => _PatientProfileTabContentState();
}

class _PatientProfileTabContentState extends State<PatientProfileTabContent> {
  // _isLoading ko permanently false kar diya taaki full-screen loader kabhi trigger na ho
  bool _isLoading = false; 
  String? _errorMessage;

  String _name = "";
  String _phone = "";
  String _location = "";
  String _bloodGroup = "-";
  String _lastDonated = "";
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    // 1. Instantly local storage se purana profile data load karo (0ms Delay)
    _loadCachedProfile().then((_) {
      // 2. Uske baad silently background mein server se fresh data fetch karo
      _fetchProfile();
    });
  }

  // Local storage se profile read karne ka function
  Future<void> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString('cached_patient_profile');
      
      if (cachedData != null) {
        final Map<String, dynamic> user = jsonDecode(cachedData);
        setState(() {
          _name = user['name'] ?? "";
          _phone = user['phone'] ?? "";
          _location = user['location'] ?? "";
          _bloodGroup = user['blood_group'] ?? "-";
          _lastDonated = user['last_donated_date'] != null
              ? "Last Donated: ${user['last_donated_date']}"
              : "Not Donated yet";
          _photoUrl = user['photo_url'];
        });
      }
    } catch (e) {
      debugPrint('Error loading cached profile: $e');
    }
  }

  // Local storage mein profile data write/save karne ka function
  Future<void> _cacheProfile(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_patient_profile', jsonEncode(userData));
    } catch (e) {
      debugPrint('Error caching profile: $e');
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await AuthTokenService.authorizedGet('/profile');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final user = data['data'];

          setState(() {
            _name = user['name'] ?? "";
            _phone = user['phone'] ?? "";
            _location = user['location'] ?? "";
            _bloodGroup = user['blood_group'] ?? "-";
            _lastDonated = user['last_donated_date'] != null
                ? "Last Donated: ${user['last_donated_date']}"
                : "Not Donated yet";
            _photoUrl = user['photo_url'];
            _errorMessage = null;
          });

          // Server se aaye fresh data ko cache memory mein update karlo
          _cacheProfile(user);
        }
      } else {
        if (_name.isEmpty) {
          setState(() => _errorMessage = "Failed to load profile");
        }
      }
    } catch (e) {
      if (_name.isEmpty) {
        setState(() => _errorMessage = "Connection error");
      }
    }
  }

  // Edit profile screen se wapis aane par ye function silently background call chalayega
  Future<void> _silentRefreshProfile() async {
    await _fetchProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // Full-screen _isLoading check ko bypass karke direct ui render kiya hai
      body: _errorMessage != null && _name.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _silentRefreshProfile, 
                      child: const Text("Retry")
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(context),
                  _buildStatsCard(),
                  const SizedBox(height: 20),
                  _buildBloodRequestStatus(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                  if (widget.onBackToHome != null) {
                    widget.onBackToHome!();
                  } else {
                    Navigator.pop(context);
                  }
                },
              ),
              const Text(
                "Your Profile",
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PatientEditProfileScreen()),
                  );
                  if (result == true) {
                    _silentRefreshProfile(); 
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: 47,
              backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                  ? NetworkImage(_photoUrl!)
                  : const AssetImage("assets/profile.jpg") as ImageProvider,
              onBackgroundImageError: (_, __) => const Icon(Icons.person, size: 50, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _name.isEmpty ? "Loading..." : _name,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          _buildInfoRow(Icons.location_on, _location.isEmpty ? "Updating location..." : _location, hasRefresh: true),
          _buildInfoRow(Icons.calendar_month, _lastDonated.isEmpty ? "Checking history..." : _lastDonated),
          _buildInfoRow(Icons.phone, _phone.isEmpty ? "..." : _phone),
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
              onPressed: _silentRefreshProfile,
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
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildThemeStatItem(_bloodGroup, "Blood Group"),
              const VerticalDivider(color: Colors.grey, thickness: 1),
              _buildThemeStatItem("0", "Donated times"),
              const VerticalDivider(color: Colors.grey, thickness: 1),
              _buildThemeStatItem("Active", "Status", isStatus: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeStatItem(String value, String label, {bool isStatus = false}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isStatus ? Colors.green : Colors.brown[800],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildBloodRequestStatus() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.brown.shade800, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Text(
          "No Blood requests found for you",
          style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}