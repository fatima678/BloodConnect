// lib/screens/BloodRequestManagementScreen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

class BloodRequestManagementScreen extends StatefulWidget {
  const BloodRequestManagementScreen({super.key});

  @override
  State<BloodRequestManagementScreen> createState() => _BloodRequestManagementScreenState();
}

class _BloodRequestManagementScreenState extends State<BloodRequestManagementScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetching requests via AuthTokenService targeting the requested donor-requests endpoint
      final response = await AuthTokenService.authorizedGet('/admin/donor-requests');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            _requests = data['data'];
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? "Failed to load management records.";
          });
        }
      } else {
        setState(() {
          _errorMessage = "Server error occurred: status code ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection error: Unable to reach the server dashboard.";
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
          "Blood Request Management",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryMaroon,
        iconTheme: const IconThemeData(color: Colors.white),
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
                          onPressed: _loadRequests,
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
                          Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Text(
                            "No blood requests available to manage",
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      color: primaryMaroon,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _requests.length,
                        itemBuilder: (context, index) {
                          final request = _requests[index];

                          // Safely mapping database parameters with fallback default parameters
                          final String bloodGroup = request["blood_group"] ?? request["bloodGroup"] ?? "Unknown";
                          final String units = request["units"] != null ? "${request["units"]} Unit(s)" : "1 Unit";
                          final String location = request["location"] ?? request["hospital_name"] ?? "Not Specified";
                          final String name = request["name"] ?? request["patient_name"] ?? "Urgent Request";

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: const CircleAvatar(
                                backgroundColor: Color(0xFFFFF1F1),
                                child: Icon(Icons.bloodtype, color: primaryMaroon),
                              ),
                              title: Text(
                                "$bloodGroup Required - $units",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  "$name • $location",
                                  style: TextStyle(color: Colors.grey[700]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green, size: 26),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Request verified and approved.")),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red, size: 26),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text("Request rejected/archived.")),
                                      );
                                    },
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