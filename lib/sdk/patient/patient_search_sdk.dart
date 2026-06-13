// lib/sdk/search/patient_search_sdk.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_sdk.dart';
import '../core/sdk_exception.dart';

class PatientSearchSdk {
  PatientSearchSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String bloodBanksCollection = 'nearby_banks';

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

  static double? _readDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is num) {
        return value.toDouble();
      }

      final parsed = double.tryParse(value.toString());

      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> fetchBloodBanksForSearch({
    int limit = 100,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final patientUser = await AuthSdk.currentAppUser(expectedRole: 'patient');

    if (patientUser == null) {
      throw const SdkException('Patient profile not found. Please login again.');
    }

    try {
      final snapshot = await _firestore.collection(bloodBanksCollection).get();

      final List<Map<String, dynamic>> bloodBanks = [];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());

        final status = _readString(data, [
          'status',
        ]).toLowerCase();

        final bool isActive = status.isEmpty ||
            status == 'active' ||
            data['is_active'] == true;

        if (!isActive) continue;

        final hospitalName = _readString(data, [
          'hospital_name',
          'hospitalName',
          'name',
        ]);

        final address = _readString(data, [
          'address',
          'location',
        ]);

        final phoneNumber = _readString(data, [
          'phone_number',
          'phone',
          'contact',
          'contact_number',
        ]);

        final latitude = _readDouble(data, [
          'latitude',
          'lat',
        ]);

        final longitude = _readDouble(data, [
          'longitude',
          'lng',
        ]);

        bloodBanks.add({
          ...data,
          'id': doc.id,
          'hospital_name':
              hospitalName.isNotEmpty ? hospitalName : 'Blood Bank',
          'name': hospitalName.isNotEmpty ? hospitalName : 'Blood Bank',
          'address': address,
          'location': address,
          'phone_number': phoneNumber,
          'latitude': latitude,
          'longitude': longitude,
          'status': status.isNotEmpty ? status : 'active',
          'created_at': data['created_at'],
          'updated_at': data['updated_at'],
        });
      }

      bloodBanks.sort((a, b) {
        final bTime =
            (b['created_at'] ?? b['updated_at'] ?? '').toString();
        final aTime =
            (a['created_at'] ?? a['updated_at'] ?? '').toString();

        return bTime.compareTo(aTime);
      });

      if (bloodBanks.length > limit) {
        return bloodBanks.take(limit).toList();
      }

      return bloodBanks;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const SdkException(
          'Permission denied. Please update Firestore rules for nearby_banks.',
        );
      }

      throw SdkException(
        e.message ?? 'Failed to fetch blood banks.',
      );
    } catch (e) {
      throw SdkException('Failed to fetch blood banks: $e');
    }
  }
}