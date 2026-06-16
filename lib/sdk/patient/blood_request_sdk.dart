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

  static const List<String> validSeverities = [
    'normal',
    'urgent',
    'critical',
    'emergency',
  ];

  static const List<int> validRequiredWithinHours = [1, 2, 4, 6, 12, 24];

  static int _priorityScore(String severity, int requiredWithinHours) {
    int severityScore;

    switch (severity) {
      case 'emergency':
        severityScore = 100;
        break;
      case 'critical':
        severityScore = 80;
        break;
      case 'urgent':
        severityScore = 60;
        break;
      default:
        severityScore = 30;
        break;
    }

    int timeScore;

    if (requiredWithinHours <= 1) {
      timeScore = 30;
    } else if (requiredWithinHours <= 2) {
      timeScore = 25;
    } else if (requiredWithinHours <= 4) {
      timeScore = 20;
    } else if (requiredWithinHours <= 6) {
      timeScore = 15;
    } else if (requiredWithinHours <= 12) {
      timeScore = 10;
    } else {
      timeScore = 5;
    }

    final score = severityScore + timeScore;

    return score > 100 ? 100 : score;
  }

  static Future<String> createBloodRequest({
    required String patientName,
    required String location,
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
    required String doctorNote,
    String? city,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final patientUser = await AuthSdk.currentAppUser(expectedRole: 'patient');

    if (patientUser == null) {
      throw const SdkException(
        'Patient profile not found. Please login again.',
      );
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

    final cleanSeverity = severity.trim().toLowerCase();
    final cleanCaseType = caseType.trim().toLowerCase();
    final cleanDoctorNote = doctorNote.trim();

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

    if (unitsRequired < 1) {
      throw const SdkException('Please select valid units required.');
    }

    if (!validSeverities.contains(cleanSeverity)) {
      throw const SdkException('Please select valid severity level.');
    }

    if (!validRequiredWithinHours.contains(requiredWithinHours)) {
      throw const SdkException('Please select valid required within time.');
    }

    if (cleanCaseType.isEmpty) {
      throw const SdkException('Please select case type.');
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

    final nowDateTime = DateTime.now();
    final now = nowDateTime.toIso8601String();
    final requiredByTime = nowDateTime
        .add(Duration(hours: requiredWithinHours))
        .toIso8601String();

    final isEmergency =
        cleanSeverity == 'urgent' ||
        cleanSeverity == 'critical' ||
        cleanSeverity == 'emergency';

    final priorityScore = _priorityScore(cleanSeverity, requiredWithinHours);

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
      'units_required': unitsRequired,

      'severity': cleanSeverity,
      'required_within_hours': requiredWithinHours,
      'required_by_time': requiredByTime,
      'case_type': cleanCaseType,

      'case_description': cleanCaseDescription,
      'message': cleanCaseDescription,

      'doctor_note': cleanDoctorNote,

      'is_emergency': isEmergency,
      'priority_score': priorityScore,

      'latitude': latitude,
      'longitude': longitude,
      'coordinates': {'latitude': latitude, 'longitude': longitude},

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