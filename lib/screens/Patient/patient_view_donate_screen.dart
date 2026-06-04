// lib/screens/Patient/ViewDonorsScreen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class ViewDonorsScreen extends StatefulWidget {
  static const String routeName = '/view-donors';

  const ViewDonorsScreen({super.key});

  @override
  State<ViewDonorsScreen> createState() => _ViewDonorsScreenState();
}

class _ViewDonorsScreenState extends State<ViewDonorsScreen> {
  bool isLoading = true;
  String errorMessage = '';
  List<Map<String, dynamic>> acceptedDonors = [];

  @override
  void initState() {
    super.initState();
    fetchAcceptedDonors();
  }

  Future<void> fetchAcceptedDonors() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await AuthTokenService.authorizedGet(
        '/donation-request-history',
      );

      debugPrint('View Donors Status: ${response.statusCode}');
      debugPrint('View Donors Body: ${response.body}');

      Map<String, dynamic> body = {};

      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      if (!mounted) return;

      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] is List ? body['data'] : [];

        final filtered = list
            .map<Map<String, dynamic>>(
              (item) => Map<String, dynamic>.from(item),
            )
            .where((item) {
          final status = item['status']?.toString().toLowerCase() ?? '';
          final phoneVisible = item['phone_visible_to_patient'] == true;
          final phone = item['donor_phone']?.toString().trim() ?? '';

          return status == 'accepted' && phoneVisible && phone.isNotEmpty;
        }).toList();

        setState(() {
          acceptedDonors = filtered;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = body['message'] ?? 'Failed to fetch donor details.';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Connection Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> callDonor(String phone) async {
    final cleanPhone = phone.trim();

    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donor phone number is not available.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final bool? result =
          await FlutterPhoneDirectCaller.callNumber(cleanPhone);

      if (result != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to start phone call.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Call Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String getValue(Map<String, dynamic> item, List<String> keys,
      {String fallback = 'N/A'}) {
    for (final key in keys) {
      final value = item[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        final text = value.toString().trim();

        if (text.toLowerCase() != 'null') {
          return text;
        }
      }
    }

    return fallback;
  }

  String formatTime(dynamic value) {
    if (value == null) return '';

    final text = value.toString();

    try {
      final date = DateTime.parse(text).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays == 1) return 'Yesterday';

      return '${difference.inDays}d ago';
    } catch (_) {
      return text;
    }
  }

  Widget buildInfoRow({
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDonorCard(Map<String, dynamic> item) {
    final donorName = getValue(
      item,
      ['donor_name'],
      fallback: 'Donor',
    );

    final bloodGroup = getValue(
      item,
      ['donor_blood_group', 'blood_group'],
      fallback: 'N/A',
    );

    final donorPhone = getValue(
      item,
      ['donor_phone'],
      fallback: '',
    );

    final message = getValue(
      item,
      ['message'],
      fallback: 'Your blood request has been accepted.',
    );

    final acceptedTime = formatTime(
      item['donor_responded_at'] ?? item['updated_at'] ?? item['created_at'],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: const Color(0xFFEFFFF1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Colors.green.withOpacity(0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFFDFF7E4),
                  child: Icon(
                    Icons.verified,
                    color: Colors.green,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Donation Request Accepted',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Text(
                  acceptedTime,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              '$donorName accepted your blood request. You can call this donor now.',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F8E8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.green.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildInfoRow(
                    label: 'Donor Name',
                    value: donorName,
                  ),
                  buildInfoRow(
                    label: 'Blood Group',
                    value: bloodGroup,
                  ),
                  buildInfoRow(
                    label: 'Donor Phone',
                    value: donorPhone,
                  ),
                  buildInfoRow(
                    label: 'Message',
                    value: message,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton.icon(
                onPressed: () => callDonor(donorPhone),
                icon: const Icon(
                  Icons.call,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Call Donor Directly',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 14),
            Text(
              'No accepted donors yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'When a donor accepts your request, donor details and call option will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('View Donors'),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: fetchAcceptedDonors,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: fetchAcceptedDonors,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : acceptedDonors.isEmpty
                  ? buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: fetchAcceptedDonors,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: acceptedDonors.length,
                        itemBuilder: (context, index) {
                          return buildDonorCard(acceptedDonors[index]);
                        },
                      ),
                    ),
    );
  }
}