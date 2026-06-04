// lib/screens/Donor/DonorDonationRequestScreen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';
import 'package:blood_donation_app/screens/Donor/Donor_Consent_Form_Screen.dart';

class DonorDonationRequestScreen extends StatefulWidget {
  static const String routeName = '/donor-donation-requests-screen';

  const DonorDonationRequestScreen({super.key});

  @override
  State<DonorDonationRequestScreen> createState() =>
      _DonorDonationRequestScreenState();
}

class _DonorDonationRequestScreenState
    extends State<DonorDonationRequestScreen> {
  bool isLoading = true;
  String errorMessage = '';
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    fetchBloodRequests();
  }

  Future<void> fetchBloodRequests() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await AuthTokenService.authorizedGet(
        '/donor-donation-requests',
      );

      debugPrint('Donor Blood Requests Status: ${response.statusCode}');
      debugPrint('Donor Blood Requests Body: ${response.body}');

      Map<String, dynamic> body = {};

      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      if (!mounted) return;

      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] is List ? body['data'] : [];

        setState(() {
          requests = list
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = body['message'] ?? 'Failed to fetch blood requests.';
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

  Future<void> rejectRequest(Map<String, dynamic> item) async {
    final String requestId = item['id']?.toString() ?? '';

    if (requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donation request ID missing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await AuthTokenService.authorizedPost(
        '/donation-requests/$requestId/reject',
        {
          'reason': 'Donor cannot donate blood right now.',
        },
      );

      debugPrint('Reject Request Status: ${response.statusCode}');
      debugPrint('Reject Request Body: ${response.body}');

      Map<String, dynamic> body = {};

      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      if (!mounted) return;

      if (response.statusCode == 200 && body['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              body['message'] ?? 'Request rejected successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );

        await fetchBloodRequests();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(body['message'] ?? 'Failed to reject request.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> openConsentForm(Map<String, dynamic> item) async {
    final String requestId = item['id']?.toString() ?? '';

    if (requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donation request ID missing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConsentFormScreen(
          requestId: requestId,
          patientName: item['patient_name']?.toString() ?? 'Patient',
          bloodGroup: item['blood_group']?.toString() ??
              item['donor_blood_group']?.toString() ??
              '',
          patientLocation:
              item['patient_location']?.toString() ?? 'Location not available',
          patientMessage: item['message']?.toString() ?? '',
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await fetchBloodRequests();
    }
  }

  Color statusColor(String status) {
    final lower = status.toLowerCase();

    if (lower == 'pending') return Colors.orange;
    if (lower == 'accepted') return Colors.green;
    if (lower == 'rejected') return Colors.red;

    return Colors.grey;
  }

  String formatStatus(String status) {
    final lower = status.toLowerCase();

    if (lower == 'pending') return 'Pending';
    if (lower == 'accepted') return 'Accepted';
    if (lower == 'rejected') return 'Rejected';

    return status.trim().isEmpty ? 'N/A' : status;
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

  Widget infoRow(String label, String value) {
    String safeValue = value;

    if (safeValue.trim().isEmpty || safeValue.trim().toLowerCase() == 'null') {
      safeValue = 'N/A';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              safeValue,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRequestCard(Map<String, dynamic> item) {
    final String patientName = item['patient_name']?.toString() ?? 'Patient';

    final String bloodGroup = item['blood_group']?.toString() ??
        item['donor_blood_group']?.toString() ??
        'N/A';

    final String location =
        item['patient_location']?.toString() ?? 'Location not available';

    final String phone = item['patient_phone']?.toString() ?? 'N/A';

    final String message = item['message']?.toString() ?? 'N/A';

    final String status = item['status']?.toString() ?? 'pending';

    final String rejectReason = item['reject_reason']?.toString() ?? '';

    final bool isPending = status.toLowerCase() == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: const Color(0xFFFFEAEA),
                  child: Text(
                    bloodGroup,
                    style: const TextStyle(
                      color: primaryMaroon,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor(status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formatStatus(status),
                    style: TextStyle(
                      color: statusColor(status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            infoRow('Location', location),
            infoRow('Phone', phone),
            infoRow('Message', message),
            infoRow('Time', formatTime(item['created_at'])),

            if (rejectReason.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reject Reason: $rejectReason',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],

            const SizedBox(height: 14),

            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => openConsentForm(item),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'Yes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => rejectRequest(item),
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text(
                        'No',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor(status).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: statusColor(status).withOpacity(0.25),
                  ),
                ),
                child: Text(
                  status.toLowerCase() == 'accepted'
                      ? 'You accepted this request.'
                      : 'You rejected this request.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: statusColor(status),
                    fontWeight: FontWeight.bold,
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bloodtype_outlined,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Text(
            'No blood requests yet',
            style: TextStyle(fontSize: 17, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int pendingCount = requests
        .where((item) => item['status']?.toString().toLowerCase() == 'pending')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          pendingCount > 0
              ? 'Blood Requests ($pendingCount)'
              : 'Blood Requests',
        ),
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: fetchBloodRequests,
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
                          onPressed: fetchBloodRequests,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : requests.isEmpty
                  ? buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: fetchBloodRequests,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: requests.length,
                        itemBuilder: (context, index) {
                          return buildRequestCard(requests[index]);
                        },
                      ),
                    ),
    );
  }
}