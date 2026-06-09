// lib/screens/blood_bank_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme.dart';
import './patient_blood_bank_map_screen.dart';

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
  static const String latestActiveBloodRequestIdKey =
      'latest_active_blood_request_id';

  List<dynamic> bloodBanks = [];

  bool isLoading = true;
  bool isFetchingBanks = false;
  bool showFillFormCard = false;
  bool hasLoadedOnce = false;

  double radius = 30.0;

  String errorMessage = '';
  String? activeBloodRequestId;

  final String apiUrl =
      "https://manliness-smugness-qualm.ngrok-free.dev/api/blood-banks";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (hasLoadedOnce) return;
    hasLoadedOnce = true;

    initializeBloodBankScreen();
  }

  Future<void> initializeBloodBankScreen() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
      showFillFormCard = false;
    });

    await resolveActiveBloodRequestId();

    if (!mounted) return;

    final bool hasRequestId =
        activeBloodRequestId != null && activeBloodRequestId!.trim().isNotEmpty;

    final bool hasLatLng = widget.lat != null && widget.lng != null;

    if (!hasRequestId && !hasLatLng) {
      setState(() {
        isLoading = false;
        showFillFormCard = true;
        bloodBanks = [];
        errorMessage = '';
      });
      return;
    }

    await fetchBloodBanks();
  }

  Future<void> resolveActiveBloodRequestId() async {
    String? resolvedId;

    if (widget.requestId != null && widget.requestId!.trim().isNotEmpty) {
      resolvedId = widget.requestId!.trim();
    }

    final Object? args = ModalRoute.of(context)?.settings.arguments;

    if (args is String && args.trim().isNotEmpty) {
      resolvedId = args.trim();
    }

    if (args is Map) {
      final dynamic value = args['blood_request_id'] ??
          args['bloodRequestId'] ??
          args['request_id'] ??
          args['requestId'] ??
          args['id'];

      if (value != null && value.toString().trim().isNotEmpty) {
        resolvedId = value.toString().trim();
      }
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    if (resolvedId == null || resolvedId.trim().isEmpty) {
      resolvedId = prefs.getString(latestActiveBloodRequestIdKey);
    }

    if (resolvedId != null && resolvedId.trim().isNotEmpty) {
      resolvedId = resolvedId.trim();

      await prefs.setString(
        latestActiveBloodRequestIdKey,
        resolvedId,
      );
    }

    activeBloodRequestId = resolvedId;
  }

  Future<void> clearSavedActiveBloodRequestId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove(latestActiveBloodRequestIdKey);

    activeBloodRequestId = null;
  }

  Future<void> fetchBloodBanks({bool showLoader = true}) async {
    try {
      if (showLoader) {
        setState(() {
          isLoading = bloodBanks.isEmpty;
          isFetchingBanks = true;
          errorMessage = '';
          showFillFormCard = false;
        });
      } else {
        setState(() {
          isFetchingBanks = true;
          errorMessage = '';
          showFillFormCard = false;
        });
      }

      final Map<String, String> queryParameters = {
        'radius': radius.round().toString(),
        'limit': '50',
      };

      if (activeBloodRequestId != null &&
          activeBloodRequestId!.trim().isNotEmpty) {
        queryParameters['blood_request_id'] = activeBloodRequestId!.trim();

        // Backward compatibility agar backend request_id bhi use kar raha ho.
        queryParameters['request_id'] = activeBloodRequestId!.trim();
      } else {
        if (widget.lat != null) {
          queryParameters['lat'] = widget.lat.toString();
        }

        if (widget.lng != null) {
          queryParameters['lng'] = widget.lng.toString();
        }
      }

      final Uri uri = Uri.parse(apiUrl).replace(
        queryParameters: queryParameters,
      );

      debugPrint('Blood Banks API URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );

      debugPrint('Blood Banks Status: ${response.statusCode}');
      debugPrint('Blood Banks Body: ${response.body}');

      if (!mounted) return;

      Map<String, dynamic> data = {};

      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = {};
      }

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          bloodBanks = data['data'] ?? [];
          isLoading = false;
          isFetchingBanks = false;
          showFillFormCard = false;
          errorMessage = '';
        });

        return;
      }

      final String? code = data['code']?.toString();

      if (response.statusCode == 422 &&
          (code == 'BLOOD_REQUEST_NOT_ACTIVE' ||
              code == 'BLOOD_REQUEST_ID_REQUIRED' ||
              code == 'BLOOD_REQUEST_LOCATION_MISSING')) {
        await clearSavedActiveBloodRequestId();

        if (!mounted) return;

        setState(() {
          bloodBanks = [];
          isLoading = false;
          isFetchingBanks = false;
          showFillFormCard = true;
          errorMessage = '';
        });

        return;
      }

      setState(() {
        errorMessage = data['message'] ?? "Server Error: ${response.statusCode}";
        isLoading = false;
        isFetchingBanks = false;
        showFillFormCard = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = "Connection Error: $e";
        isLoading = false;
        isFetchingBanks = false;
        showFillFormCard = false;
      });
    }
  }

  void openBloodRequestForm() {
    Navigator.pushNamed(
      context,
      '/blood_request',
    ).then((_) {
      initializeBloodBankScreen();
    });
  }

  Widget buildFillFormCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: primaryMaroon.withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: primaryMaroon.withOpacity(0.10),
                child: const Icon(
                  Icons.local_hospital,
                  color: primaryMaroon,
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Fill the form to find nearby blood banks",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please submit a blood request first. Blood banks will be shown according to the location selected in your form.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: openBloodRequestForm,
                  icon: const Icon(
                    Icons.edit_document,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    "Fill Blood Request Form",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryMaroon,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget buildRadiusSlider() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                "Radius",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                "${radius.round()} km",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryMaroon,
                ),
              ),
            ],
          ),
          Slider(
            value: radius,
            min: 5,
            max: 100,
            divisions: 19,
            label: "${radius.round()} km",
            activeColor: primaryMaroon,
            onChanged: (value) {
              setState(() {
                radius = value;
              });
            },
            onChangeEnd: (value) async {
              await fetchBloodBanks(showLoader: false);
            },
          ),
          if (isFetchingBanks && bloodBanks.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.local_hospital_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 14),
            const Text(
              "No nearby blood banks found",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "No active blood banks were found within ${radius.round()} km of your blood request location.",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => fetchBloodBanks(),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryMaroon,
              ),
              child: const Text(
                "Retry",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBloodBankCard(dynamic bank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bank['hospital_name'] ?? bank['name'] ?? 'Unknown Hospital',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB71C1C),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              bank['address'] ?? bank['location'] ?? 'No address available',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            if (bank['phone_number'] != null &&
                bank['phone_number'].toString().trim().isNotEmpty)
              Text(
                "Phone: ${bank['phone_number']}",
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
            if (bank['distance_km'] != null) ...[
              const SizedBox(height: 6),
              Text(
                "${bank['distance_km']} km away",
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryMaroon,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PatientBloodBankMapScreen(
                            selectedBank: {
                              'name': bank['hospital_name'] ?? bank['name'],
                              'location': bank['address'] ?? bank['location'],
                              'lat': bank['latitude'],
                              'lng': bank['longitude'],
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.map,
                      color: Colors.white,
                      size: 17,
                    ),
                    label: const Text(
                      "VIEW ON MAP",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBloodBanksList() {
    return RefreshIndicator(
      onRefresh: () => fetchBloodBanks(showLoader: false),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: bloodBanks.length,
        itemBuilder: (context, index) {
          final bank = bloodBanks[index];

          return buildBloodBankCard(bank);
        },
      ),
    );
  }

  Widget buildMainContent() {
    if (showFillFormCard) {
      return buildFillFormCard();
    }

    if (errorMessage.isNotEmpty) {
      return Column(
        children: [
          buildRadiusSlider(),
          Expanded(child: buildErrorState()),
        ],
      );
    }

    return Column(
      children: [
        buildRadiusSlider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "${bloodBanks.length} blood banks within ${radius.round()} km",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
        Expanded(
          child: bloodBanks.isEmpty ? buildEmptyState() : buildBloodBanksList(),
        ),
      ],
    );
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
            onPressed: () => fetchBloodBanks(showLoader: false),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : buildMainContent(),
    );
  }
}