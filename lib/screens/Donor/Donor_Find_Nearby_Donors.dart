// lib/screens/FindNearbyDonorsScreen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

class FindNearbyDonorsScreen extends StatefulWidget {
  static const String routeName = '/find-nearby-donors';

  const FindNearbyDonorsScreen({super.key});

  @override
  State<FindNearbyDonorsScreen> createState() => _FindNearbyDonorsScreenState();
}

class _FindNearbyDonorsScreenState extends State<FindNearbyDonorsScreen> {
  bool _isLoading = false;
  bool _hasLoadedOnce = false;

  String? _selectedBloodGroup = 'All';
  double? _latitude;
  double? _longitude;
  double _radius = 20.0;

  List<Map<String, dynamic>> nearbyDonors = [];

  final List<String> bloodGroups = [
    'All',
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  List<Map<String, dynamic>> get filteredDonors {
    List<Map<String, dynamic>> donors = nearbyDonors;

    if (_selectedBloodGroup != null && _selectedBloodGroup != 'All') {
      donors = donors.where((donor) {
        return donor["blood_group"]?.toString() == _selectedBloodGroup;
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

      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          )
          .timeout(const Duration(seconds: 25));

      if (!mounted) return;

      Map<String, dynamic> responseBody = {};

      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = {};
      }

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
        final errorMessage =
            responseBody["message"] ?? "Failed to fetch nearby donors.";

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

  String _formatDistance(dynamic value) {
    if (value == null) return "N/A";

    final double? distance = double.tryParse(value.toString());

    if (distance == null) return "N/A";

    return "${distance.toStringAsFixed(2)} km";
  }

  String _formatLastDonation(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return "Not provided";
    }

    return value.toString();
  }

  Color _statusColor(String status) {
    final lowerStatus = status.toLowerCase();

    if (lowerStatus == "active" || lowerStatus.contains("available")) {
      return Colors.green;
    }

    return Colors.orange;
  }

  Future<void> _refreshData() async {
    await _fetchNearbyDonors();
  }

  Future<void> _sendRequest(Map<String, dynamic> donor) async {
    final donorRequestId = donor["id"]?.toString();

    if (donorRequestId == null || donorRequestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Donor request ID missing.")),
      );
      return;
    }

    try {
      final response = await AuthTokenService.authorizedPost(
        '/donation-requests',
        {
          'donor_request_id': donorRequestId,
          'message': 'Patient needs blood urgently.',
        },
      );

      if (!mounted) return;

      Map<String, dynamic> responseBody = {};

      try {
        responseBody = jsonDecode(response.body);
      } catch (_) {
        responseBody = {};
      }

      if (response.statusCode == 201 && responseBody['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request sent successfully."),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseBody['message'] ?? "Failed to send request.",
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Find Nearby Donors"),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: DropdownButtonFormField<String>(
              value: _selectedBloodGroup,
              decoration: InputDecoration(
                labelText: "Filter by Blood Group",
                prefixIcon: const Icon(Icons.bloodtype),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                setState(() {
                  _selectedBloodGroup = value ?? 'All';
                });
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      "Radius",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text("${_radius.round()} km"),
                  ],
                ),
                Slider(
                  value: _radius,
                  min: 5,
                  max: 100,
                  divisions: 19,
                  label: "${_radius.round()} km",
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${filteredDonors.length} Donors Nearby",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _isLoading ? null : _refreshData,
                  icon: const Icon(Icons.refresh, size: 20),
                  label: const Text("Refresh"),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : filteredDonors.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search,
                              size: 80,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              "No donors found nearby",
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredDonors.length,
                        itemBuilder: (context, index) {
                          final donor = filteredDonors[index];

                          final name = donor["name"]?.toString() ?? "N/A";
                          final bloodGroup =
                              donor["blood_group"]?.toString() ?? "N/A";
                          final location =
                              donor["current_location"]?.toString() ??
                                  donor["location"]?.toString() ??
                                  "N/A";
                          final distance =
                              _formatDistance(donor["distance_km"]);
                          final lastDonation = _formatLastDonation(
                            donor["last_donated_date"],
                          );
                          final status =
                              donor["status"]?.toString() ?? "N/A";

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor:
                                        primaryMaroon.withOpacity(0.1),
                                    child: Text(
                                      bloodGroup,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6B0000),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "$distance away",
                                          style: const TextStyle(
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Last donated: $lastDonation",
                                          style: const TextStyle(
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          location,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            color: _statusColor(status),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        SizedBox(
                                          height: 38,
                                          child: ElevatedButton(
                                            onPressed: () =>
                                                _sendRequest(donor),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryMaroon,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            child: const Text(
                                              "Send Request",
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

                                  const Icon(
                                    Icons.verified_user,
                                    color: Colors.green,
                                    size: 28,
                                  ),
                                ],
                              ),
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