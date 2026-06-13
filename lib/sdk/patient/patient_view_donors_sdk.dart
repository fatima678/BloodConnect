// lib/sdk/patient/patient_view_donors_sdk.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_sdk.dart';
import '../core/sdk_exception.dart';

class PatientViewDonorsSdk {
  PatientViewDonorsSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String donationRequestsCollection = 'donation_requests';

  static String _readString(Map<String, dynamic> data, List<String> keys) {
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

  static Future<List<Map<String, dynamic>>> fetchAcceptedDonors() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final patientUser = await AuthSdk.currentAppUser(expectedRole: 'patient');

    if (patientUser == null) {
      throw const SdkException('Patient profile not found. Please login again.');
    }

    final snapshot = await _firestore
        .collection(donationRequestsCollection)
        .where('patient_uid', isEqualTo: firebaseUser.uid)
        .get();

    final List<Map<String, dynamic>> acceptedDonors = [];

    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());

      final String status = _readString(data, [
        'status',
        'request_status',
      ]).toLowerCase();

      final bool phoneVisible =
          data['phone_visible_to_patient'] == true ||
          data['is_phone_visible'] == true;

      final String donorPhone = _readString(data, [
        'donor_phone',
        'phone',
        'contact',
        'phone_number',
      ]);

      if (status != 'accepted') continue;
      if (!phoneVisible) continue;
      if (donorPhone.isEmpty) continue;

      final item = <String, dynamic>{
        ...data,
        'id': data['id'] ?? data['donation_request_id'] ?? doc.id,
        'donation_request_id': data['donation_request_id'] ?? doc.id,

        'donor_name': _readString(data, [
          'donor_name',
          'name',
        ]).isNotEmpty
            ? _readString(data, ['donor_name', 'name'])
            : 'Donor',

        'donor_phone': donorPhone,

        'donor_blood_group': _readString(data, [
          'donor_blood_group',
          'blood_group',
          'patient_blood_group',
        ]),

        'blood_group': _readString(data, [
          'blood_group',
          'donor_blood_group',
          'patient_blood_group',
        ]),

        'message': _readString(data, [
          'donor_message',
          'message',
        ]).isNotEmpty
            ? _readString(data, ['donor_message', 'message'])
            : 'Your blood request has been accepted.',

        'status': status,
        'phone_visible_to_patient': true,

        'donor_responded_at': data['donor_responded_at'] ??
            data['accepted_at'] ??
            data['updated_at'] ??
            data['created_at'],
      };

      acceptedDonors.add(item);
    }

    acceptedDonors.sort((a, b) {
      final String bTime =
          (b['donor_responded_at'] ?? b['updated_at'] ?? b['created_at'])
                  ?.toString() ??
              '';

      final String aTime =
          (a['donor_responded_at'] ?? a['updated_at'] ?? a['created_at'])
                  ?.toString() ??
              '';

      return bTime.compareTo(aTime);
    });

    return acceptedDonors;
  }
}