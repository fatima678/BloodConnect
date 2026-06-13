import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/sdk_exception.dart';

class DonorBloodBankSdk {
  DonorBloodBankSdk._();

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

      final parsed = double.tryParse(value.toString().trim());

      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  static bool _isActiveBank(Map<String, dynamic> data) {
    final status = _readString(data, ['status']);

    if (status.isEmpty) return true;

    return status.toLowerCase() == 'active';
  }

  static Future<List<Map<String, dynamic>>> fetchBloodBanks({
    int limit = 100,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    try {
      final snapshot = await _firestore
          .collection(bloodBanksCollection)
          .limit(limit)
          .get();

      final List<Map<String, dynamic>> banks = [];

      for (final doc in snapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());

        if (!_isActiveBank(data)) {
          continue;
        }

        final hospitalName = _readString(data, [
          'hospital_name',
          'name',
          'bank_name',
        ]);

        final address = _readString(data, [
          'address',
          'location',
        ]);

        final phoneNumber = _readString(data, [
          'phone_number',
          'phone',
          'contact',
        ]);

        final latitude = _readDouble(data, [
          'latitude',
          'lat',
        ]);

        final longitude = _readDouble(data, [
          'longitude',
          'lng',
          'long',
        ]);

        final status = _readString(data, ['status']);

        banks.add({
          ...data,
          'id': doc.id,
          'bank_id': doc.id,
          'hospital_name':
              hospitalName.isNotEmpty ? hospitalName : 'Unknown Hospital',
          'address': address,
          'phone_number': phoneNumber,
          'latitude': latitude,
          'longitude': longitude,
          'status': status.isNotEmpty ? status : 'active',
        });
      }

      banks.sort((a, b) {
        final aName = a['hospital_name']?.toString().toLowerCase() ?? '';
        final bName = b['hospital_name']?.toString().toLowerCase() ?? '';

        return aName.compareTo(bName);
      });

      return banks;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const SdkException(
          'Permission denied. Please update Firestore rules.',
        );
      }

      throw SdkException(e.message ?? 'Failed to fetch blood banks.');
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to fetch blood banks: $e');
    }
  }
}