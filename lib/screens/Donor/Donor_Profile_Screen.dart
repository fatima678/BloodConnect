// lib/screens/profile_tab.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme.dart';
import 'Donor_Edit_profile.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

class DonorProfileTabContent extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const DonorProfileTabContent({
    super.key,
    this.onBackToHome,
  });

  @override
  State<DonorProfileTabContent> createState() => _DonorProfileTabContentState();
}

class _DonorProfileTabContentState extends State<DonorProfileTabContent> {
  bool _isLoading = false;
  String? _errorMessage;

  // Initialized empty to prevent hardcoded flashing values
  String _name = "";
  String _phone = "";
  String _location = "";
  String _bloodGroup = "-";
  String _lastDonated = "";
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _fetchProfileOnStart();
  }

  Future<void> _fetchProfileOnStart() async {
    if (_name.isEmpty) {
      await _fetchProfileSilently();
    }
  }

  void _applyUserData(Map<String, dynamic> user) {
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

  Future<void> _fetchProfileSilently() async {
    try {
      final response = await AuthTokenService.authorizedGet('/profile');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final user = data['data'];
          _applyUserData(user);
          setState(() {
            _errorMessage = null;
          });
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

  Future<void> _refreshProfile() async {
    setState(() => _isLoading = true);
    await _fetchProfileSilently();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryMaroon))
          : _errorMessage != null && _name.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _refreshProfile, child: const Text("Retry")),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(context),
                      _buildStatsCard(),
                      const SizedBox(height: 20),
                      // "No blood requests found for you" layer removed permanently from here.
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
                    MaterialPageRoute(builder: (_) => const DonorEditProfileScreen()),
                  );
                  if (result == true) {
                    _refreshProfile(); 
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
              backgroundImage: _photoUrl != null
                  ? NetworkImage(_photoUrl!)
                  : const AssetImage("assets/profile.jpg"),
              onBackgroundImageError: (_, __) => const Icon(Icons.person, size: 50, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _name.isEmpty ? "Loading..." : _name,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          _buildInfoRow(Icons.location_on, _location.isEmpty ? "Not available" : _location, hasRefresh: true),
          _buildInfoRow(Icons.calendar_month, _lastDonated.isEmpty ? "Not available" : _lastDonated),
          _buildInfoRow(Icons.phone, _phone.isEmpty ? "Not available" : _phone),
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
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(_bloodGroup, "Blood Group"),
              const VerticalDivider(color: Colors.grey, thickness: 1),
              _buildStatItem("0", "Donated times"),
              const VerticalDivider(color: Colors.grey, thickness: 1),
              _buildStatItem("Active", "Status", isStatus: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, {bool isStatus = false}) {
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
}