// lib/screens/blood_request_nearby.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme.dart'; 
import 'package:blood_donation_app/services/auth_token_service.dart';

class PublicRequestsNearby extends StatefulWidget {
  static const String routeName = '/public_requests';

  const PublicRequestsNearby({super.key});

  @override
  State<PublicRequestsNearby> createState() => _PublicRequestsNearbyState();
}

class _PublicRequestsNearbyState extends State<PublicRequestsNearby> {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPublicRequests();
  }

  Future<void> _fetchPublicRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Utilizing authorized get method connected to the target API endpoint path
      final response = await AuthTokenService.authorizedGet('/app-get-blood-requests');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _requests = data['data'];
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? "Failed to load public requests.";
          });
        }
      } else {
        setState(() {
          _errorMessage = "Server error occurred: status code ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection failure: Unable to fetch blood requests.";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Blood Requests Nearby",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryMaroon, 
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryMaroon,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchPublicRequests,
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text("Retry", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
                        )
                      ],
                    ),
                  ),
                )
              : _requests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bloodtype_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            "No active public blood requests found nearby",
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchPublicRequests,
                      color: primaryMaroon,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          final request = _requests[index];

                          // Safely resolve nested fields matching payload data dictionary properties
                          final String name = request["name"] ?? request["patient_name"] ?? "URGENT PATIENT";
                          final String bloodGroup = request["blood_group"] ?? request["bloodGroup"] ?? "Any Group";
                          final String units = request["units"] != null ? "${request["units"]} Pint(s)" : "1 Pint";
                          final String details = request["request_type"] ?? "Fresh Blood";
                          final String location = request["location"] ?? request["hospital_name"] ?? "Nearby Hospital";
                          final String phone = request["phone"] ?? request["contact_number"] ?? "03000000000";

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name.toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          "$bloodGroup, $units, $details",
                                          style: const TextStyle(
                                            color: primaryMaroon, 
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    location,
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone, color: Colors.green, size: 20),
                                      const SizedBox(width: 8),
                                      Text(phone),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text("Calling $phone..."),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryMaroon, 
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 22),
                                        ),
                                        child: const Text("ACCEPT"),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text("Rejecting request..."),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[400],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 24),
                                        ),
                                        child: const Text("Reject"),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}