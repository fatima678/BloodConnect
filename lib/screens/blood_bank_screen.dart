import 'package:flutter/material.dart';

import '../theme.dart';
import '../sdk/patient/blood_bank_sdk.dart';
import '../sdk/core/sdk_exception.dart';
import 'Patient/patient_blood_bank_map_screen.dart';

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
  List<Map<String, dynamic>> bloodBanks = [];

  bool isLoading = true;
  bool isRefreshing = false;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchBloodBanks();
  }

  Future<void> fetchBloodBanks({bool showLoader = true}) async {
    try {
      if (showLoader) {
        setState(() {
          isLoading = bloodBanks.isEmpty;
          isRefreshing = true;
          errorMessage = '';
        });
      } else {
        setState(() {
          isRefreshing = true;
          errorMessage = '';
        });
      }

      final banks = await BloodBankSdk.fetchBloodBanks(
        limit: 100,
      );

      if (!mounted) return;

      setState(() {
        bloodBanks = banks;
        isLoading = false;
        isRefreshing = false;
        errorMessage = '';
      });
    } on SdkException catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.message;
        isLoading = false;
        isRefreshing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Failed to fetch blood banks.';
        isLoading = false;
        isRefreshing = false;
      });
    }
  }

  String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  double? _readDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is num) {
        return value.toDouble();
      }

      final parsed = double.tryParse(value.toString().trim());

      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  Widget buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_hospital_outlined,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 14),
            Text(
              'No blood banks found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'No active blood banks are available right now.',
              textAlign: TextAlign.center,
              style: TextStyle(
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
                'Retry',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildBloodBankCard(Map<String, dynamic> bank) {
    final hospitalName = _readString(bank, [
      'hospital_name',
      'name',
      'bank_name',
    ]);

    final address = _readString(bank, [
      'address',
      'location',
    ]);

    final phoneNumber = _readString(bank, [
      'phone_number',
      'phone',
      'contact',
    ]);

    final status = _readString(bank, [
      'status',
    ]);

    final latitude = _readDouble(bank, [
      'latitude',
      'lat',
    ]);

    final longitude = _readDouble(bank, [
      'longitude',
      'lng',
      'long',
    ]);

    final bool hasMapLocation = latitude != null && longitude != null;

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
              hospitalName.isNotEmpty ? hospitalName : 'Unknown Hospital',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB71C1C),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              address.isNotEmpty ? address : 'No address available',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),

            if (phoneNumber.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Phone: $phoneNumber',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
                ),
              ),
            ],

            if (status.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                style: TextStyle(
                  color: status.toLowerCase() == 'active'
                      ? Colors.green
                      : Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          hasMapLocation ? primaryMaroon : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    onPressed: hasMapLocation
                        ? () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    PatientBloodBankMapScreen(
                                  selectedBank: {
                                    'name': hospitalName.isNotEmpty
                                        ? hospitalName
                                        : 'Unknown Hospital',
                                    'location': address,
                                    'lat': latitude,
                                    'lng': longitude,
                                  },
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(
                      Icons.map,
                      color: Colors.white,
                      size: 17,
                    ),
                    label: const Text(
                      'VIEW ON MAP',
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: bloodBanks.length,
        itemBuilder: (context, index) {
          final bank = bloodBanks[index];

          return buildBloodBankCard(bank);
        },
      ),
    );
  }

  Widget buildMainContent() {
    if (errorMessage.isNotEmpty) {
      return buildErrorState();
    }

    return Column(
      children: [
        if (isRefreshing && bloodBanks.isNotEmpty)
          const LinearProgressIndicator(minHeight: 2),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${bloodBanks.length} blood banks found',
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
          'Blood Banks',
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
          ? const Center(
              child: CircularProgressIndicator(color: primaryMaroon),
            )
          : buildMainContent(),
    );
  }
}