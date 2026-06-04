// lib/screens/blood_bank_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../theme.dart';
import './Donor_Blood_Bank_Map_Screen.dart';

class BloodBankScreen extends StatefulWidget {
  static const String routeName = '/blood_bank';

  final double? lat;
  final double? lng;
  final String? requestId;

  const BloodBankScreen({
    super.key,
    this.lat,
    this.lng,
    this.requestId,
  });

  @override
  State<BloodBankScreen> createState() => _BloodBankScreenState();
}

class _BloodBankScreenState extends State<BloodBankScreen> {
  List<dynamic> bloodBanks = [];
  bool isLoading = true;
  String errorMessage = '';

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

      final uri = Uri.parse(apiUrl).replace(queryParameters: {
        if (widget.requestId != null) 'request_id': widget.requestId!,
        if (widget.lat != null) 'lat': widget.lat.toString(),
        if (widget.lng != null) 'lng': widget.lng.toString(),
        'radius': '30',
        'limit': '50',
      });

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

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
      } else {
        setState(() {
          errorMessage = "Server Error: ${response.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
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
                        Text(errorMessage, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: fetchBloodBanks,
                          child: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              : bloodBanks.isEmpty
                  ? const Center(
                      child: Text("No nearby blood banks found"),
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
                                                  DonorBloodBankMapScreen(
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
                                          style: TextStyle(fontSize: 12),
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