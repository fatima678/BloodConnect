// lib/screens/DonorDataScreen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

class DonorDataScreen extends StatefulWidget {
  const DonorDataScreen({super.key});

  @override
  State<DonorDataScreen> createState() => _DonorDataScreenState();
}

class _DonorDataScreenState extends State<DonorDataScreen> {
  bool _isLoading = false;
  bool _hasLoadedOnce = false;

  String? _selectedBloodGroup = 'All';
  double? _latitude;
  double? _longitude;
  double _radius = 20.0;
  String _searchQuery = '';

  List<Map<String, dynamic>> nearbyDonors = [];

  final List<String> bloodGroups = [
    'All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  List<Map<String, dynamic>> get filteredDonors {
    List<Map<String, dynamic>> donors = nearbyDonors;

    // Filter by Blood Group dropdown selection
    if (_selectedBloodGroup != null && _selectedBloodGroup != 'All') {
      donors = donors.where((donor) {
        return donor["blood_group"]?.toString() == _selectedBloodGroup;
      }).toList();
    }

    // Filter by Search text string query matching Name or Location fields
    if (_searchQuery.isNotEmpty) {
      donors = donors.where((donor) {
        final name = donor["name"]?.toString().toLowerCase() ?? '';
        final location = (donor["current_location"] ?? donor["location"])?.toString().toLowerCase() ?? '';
        return name.contains(_searchQuery.toLowerCase()) || location.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return donors;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasLoadedOnce) return;
    _hasLoadedOnce = true;
    _getCurrentLocationAndFetchDonors();
  }

  Future<void> _getCurrentLocationAndFetchDonors() async {
    setState(() => _isLoading = true);

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enable location services.")),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission is required.")),
        );
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      await _fetchNearbyDonors();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get location: $e")),
      );
    }
  }

  Future<void> _fetchNearbyDonors() async {
    if (_latitude == null || _longitude == null) {
      await _getCurrentLocationAndFetchDonors();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse('${AuthTokenService.baseUrl}/nearby-options')
          .replace(
        queryParameters: {
          'lat': _latitude.toString(),
          'lng': _longitude.toString(),
          'radius': _radius.round().toString(),
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ).timeout(const Duration(seconds: 25));

      if (!mounted) return;

      Map<String, dynamic> responseBody = {};
      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200 && responseBody["success"] == true) {
        final dynamic data = responseBody["data"];
        final List donors = data is List
            ? data
            : data is Map && data["donors"] is List
                ? data["donors"]
                : responseBody["donors"] is List
                    ? responseBody["donors"]
                    : [];

        setState(() {
          nearbyDonors = donors
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
        });
      } else {
        final errorMessage = responseBody["message"] ?? "Failed to fetch nearby donors.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatLastDonation(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return "Not provided";
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Donor Directory"), 
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchNearbyDonors,
          )
        ],
      ),
      body: Column(
        children: [
          // Row configuration containing Blood Group dropdown filter and radius slide configuration parameters
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedBloodGroup,
                    decoration: InputDecoration(
                      labelText: "Blood Group",
                      prefixIcon: const Icon(Icons.bloodtype),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: bloodGroups.map((group) => DropdownMenuItem(value: group, child: Text(group))).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBloodGroup = value ?? 'All';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Radius", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text("${_radius.round()} km", style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      Slider(
                        value: _radius,
                        min: 5,
                        max: 100,
                        divisions: 19,
                        activeColor: primaryMaroon,
                        onChanged: (value) {
                          setState(() {
                            _radius = value;
                          });
                        },
                        onChangeEnd: (value) async {
                          await _fetchNearbyDonors();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
              decoration: InputDecoration(
                hintText: "Search donors...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredDonors.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text("No matching donors found nearby", style: TextStyle(fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredDonors.length,
                        itemBuilder: (context, index) {
                          final donor = filteredDonors[index];
                          final name = donor["name"]?.toString() ?? "N/A";
                          final bloodGroup = donor["blood_group"]?.toString() ?? "O+";
                          final location = donor["current_location"]?.toString() ?? donor["location"]?.toString() ?? "N/A";
                          final lastDonation = _formatLastDonation(donor["last_donated_date"]);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: primaryMaroon.withOpacity(0.1), 
                                child: Text(
                                  bloodGroup, 
                                  style: const TextStyle(color: primaryMaroon, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(name),
                              subtitle: Text("$location • Last Donated: $lastDonation"),
                              trailing: const Icon(Icons.phone, color: Colors.green),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}