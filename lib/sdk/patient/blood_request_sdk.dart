// lib/sdk/patient/blood_request_sdk.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/sdk_exception.dart';

class BloodRequestSdk {
  BloodRequestSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String collectionName = 'blood_requests';

  static const List<String> validBloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static String _now() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceFirst('Z', '+00:00');
  }

  static void _validateText({
    required String value,
    required String fieldName,
  }) {
    if (value.trim().isEmpty) {
      throw SdkException('$fieldName is required.');
    }
  }

  static Future<String> createBloodRequest({
    required String patientName,
    required String location,
    required String? city,
    required String hospitalName,
    required String bloodGroup,
    required List<String> bloodConstituents,
    required String caseDescription,
    required double latitude,
    required double longitude,
    required int unitsRequired,
    required String severity,
    required int requiredWithinHours,
    required String caseType,
    String? doctorNote,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw SdkException('Session not found. Please login again.');
    }

    final String uid = currentUser.uid;

    _validateText(value: patientName, fieldName: 'Patient name');
    _validateText(value: location, fieldName: 'Location');
    _validateText(value: hospitalName, fieldName: 'Hospital name');
    _validateText(value: caseDescription, fieldName: 'Case description');
    _validateText(value: severity, fieldName: 'Severity');
    _validateText(value: caseType, fieldName: 'Case type');

    if (!validBloodGroups.contains(bloodGroup)) {
      throw SdkException('Invalid blood group.');
    }

    if (bloodConstituents.isEmpty) {
      throw SdkException('Please select blood constituents.');
    }

    if (unitsRequired <= 0) {
      throw SdkException('Invalid units required.');
    }

    if (requiredWithinHours <= 0) {
      throw SdkException('Invalid required within time.');
    }

    final DocumentReference<Map<String, dynamic>> docRef =
        _firestore.collection(collectionName).doc();

    final String now = _now();

    final Map<String, dynamic> data = {
      'blood_request_id': docRef.id,
      'request_id': docRef.id,

      'patient_uid': uid,
      'user_id': uid,
      'created_by_uid': uid,

      'patient_name': patientName.trim(),
      'location': location.trim(),
      'city': city?.trim() ?? '',
      'hospital_name': hospitalName.trim(),

      'blood_group': bloodGroup,
      'blood_constituents': bloodConstituents,

      'case_description': caseDescription.trim(),
      'doctor_note': doctorNote?.trim() ?? '',

      'latitude': latitude,
      'longitude': longitude,

      'units_required': unitsRequired,
      'severity': severity.trim(),
      'required_within_hours': requiredWithinHours,
      'case_type': caseType.trim(),

      'status': 'pending',
      'request_status': 'pending',
      'is_active': true,

      'accepted_donor_uid': '',
      'accepted_donor_id': '',
      'accepted_donor_name': '',
      'accepted_donor_phone': '',

      'rejected_donor_uid': '',
      'rejected_donor_id': '',
      'reject_reason': '',

      'created_at': now,
      'updated_at': now,
    };

    try {
      await docRef.set(data);

      return docRef.id;
    } on FirebaseException catch (e) {
      throw SdkException(
        e.message ?? 'Failed to create blood request.',
      );
    } catch (e) {
      throw SdkException('Failed to create blood request.');
    }
  }
}