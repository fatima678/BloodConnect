// lib/screens/blood_bank_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme.dart';
import 'patient_blood_bank_map_screen.dart';

class PatientBloodBankScreen extends StatefulWidget {
  static const String routeName = '/blood_bank';

  final double? lat;
  final double? lng;
  final String? requestId;

  const PatientBloodBankScreen({
    super.key,
    this.lat,
    this.lng,
    this.requestId,
  });

  @override
  State<PatientBloodBankScreen> createState() => _PatientBloodBankScreenState();
}

class _PatientBloodBankScreenState extends State<PatientBloodBankScreen> {
  List<dynamic> bloodBanks = [];
  bool isLoading = true;
  String errorMessage = '';

  // Aapki ngrok URL
  final String apiUrl =
      "https://manliness-smugness-qualm.ngrok-free.dev/api/blood-banks";

  @override
  void initState() {
    super.initState();
    fetchBloodBanks();
  }

  Future<void> fetchBloodBanks() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      // BACKUP LOGIC: Agar widget se lat/lng null aa rhi hain, to default coordinates use hongey
      // Taake backend par "Patient location required" ka validation error na aaye.
      String finalLat = widget.lat != null ? widget.lat.toString() : "31.5204"; // Default Lat (e.g., Lahore)
      String finalLng = widget.lng != null ? widget.lng.toString() : "74.3587"; // Default Lng (e.g., Lahore)

      final Map<String, String> queryParameters = {
        'lat': finalLat,
        'lng': finalLng,
        'radius': '30',
        'limit': '50',
      };

      // Agar requestId moojud hai to hi parameter mein add karein
      if (widget.requestId != null && widget.requestId!.isNotEmpty) {
        queryParameters['request_id'] = widget.requestId!;
      }

      final uri = Uri.parse(apiUrl).replace(queryParameters: queryParameters);

      // VS Code Terminal mein URL check karne ke liye
      print("Sending Request to: $uri");

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      // Terminal logs for debugging
      print("Backend Status Code: ${response.statusCode}");
      print("Backend Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);

        if (data['success'] == true) {
          setState(() {
            bloodBanks = data['data'] ?? [];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['message'] ?? "Failed to fetch blood banks";
            isLoading = false;
          });
        }
      } else if (response.statusCode == 422) {
        // Backend validation error ko pakadne ke liye
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        setState(() {
          errorMessage = "Validation Error: ${errorData['message'] ?? 'Invalid input data'}";
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = "Server Error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      print("Flutter Catch Error: $e");
      setState(() {
        errorMessage = "Connection Error: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: primaryMaroon,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Nearby Blood Banks",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchBloodBanks,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryMaroon),
                          onPressed: fetchBloodBanks,
                          child: const Text("Retry", style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              : bloodBanks.isEmpty
                  ? const Center(
                      child: Text(
                        "No nearby blood banks found",
                        style: TextStyle(fontSize: 15, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: bloodBanks.length,
                      itemBuilder: (context, index) {
                        final bank = bloodBanks[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bank['hospital_name'] ?? 'Unknown Hospital',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB71C1C),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  bank['address'] ??
                                      bank['location'] ??
                                      'No address available',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (bank['distance_km'] != null)
                                  Text(
                                    "${bank['distance_km']} km away",
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryMaroon,
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  PatientBloodBankMapScreen(
                                                selectedBank: {
                                                  'name': bank['hospital_name'],
                                                  'location': bank['address'] ??
                                                      bank['location'],
                                                  'lat': bank['latitude'],
                                                  'lng': bank['longitude'],
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "VIEW ON MAP",
                                          style: TextStyle(fontSize: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}