//

import 'package:flutter/material.dart';

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/screens/Donor/Donor_Consent_Form_Screen.dart';
import 'package:blood_donation_app/sdk/core/sdk_exception.dart';
import 'package:blood_donation_app/sdk/donor/donor_donation_request_sdk.dart';

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
      final List<Map<String, dynamic>> list =
          await DonorDonationRequestSdk.fetchIncomingRequests();

      if (!mounted) return;

      setState(() {
        requests = list;
        isLoading = false;
        errorMessage = '';
      });
    } on SdkException catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.message;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> rejectRequest(Map<String, dynamic> item) async {
    final String requestId =
        item['id']?.toString() ?? item['donation_request_id']?.toString() ?? '';

    if (requestId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Donation request ID missing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await DonorDonationRequestSdk.rejectRequest(
        donationRequestId: requestId,
        reason: 'Donor cannot donate blood right now.',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected successfully.'),
          backgroundColor: Colors.green,
        ),
      );

      await fetchBloodRequests();
    } on SdkException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> openConsentForm(Map<String, dynamic> item) async {
    final String requestId =
        item['id']?.toString() ?? item['donation_request_id']?.toString() ?? '';

    if (requestId.trim().isEmpty) {
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
          bloodGroup:
              item['blood_group']?.toString() ??
              item['donor_blood_group']?.toString() ??
              '',
          patientLocation:
              item['patient_location']?.toString() ?? 'Location not available',
          patientMessage:
              item['case_description']?.toString() ??
              item['message']?.toString() ??
              '',
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

  String safeText(dynamic value) {
    if (value == null) return '';

    final text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }

    return text;
  }

  String readableText(dynamic value) {
    final text = safeText(value);

    if (text.isEmpty) return '';

    final cleaned = text
        .replaceAll('_', ' ')
        .replaceAll('/', ' / ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return cleaned
        .split(' ')
        .map((word) {
          if (word.trim().isEmpty) return '';
          if (word == '/') return word;

          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .where((word) => word.trim().isNotEmpty)
        .join(' ');
  }

  String formatBloodConstituents(dynamic value) {
    if (value == null) return '';

    if (value is List) {
      final list = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty && item.toLowerCase() != 'null')
          .toList();

      return list.join(', ');
    }

    return safeText(value);
  }

  String formatUnitsRequired(dynamic value) {
    final text = safeText(value);

    if (text.isEmpty) return '';

    final units = int.tryParse(text);

    if (units == null) return text;

    if (units == 4) {
      return '4+ Units';
    }

    return '$units Unit${units > 1 ? 's' : ''}';
  }

  String formatRequiredWithin(dynamic value) {
    final text = safeText(value);

    if (text.isEmpty) return '';

    final hours = int.tryParse(text);

    if (hours == null) return text;

    return 'Within $hours hour${hours > 1 ? 's' : ''}';
  }

  String formatPriority(dynamic value) {
    final text = safeText(value);

    if (text.isEmpty) return '';

    return '$text / 100';
  }

  String formatEmergency(dynamic value) {
    if (value == null) return '';

    if (value is bool) {
      return value ? 'Yes' : 'No';
    }

    final text = value.toString().trim().toLowerCase();

    if (text == 'true' || text == '1' || text == 'yes') {
      return 'Yes';
    }

    if (text == 'false' || text == '0' || text == 'no') {
      return 'No';
    }

    return safeText(value);
  }

  String formatDateTime(dynamic value) {
    final text = safeText(value);

    if (text.isEmpty) return '';

    try {
      final date = DateTime.parse(text).toLocal();

      String twoDigits(int number) {
        return number.toString().padLeft(2, '0');
      }

      return '${twoDigits(date.day)}-${twoDigits(date.month)}-${date.year} '
          '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
    } catch (_) {
      return text;
    }
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
            width: 118,
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
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget optionalInfoRow(String label, String value) {
    if (value.trim().isEmpty || value.trim().toLowerCase() == 'null') {
      return const SizedBox.shrink();
    }

    return infoRow(label, value);
  }

  Widget smallDivider() {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Divider(color: Colors.grey.shade200, height: 1),
    );
  }

  Widget buildRequestCard(Map<String, dynamic> item) {
    final String patientName = safeText(item['patient_name']).isNotEmpty
        ? safeText(item['patient_name'])
        : 'Patient';

    final String bloodGroup = safeText(item['blood_group']).isNotEmpty
        ? safeText(item['blood_group'])
        : safeText(item['donor_blood_group']).isNotEmpty
        ? safeText(item['donor_blood_group'])
        : 'N/A';

    final String location = safeText(item['patient_location']).isNotEmpty
        ? safeText(item['patient_location'])
        : safeText(item['location']).isNotEmpty
        ? safeText(item['location'])
        : 'Location not available';

    final String city = safeText(item['city']).isNotEmpty
        ? safeText(item['city'])
        : safeText(item['current_city']);

    final String phone = safeText(item['patient_phone']);

    final String hospitalName = safeText(item['hospital_name']);

    final String constituents = formatBloodConstituents(
      item['blood_constituents'],
    );

    final String units = formatUnitsRequired(item['units_required']);

    final String severity = readableText(item['severity']);

    final String requiredWithin = formatRequiredWithin(
      item['required_within_hours'],
    );

    final String requiredBy = formatDateTime(item['required_by_time']);

    final String caseType = readableText(item['case_type']);

    final String message = safeText(item['case_description']).isNotEmpty
        ? safeText(item['case_description'])
        : safeText(item['message']);

    final String doctorNote = safeText(item['doctor_note']);

    final String emergency = formatEmergency(item['is_emergency']);

    final String priority = formatPriority(item['priority_score']);

    final String status = safeText(item['status']).isNotEmpty
        ? safeText(item['status'])
        : 'pending';

    final String rejectReason = safeText(item['reject_reason']);

    final bool isPending = status.toLowerCase() == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

            infoRow('Hospital', hospitalName),
            optionalInfoRow('City', city),
            infoRow('Location', location),
            optionalInfoRow('Phone', phone),

            smallDivider(),

            infoRow('Blood Group', bloodGroup),
            optionalInfoRow('Constituents', constituents),
            optionalInfoRow('Units', units),
            optionalInfoRow('Severity', severity),
            optionalInfoRow('Required', requiredWithin),
            optionalInfoRow('Required By', requiredBy),
            optionalInfoRow('Case Type', caseType),
            optionalInfoRow('Emergency', emergency),
            optionalInfoRow('Priority', priority),

            smallDivider(),

            infoRow('Case Details', message),
            optionalInfoRow('Doctor Note', doctorNote),
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
          Icon(Icons.bloodtype_outlined, size: 80, color: Colors.grey),
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