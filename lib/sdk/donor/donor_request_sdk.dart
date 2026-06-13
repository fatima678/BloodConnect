// lib/sdk/donor/donor_request_sdk.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_sdk.dart';
import '../core/sdk_exception.dart';

class DonorRequestSdk {
  DonorRequestSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String collectionName = 'donor_requests';

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

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _hasDonatedWithinLastThreeMonths(String? lastDonatedDate) {
    if (lastDonatedDate == null || lastDonatedDate.trim().isEmpty) {
      return false;
    }

    final parsedDate = DateTime.tryParse(lastDonatedDate.trim());

    if (parsedDate == null) {
      return false;
    }

    final lastDonation = _dateOnly(parsedDate);
    final minimumAllowedDate = _dateOnly(
      DateTime.now().subtract(const Duration(days: 90)),
    );

    return lastDonation.isAfter(minimumAllowedDate);
  }

  static Future<String> createDonorRequest({
    required String name,
    required String cnic,
    required String phone,
    required String guardianName,
    required String guardianPhone,
    required String bloodGroup,
    required String currentLocation,
    required String city,
    required double latitude,
    required double longitude,
    String? lastDonatedDate,
    bool isAvailableNow = true,
    String? message,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final donorUser = await AuthSdk.currentAppUser(expectedRole: 'donor');

    if (donorUser == null) {
      throw const SdkException('Donor profile not found. Please login again.');
    }

    if (donorUser.status.trim().toLowerCase() != 'active') {
      throw const SdkException('Your account is not active.');
    }

    final cleanName = name.trim();
    final cleanCnic = cnic.trim();
    final cleanPhone = phone.trim();
    final cleanGuardianName = guardianName.trim();
    final cleanGuardianPhone = guardianPhone.trim();
    final cleanBloodGroup = bloodGroup.trim().toUpperCase();
    final cleanCurrentLocation = currentLocation.trim();
    final cleanCity = city.trim();
    final cleanMessage = message?.trim();

    if (cleanName.isEmpty) {
      throw const SdkException('Name is required.');
    }

    if (cleanCnic.isEmpty) {
      throw const SdkException('CNIC is required.');
    }

    if (cleanPhone.isEmpty) {
      throw const SdkException('Phone number is required.');
    }

    if (cleanGuardianName.isEmpty) {
      throw const SdkException('Guardian name is required.');
    }

    if (cleanGuardianPhone.isEmpty) {
      throw const SdkException('Guardian phone number is required.');
    }

    if (!validBloodGroups.contains(cleanBloodGroup)) {
      throw const SdkException('Please select a valid blood group.');
    }

    if (cleanCurrentLocation.isEmpty) {
      throw const SdkException('Current location is required.');
    }

    if (cleanCity.isEmpty) {
      throw const SdkException('City is required.');
    }

    if (latitude < -90 || latitude > 90) {
      throw const SdkException('Invalid latitude.');
    }

    if (longitude < -180 || longitude > 180) {
      throw const SdkException('Invalid longitude.');
    }

    if (_hasDonatedWithinLastThreeMonths(lastDonatedDate)) {
      throw const SdkException(
        'You can donate only after 3 months from your last donation.',
      );
    }

    final docRef = _firestore.collection(collectionName).doc();
    final donorRequestId = docRef.id;
    final now = DateTime.now().toIso8601String();

    final data = <String, dynamic>{
      'id': donorRequestId,

      'donor_uid': firebaseUser.uid,
      'user_id': firebaseUser.uid,
      'uid': firebaseUser.uid,

      'name': cleanName,
      'donor_name': cleanName,
      'donor_email': donorUser.email,

      'cnic': cleanCnic,
      'phone': cleanPhone,
      'donor_phone': cleanPhone,

      'guardian_name': cleanGuardianName,
      'guardian_phone': cleanGuardianPhone,

      'blood_group': cleanBloodGroup,
      'last_donated_date': lastDonatedDate,

      'current_location': cleanCurrentLocation,
      'location': cleanCurrentLocation,
      'city': cleanCity,
      'current_city': cleanCity,

      'latitude': latitude,
      'longitude': longitude,
      'coordinates': {
        'latitude': latitude,
        'longitude': longitude,
      },

      'is_available_now': isAvailableNow,
      'message': cleanMessage,

      'status': 'active',
      'request_status': 'active',
      'is_active': true,

      'created_at': now,
      'updated_at': now,
    };

    await docRef.set(data);

    return donorRequestId;
  }
}