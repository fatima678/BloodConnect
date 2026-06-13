import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/sdk_exception.dart';

class DonorProfileSdk {
  DonorProfileSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String donorRolesCollection = 'users/roles/donors';

  static User _currentFirebaseUser() {
    final user = _auth.currentUser;

    if (user == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    return user;
  }

  static String _now() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceFirst('Z', '+00:00');
  }

  static String _firebaseErrorMessage(
    FirebaseException e,
    String fallback,
  ) {
    if (e.code == 'permission-denied') {
      return 'Permission denied. Please update Firestore rules for donor profile.';
    }

    return e.message ?? fallback;
  }

  static String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is Timestamp) {
        final date = value.toDate();
        final year = date.year.toString();
        final month = date.month.toString().padLeft(2, '0');
        final day = date.day.toString().padLeft(2, '0');

        return '$year-$month-$day';
      }

      if (value is DateTime) {
        final year = value.year.toString();
        final month = value.month.toString().padLeft(2, '0');
        final day = value.day.toString().padLeft(2, '0');

        return '$year-$month-$day';
      }

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return fallback;
  }

  static bool _readBool(
    Map<String, dynamic> data,
    List<String> keys, {
    bool fallback = true,
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value == true) return true;
      if (value == false) return false;

      if (value is int) return value == 1;

      if (value is String) {
        final text = value.toLowerCase().trim();

        if (text == 'true' || text == '1' || text == 'yes' || text == 'active') {
          return true;
        }

        if (text == 'false' ||
            text == '0' ||
            text == 'no' ||
            text == 'inactive') {
          return false;
        }
      }
    }

    return fallback;
  }

  static DonorProfileModel _mapSnapshotToProfile(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = Map<String, dynamic>.from(snapshot.data() ?? {});

    return DonorProfileModel.fromFirestore(
      uid: snapshot.id,
      data: data,
    );
  }

  static Future<DonorProfileModel> fetchProfile() async {
    final user = _currentFirebaseUser();

    try {
      final snapshot =
          await _firestore.collection(donorRolesCollection).doc(user.uid).get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw const SdkException(
          'Donor profile not found. Please login again.',
        );
      }

      final profile = _mapSnapshotToProfile(snapshot);

      if (profile.role != 'donor') {
        throw const SdkException(
          'Donor profile not found. Please login again.',
        );
      }

      return profile;
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to fetch donor profile.'),
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to fetch donor profile: $e');
    }
  }

  static Future<void> updateProfile({
    required String name,
    required String phone,
    required String location,
    required String? bloodGroup,
    required String? lastDonatedDate,
  }) async {
    final user = _currentFirebaseUser();

    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    final cleanLocation = location.trim();

    if (cleanName.isEmpty) {
      throw const SdkException('Name is required.');
    }

    if (cleanPhone.isEmpty) {
      throw const SdkException('Phone number is required.');
    }

    try {
      final docRef = _firestore.collection(donorRolesCollection).doc(user.uid);

      final snapshot = await docRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw const SdkException(
          'Donor profile not found. Please login again.',
        );
      }

      final data = Map<String, dynamic>.from(snapshot.data()!);
      final role = _readString(data, ['role']);

      if (role != 'donor') {
        throw const SdkException(
          'Donor profile not found. Please login again.',
        );
      }

      await docRef.update({
        'name': cleanName,
        'phone': cleanPhone,
        'location': cleanLocation,
        'blood_group': bloodGroup,
        'last_donated_date': lastDonatedDate,
        'updated_at': _now(),
      });
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to update donor profile.'),
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to update donor profile: $e');
    }
  }
}

class DonorProfileModel {
  final String uid;
  final String role;
  final String name;
  final String phone;
  final String location;
  final String bloodGroup;
  final String lastDonatedDate;
  final String photoUrl;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const DonorProfileModel({
    required this.uid,
    required this.role,
    required this.name,
    required this.phone,
    required this.location,
    required this.bloodGroup,
    required this.lastDonatedDate,
    required this.photoUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DonorProfileModel.fromFirestore({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return DonorProfileModel(
      uid: DonorProfileSdk._readString(
        data,
        ['uid', 'user_id', 'userId'],
        fallback: uid,
      ),
      role: DonorProfileSdk._readString(
        data,
        ['role'],
      ),
      name: DonorProfileSdk._readString(
        data,
        ['name', 'full_name', 'fullName', 'donor_name', 'donorName'],
      ),
      phone: DonorProfileSdk._readString(
        data,
        ['phone', 'phone_number', 'phoneNumber', 'donor_phone', 'donorPhone'],
      ),
      location: DonorProfileSdk._readString(
        data,
        ['location', 'address', 'city'],
      ),
      bloodGroup: DonorProfileSdk._readString(
        data,
        ['blood_group', 'bloodGroup'],
        fallback: '-',
      ),
      lastDonatedDate: DonorProfileSdk._readString(
        data,
        ['last_donated_date', 'lastDonatedDate'],
      ),
      photoUrl: DonorProfileSdk._readString(
        data,
        ['photo_url', 'photoUrl', 'profile_image', 'profileImage'],
      ),
      isActive: DonorProfileSdk._readBool(
        data,
        ['is_active', 'isActive', 'status'],
        fallback: true,
      ),
      createdAt: DonorProfileSdk._readString(
        data,
        ['created_at', 'createdAt'],
      ),
      updatedAt: DonorProfileSdk._readString(
        data,
        ['updated_at', 'updatedAt'],
      ),
    );
  }
}