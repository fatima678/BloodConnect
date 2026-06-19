import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/screens/general_consent_form_screen.dart';
import 'package:blood_donation_app/sdk/donation_request_sdk.dart';

class IncomingBloodRequestsScreen extends StatefulWidget {
  const IncomingBloodRequestsScreen({super.key});

  @override
  State<IncomingBloodRequestsScreen> createState() =>
      _IncomingBloodRequestsScreenState();
}

class _IncomingBloodRequestsScreenState
    extends State<IncomingBloodRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, Map<String, dynamic>> _preparedRequestCache = {};

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

  String _extractLocation(Map<String, dynamic> data) {
    final String directLocation = _readString(
      data,
      [
        'patient_location',
        'patientLocation',
        'patient_address',
        'patientAddress',
        'recipient_location',
        'recipientLocation',
        'recipient_address',
        'recipientAddress',
        'request_location',
        'requestLocation',
        'blood_request_location',
        'bloodRequestLocation',
        'blood_request_address',
        'bloodRequestAddress',
        'location',
        'address',
        'current_location',
        'currentLocation',
        'hospital_location',
        'hospitalLocation',
        'hospital_address',
        'hospitalAddress',
        'donation_location',
        'donationLocation',
        'pickup_location',
        'pickupLocation',
        'selected_location',
        'selectedLocation',
        'formatted_address',
        'formattedAddress',
        'place_name',
        'placeName',
        'full_address',
        'fullAddress',
        'city',
      ],
    );

    if (directLocation.isNotEmpty) {
      return directLocation;
    }

    final List<String> nestedKeys = [
      'blood_request',
      'bloodRequest',
      'blood_request_data',
      'bloodRequestData',
      'request',
      'request_data',
      'requestData',
      'patient',
      'recipient',
      'location_data',
      'locationData',
      'selected_place',
      'selectedPlace',
      'place',
    ];

    for (final key in nestedKeys) {
      final value = data[key];

      if (value is Map) {
        final nestedData = Map<String, dynamic>.from(value);

        final nestedLocation = _extractLocation(nestedData);

        if (nestedLocation.isNotEmpty) {
          return nestedLocation;
        }
      }
    }

    return '';
  }

  String _requestCacheKey(Map<String, dynamic> request) {
    final key = _readString(
      request,
      [
        'donation_request_id',
        'id',
        'blood_request_id',
        'bloodRequestId',
        'request_id',
        'requestId',
      ],
    );

    if (key.isNotEmpty) {
      return key;
    }

    return request.hashCode.toString();
  }

  Future<Map<String, dynamic>?> _fetchBloodRequestData(
    String bloodRequestId,
  ) async {
    if (bloodRequestId.trim().isEmpty) {
      return null;
    }

    try {
      final directSnapshot = await _firestore
          .collection('blood_requests')
          .doc(bloodRequestId.trim())
          .get();

      if (directSnapshot.exists && directSnapshot.data() != null) {
        final data = Map<String, dynamic>.from(directSnapshot.data()!);

        data['id'] = data['id'] ?? directSnapshot.id;
        data['blood_request_id'] =
            data['blood_request_id'] ?? directSnapshot.id;

        return data;
      }

      final querySnapshot = await _firestore
          .collection('blood_requests')
          .where('blood_request_id', isEqualTo: bloodRequestId.trim())
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = Map<String, dynamic>.from(doc.data());

        data['id'] = data['id'] ?? doc.id;
        data['blood_request_id'] = data['blood_request_id'] ?? doc.id;

        return data;
      }
    } catch (e) {
      debugPrint('Fetch blood request location error: $e');
    }

    return null;
  }

  void _copyStringIfMissing({
    required Map<String, dynamic> target,
    required Map<String, dynamic> source,
    required List<String> targetKeys,
    required List<String> sourceKeys,
  }) {
    final existingValue = _readString(target, targetKeys);

    if (existingValue.isNotEmpty) {
      return;
    }

    final sourceValue = _readString(source, sourceKeys);

    if (sourceValue.isEmpty) {
      return;
    }

    target[targetKeys.first] = sourceValue;
  }

  Future<Map<String, dynamic>> _prepareRequestWithBloodRequestDetails(
    Map<String, dynamic> request,
  ) async {
    final String cacheKey = _requestCacheKey(request);

    if (_preparedRequestCache.containsKey(cacheKey)) {
      return Map<String, dynamic>.from(_preparedRequestCache[cacheKey]!);
    }

    final Map<String, dynamic> prepared = Map<String, dynamic>.from(request);

    final String existingLocation = _extractLocation(prepared);

    final String bloodRequestId = _readString(
      prepared,
      [
        'blood_request_id',
        'bloodRequestId',
        'request_id',
        'requestId',
      ],
    );

    if (existingLocation.isEmpty && bloodRequestId.isNotEmpty) {
      final bloodRequestData = await _fetchBloodRequestData(bloodRequestId);

      if (bloodRequestData != null) {
        prepared['blood_request_data'] = bloodRequestData;

        final String bloodRequestLocation = _extractLocation(bloodRequestData);

        if (bloodRequestLocation.isNotEmpty) {
          prepared['patient_location'] = bloodRequestLocation;
          prepared['location'] = bloodRequestLocation;
          prepared['request_location'] = bloodRequestLocation;
          prepared['blood_request_location'] = bloodRequestLocation;
        }

        _copyStringIfMissing(
          target: prepared,
          source: bloodRequestData,
          targetKeys: ['patient_name', 'patientName'],
          sourceKeys: ['patient_name', 'patientName', 'name'],
        );

        _copyStringIfMissing(
          target: prepared,
          source: bloodRequestData,
          targetKeys: ['patient_blood_group', 'blood_group', 'bloodGroup'],
          sourceKeys: [
            'patient_blood_group',
            'blood_group',
            'bloodGroup',
            'blood_type',
            'bloodType',
          ],
        );

        _copyStringIfMissing(
          target: prepared,
          source: bloodRequestData,
          targetKeys: ['message'],
          sourceKeys: [
            'message',
            'case_description',
            'caseDescription',
            'description',
          ],
        );

        _copyStringIfMissing(
          target: prepared,
          source: bloodRequestData,
          targetKeys: ['hospital_name', 'hospitalName'],
          sourceKeys: ['hospital_name', 'hospitalName'],
        );
      }
    }

    final String finalLocation = _extractLocation(prepared);

    if (finalLocation.isNotEmpty) {
      prepared['patient_location'] = finalLocation;
      prepared['location'] = finalLocation;
    }

    _preparedRequestCache[cacheKey] = Map<String, dynamic>.from(prepared);

    return prepared;
  }

  Color _requestStatusColor(String status) {
    final value = status.toLowerCase();

    if (value == 'accepted') return Colors.green;
    if (value == 'rejected' || value == 'declined') return Colors.red;
    return Colors.orange;
  }

  String _requestStatusText(String status) {
    final value = status.toLowerCase();

    if (value == 'accepted') return 'Accepted';
    if (value == 'rejected') return 'Rejected';
    if (value == 'declined') return 'Declined';
    return 'Pending';
  }

  String _requestId(Map<String, dynamic> request) {
    return _readString(
      request,
      ['donation_request_id', 'id'],
    );
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final requestId = _requestId(request);

    if (requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request ID missing.')),
      );
      return;
    }

    try {
      await DonationRequestFlowSdk.rejectRequest(
        donationRequestId: requestId,
      );

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reject request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openConsentForm(Map<String, dynamic> request) async {
    final Map<String, dynamic> preparedRequest =
        await _prepareRequestWithBloodRequestDetails(request);

    final requestId = _requestId(preparedRequest);

    if (requestId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request ID missing.')),
      );
      return;
    }

    Navigator.pop(context);

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GeneralConsentFormScreen(
          donationRequestId: requestId,
          requestData: preparedRequest,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request accepted successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showRequestDetails(Map<String, dynamic> request) async {
    final Map<String, dynamic> preparedRequest =
        await _prepareRequestWithBloodRequestDetails(request);

    if (!mounted) return;

    final patientName = _readString(
      preparedRequest,
      ['patient_name', 'patientName'],
    ).isEmpty
        ? 'Recipient'
        : _readString(preparedRequest, ['patient_name', 'patientName']);

    final bloodGroup = _readString(
      preparedRequest,
      ['patient_blood_group', 'blood_group', 'bloodGroup'],
    ).isEmpty
        ? 'N/A'
        : _readString(
            preparedRequest,
            ['patient_blood_group', 'blood_group', 'bloodGroup'],
          );

    final location = _extractLocation(preparedRequest).isEmpty
        ? 'Location not available'
        : _extractLocation(preparedRequest);

    final message = _readString(preparedRequest, [
      'message',
      'case_description',
      'caseDescription',
      'description',
    ]);

    final status =
        _readString(preparedRequest, ['status', 'request_status']).isEmpty
            ? 'pending'
            : _readString(preparedRequest, ['status', 'request_status']);

    final isPending = status.toLowerCase() == 'pending';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF8F9FA),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 45,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: primaryMaroon.withOpacity(0.12),
                    child: Text(
                      bloodGroup,
                      style: const TextStyle(
                        color: primaryMaroon,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      patientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _requestStatusColor(status).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _requestStatusText(status),
                      style: TextStyle(
                        color: _requestStatusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildRequestDetailRow(Icons.location_on, 'Location', location),
              _buildRequestDetailRow(
                Icons.bloodtype,
                'Blood Group',
                bloodGroup,
              ),
              if (message.isNotEmpty)
                _buildRequestDetailRow(Icons.message, 'Message', message),
              const SizedBox(height: 20),
              if (isPending) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _openConsentForm(preparedRequest),
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'Accept & Fill Consent',
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectRequest(preparedRequest),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text(
                      'Reject Request',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestDetailRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryMaroon, size: 19),
          const SizedBox(width: 10),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestCard(Map<String, dynamic> request) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _prepareRequestWithBloodRequestDetails(request),
      builder: (context, snapshot) {
        final Map<String, dynamic> displayRequest = snapshot.data ?? request;

        final patientName = _readString(
          displayRequest,
          ['patient_name', 'patientName'],
        ).isEmpty
            ? 'Recipient'
            : _readString(displayRequest, ['patient_name', 'patientName']);

        final bloodGroup = _readString(
          displayRequest,
          ['patient_blood_group', 'blood_group', 'bloodGroup'],
        ).isEmpty
            ? 'N/A'
            : _readString(
                displayRequest,
                ['patient_blood_group', 'blood_group', 'bloodGroup'],
              );

        final status =
            _readString(displayRequest, ['status', 'request_status']).isEmpty
                ? 'pending'
                : _readString(displayRequest, ['status', 'request_status']);

        final location = _extractLocation(displayRequest);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryMaroon.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 27,
                backgroundColor: primaryMaroon.withOpacity(0.10),
                child: Text(
                  bloodGroup,
                  style: const TextStyle(
                    color: primaryMaroon,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _requestStatusText(status),
                      style: TextStyle(
                        color: _requestStatusColor(status),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 15,
                            color: Colors.black45,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _showRequestDetails(displayRequest),
                child: const Text(
                  'See Request',
                  style: TextStyle(
                    color: primaryMaroon,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.brown.shade800, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No Blood requests found for you',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.brown,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 30),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red, width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          'Failed to load requests: $error',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildRequestsList(List<Map<String, dynamic>> requests) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(22, 18, 22, 12),
          child: Center(
            child: Text(
              'Blood Requests For You',
              style: TextStyle(
                color: primaryMaroon,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _buildIncomingRequestCard(requests[index]);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        title: const Text('Blood Requests'),
        centerTitle: true,
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: DonationRequestFlowSdk.watchIncomingRequestsForCurrentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: primaryMaroon),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(snapshot.error);
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return _buildEmptyState();
          }

          return _buildRequestsList(requests);
        },
      ),
    );
  }
}