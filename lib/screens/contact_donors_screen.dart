// lib/screens/contact_donors_screen.dart

import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ContactDonorsScreen extends StatefulWidget {
  const ContactDonorsScreen({super.key});

  @override
  State<ContactDonorsScreen> createState() => _ContactDonorsScreenState();
}

class _ContactDonorsScreenState extends State<ContactDonorsScreen> {
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
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Session not found. Please login again.');
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('donation_requests')
          .where('patient_uid', isEqualTo: user.uid)
          .get();

      final List<Map<String, dynamic>> donors = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            data['donation_request_id'] =
                data['donation_request_id'] ?? doc.id;
            return data;
          })
          .where((item) {
            final status = getValue(
              item,
              ['status', 'request_status'],
              fallback: '',
            ).toLowerCase();

            return status == 'accepted';
          })
          .toList();

      donors.sort((a, b) {
        final String aDate = (a['accepted_at'] ??
                a['donor_responded_at'] ??
                a['updated_at'] ??
                a['created_at'] ??
                '')
            .toString();

        final String bDate = (b['accepted_at'] ??
                b['donor_responded_at'] ??
                b['updated_at'] ??
                b['created_at'] ??
                '')
            .toString();

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        acceptedDonors = donors;
        isLoading = false;
        errorMessage = '';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Error: $e';
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

  String getValue(
    Map<String, dynamic> item,
    List<String> keys, {
    String fallback = 'N/A',
  }) {
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

    if (value is Timestamp) {
      final date = value.toDate();
      return formatTime(date.toIso8601String());
    }

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
      ['donor_name', 'accepted_donor_name', 'name'],
      fallback: 'Donor',
    );

    final bloodGroup = getValue(
      item,
      ['donor_blood_group', 'accepted_donor_blood_group', 'blood_group'],
      fallback: 'N/A',
    );

    final donorPhone = getValue(
      item,
      ['donor_phone', 'accepted_donor_phone', 'phone'],
      fallback: '',
    );

    final message = getValue(
      item,
      ['donor_consent_message', 'donor_message', 'message'],
      fallback: 'Your blood request has been accepted.',
    );

    final acceptedTime = formatTime(
      item['accepted_at'] ??
          item['donor_responded_at'] ??
          item['updated_at'] ??
          item['created_at'],
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
                const Expanded(
                  child: Text(
                    'Donation Request Accepted',
                    style: TextStyle(
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
                    value: donorPhone.isEmpty ? 'N/A' : donorPhone,
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
                onPressed: donorPhone.isEmpty ? null : () => callDonor(donorPhone),
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
                  disabledBackgroundColor: Colors.grey,
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
        title: const Text('Contact Donors'),
        centerTitle: true,
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