// lib/sdk/blood_request/blood_request_sdk.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_sdk.dart';
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

  static Future<String> createBloodRequest({
    required String patientName,
    required String location,
    required String hospitalName,
    required String bloodGroup,
    required List<String> bloodConstituents,
    required String caseDescription,
    required double latitude,
    required double longitude,
    String? city,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final patientUser = await AuthSdk.currentAppUser(expectedRole: 'patient');

    if (patientUser == null) {
      throw const SdkException('Patient profile not found. Please login again.');
    }

    if (patientUser.status.trim().toLowerCase() != 'active') {
      throw const SdkException('Your account is not active.');
    }

    final cleanPatientName = patientName.trim();
    final cleanLocation = location.trim();
    final cleanHospitalName = hospitalName.trim();
    final cleanBloodGroup = bloodGroup.trim().toUpperCase();
    final cleanCaseDescription = caseDescription.trim();
    final cleanCity = city?.trim();

    if (cleanPatientName.isEmpty) {
      throw const SdkException('Patient name is required.');
    }

    if (cleanLocation.isEmpty) {
      throw const SdkException('Location is required.');
    }

    if (cleanHospitalName.isEmpty) {
      throw const SdkException('Hospital name is required.');
    }

    if (!validBloodGroups.contains(cleanBloodGroup)) {
      throw const SdkException('Please select a valid blood group.');
    }

    if (bloodConstituents.isEmpty) {
      throw const SdkException('Please select blood constituents.');
    }

    if (cleanCaseDescription.isEmpty) {
      throw const SdkException('Case description is required.');
    }

    if (latitude < -90 || latitude > 90) {
      throw const SdkException('Invalid latitude.');
    }

    if (longitude < -180 || longitude > 180) {
      throw const SdkException('Invalid longitude.');
    }

    final docRef = _firestore.collection(collectionName).doc();
    final requestId = docRef.id;
    final now = DateTime.now().toIso8601String();

    final data = <String, dynamic>{
      'id': requestId,

      'patient_uid': firebaseUser.uid,
      'user_id': firebaseUser.uid,

      'patient_name': cleanPatientName,
      'patient_email': patientUser.email,
      'patient_phone': patientUser.phone,

      'location': cleanLocation,
      'patient_location': cleanLocation,

      'city': cleanCity,
      'current_city': cleanCity,

      'hospital_name': cleanHospitalName,
      'blood_group': cleanBloodGroup,
      'blood_constituents': bloodConstituents,
      'case_description': cleanCaseDescription,
      'message': cleanCaseDescription,

      'latitude': latitude,
      'longitude': longitude,
      'coordinates': {
        'latitude': latitude,
        'longitude': longitude,
      },

      'status': 'pending',
      'request_status': 'pending',
      'is_active': true,

      'created_at': now,
      'updated_at': now,
    };

    await docRef.set(data);

    return requestId;
  }
}