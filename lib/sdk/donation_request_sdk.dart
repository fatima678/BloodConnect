// lib/sdk/general/donation_request_flow_sdk.dart

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/sdk_exception.dart';

class NearbyDonorsResult {
  final Map<String, dynamic> bloodRequest;
  final List<Map<String, dynamic>> donors;

  NearbyDonorsResult({
    required this.bloodRequest,
    required this.donors,
  });
}

class DonationRequestFlowSdk {
  DonationRequestFlowSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String usersCollection = 'users';
  static const String bloodRequestsCollection = 'blood_requests';
  static const String donationRequestsCollection = 'donation_requests';
  static const String donorNotificationsCollection = 'donor_notifications';
  static const String notificationsCollection = 'notifications';

  static String _now() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceFirst('Z', '+00:00');
  }

  static String _normalizeBloodGroup(dynamic value) {
    return value
            ?.toString()
            .trim()
            .toUpperCase()
            .replaceAll(' ', '')
            .replaceAll('POSITIVE', '+')
            .replaceAll('NEGATIVE', '-') ??
        '';
  }

  static String _normalizeText(dynamic value) {
    return value
            ?.toString()
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ') ??
        '';
  }

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

  static int _readDateMillis(Map<String, dynamic> data) {
    final value = data['created_at'] ?? data['updated_at'];

    if (value == null) return 0;

    if (value is Timestamp) {
      return value.toDate().millisecondsSinceEpoch;
    }

    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }

    final parsed = DateTime.tryParse(value.toString());

    return parsed?.millisecondsSinceEpoch ?? 0;
  }

  static double _degreeToRadian(double degree) {
    return degree * pi / 180;
  }

  static double _calculateDistanceKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const double earthRadiusKm = 6371;

    final double dLat = _degreeToRadian(endLatitude - startLatitude);
    final double dLng = _degreeToRadian(endLongitude - startLongitude);

    final double lat1 = _degreeToRadian(startLatitude);
    final double lat2 = _degreeToRadian(endLatitude);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLng / 2) * sin(dLng / 2) * cos(lat1) * cos(lat2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  static String _extractCityFromLocation(String location) {
    final text = location.trim();

    if (text.isEmpty) return '';

    final parts = text.split(',');

    if (parts.isEmpty) return text;

    return parts.first.trim();
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?>
      _currentUserDocSnapshot() async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return null;
    }

    final directSnapshot = await _firestore
        .collection(usersCollection)
        .doc(currentUser.uid)
        .get();

    if (directSnapshot.exists) {
      return directSnapshot;
    }

    final authUidSnapshot = await _firestore
        .collection(usersCollection)
        .where('auth_uid', isEqualTo: currentUser.uid)
        .limit(1)
        .get();

    if (authUidSnapshot.docs.isNotEmpty) {
      return authUidSnapshot.docs.first;
    }

    final uidSnapshot = await _firestore
        .collection(usersCollection)
        .where('uid', isEqualTo: currentUser.uid)
        .limit(1)
        .get();

    if (uidSnapshot.docs.isNotEmpty) {
      return uidSnapshot.docs.first;
    }

    return null;
  }

  static Future<Map<String, dynamic>> _currentUserProfile() async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw SdkException('Session not found. Please login again.');
    }

    final snapshot = await _currentUserDocSnapshot();

    if (snapshot == null || !snapshot.exists || snapshot.data() == null) {
      throw SdkException('User profile not found. Please complete your profile.');
    }

    final data = Map<String, dynamic>.from(snapshot.data()!);
    data['id'] = snapshot.id;
    data['uid'] = data['uid'] ?? currentUser.uid;
    data['auth_uid'] = data['auth_uid'] ?? currentUser.uid;

    return data;
  }

  static bool _textLocationMatches({
    required Map<String, dynamic> user,
    required String requestCity,
    required String requestLocation,
  }) {
    final String userCity = _normalizeText(
      _readString(
        user,
        [
          'city',
          'current_city',
          'currentCity',
        ],
      ),
    );

    final String userAddress = _normalizeText(
      _readString(
        user,
        [
          'address',
          'location',
          'current_location',
          'currentLocation',
          'location_name',
          'locationName',
        ],
      ),
    );

    final String normalizedRequestCity = _normalizeText(requestCity);
    final String normalizedRequestLocation = _normalizeText(requestLocation);

    if (normalizedRequestCity.isNotEmpty && userCity.isNotEmpty) {
      if (userCity == normalizedRequestCity ||
          userCity.contains(normalizedRequestCity) ||
          normalizedRequestCity.contains(userCity)) {
        return true;
      }
    }

    if (normalizedRequestCity.isNotEmpty && userAddress.isNotEmpty) {
      if (userAddress.contains(normalizedRequestCity)) {
        return true;
      }
    }

    if (normalizedRequestLocation.isNotEmpty && userAddress.isNotEmpty) {
      if (userAddress.contains(normalizedRequestLocation) ||
          normalizedRequestLocation.contains(userAddress)) {
        return true;
      }
    }

    return false;
  }

  static bool _isAvailableUser({
    required String docId,
    required Map<String, dynamic> user,
  }) {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return false;
    }

    final String authUid = _readString(user, ['auth_uid']);
    final String uid = _readString(user, ['uid']);

    if (docId == currentUser.uid ||
        authUid == currentUser.uid ||
        uid == currentUser.uid) {
      return false;
    }

    final String status = _readString(user, ['status']).toLowerCase();

    if (status.isNotEmpty && status != 'active') {
      return false;
    }

    final String address = _readString(
      user,
      [
        'address',
        'location',
        'current_location',
        'currentLocation',
        'location_name',
        'locationName',
      ],
    );

    final String city = _readString(
      user,
      [
        'city',
        'current_city',
        'currentCity',
      ],
    );

    final double? latitude = _readDouble(
      user,
      [
        'latitude',
        'lat',
        'current_latitude',
        'currentLatitude',
      ],
    );

    final double? longitude = _readDouble(
      user,
      [
        'longitude',
        'lng',
        'current_longitude',
        'currentLongitude',
      ],
    );

    if ((latitude == null || longitude == null) &&
        address.isEmpty &&
        city.isEmpty) {
      return false;
    }

    return true;
  }

  static Map<String, dynamic> _userToDonorMap({
    required String docId,
    required Map<String, dynamic> user,
    double? requestLatitude,
    double? requestLongitude,
  }) {
    final String actualUid = _readString(user, ['auth_uid']).isNotEmpty
        ? _readString(user, ['auth_uid'])
        : _readString(user, ['uid']).isNotEmpty
            ? _readString(user, ['uid'])
            : docId;

    final String bloodGroup = _readString(
      user,
      [
        'blood_group',
        'blood_type',
        'bloodType',
        'bloodGroup',
      ],
    );

    final String address = _readString(
      user,
      [
        'address',
        'location',
        'current_location',
        'currentLocation',
        'location_name',
        'locationName',
      ],
    );

    final String status = _readString(user, ['status']).isNotEmpty
        ? _readString(user, ['status'])
        : 'active';

    final double? userLatitude = _readDouble(
      user,
      [
        'latitude',
        'lat',
        'current_latitude',
        'currentLatitude',
      ],
    );

    final double? userLongitude = _readDouble(
      user,
      [
        'longitude',
        'lng',
        'current_longitude',
        'currentLongitude',
      ],
    );

    double? distanceKm;
    int? estimatedMinutes;

    if (requestLatitude != null &&
        requestLongitude != null &&
        userLatitude != null &&
        userLongitude != null) {
      distanceKm = _calculateDistanceKm(
        startLatitude: requestLatitude,
        startLongitude: requestLongitude,
        endLatitude: userLatitude,
        endLongitude: userLongitude,
      );

      estimatedMinutes = ((distanceKm / 35) * 60).round();

      if (estimatedMinutes <= 0) {
        estimatedMinutes = 1;
      }
    }

    return {
      ...user,
      'id': docId,
      'uid': actualUid,
      'user_id': actualUid,
      'donor_uid': actualUid,
      'donor_id': actualUid,
      'donor_request_id': docId,
      'request_id': docId,
      'name': _readString(
        user,
        [
          'name',
          'user_name',
          'full_name',
        ],
      ),
      'email': _readString(user, ['email']),
      'phone': _readString(
        user,
        [
          'phone',
          'phone_number',
        ],
      ),
      'blood_group': bloodGroup,
      'blood_type': bloodGroup,
      'current_location': address,
      'location': address,
      'address': address,
      'latitude': userLatitude,
      'longitude': userLongitude,
      'last_donated_date': _readString(
        user,
        [
          'last_donated_date',
          'lastDonatedDate',
        ],
      ),
      'status': status,
      'is_donor_available': true,
      if (distanceKm != null) 'distance_km': distanceKm,
      if (distanceKm != null) 'route_distance_km': distanceKm,
      if (estimatedMinutes != null) 'route_duration_min': estimatedMinutes,
      if (estimatedMinutes != null)
        'route_duration_seconds': estimatedMinutes * 60,
    };
  }

  static List<Map<String, dynamic>> _filterUsersByLocationAndBloodGroup({
    required QuerySnapshot<Map<String, dynamic>> snapshot,
    String? bloodGroup,
    double? requestLatitude,
    double? requestLongitude,
    String? requestCity,
    String? requestLocation,
    double radiusKm = 100,
  }) {
    final String selectedBloodGroup = _normalizeBloodGroup(bloodGroup);
    final String selectedCity = requestCity?.trim() ?? '';
    final String selectedLocation = requestLocation?.trim() ?? '';

    final List<Map<String, dynamic>> users = [];

    for (final doc in snapshot.docs) {
      final user = Map<String, dynamic>.from(doc.data());

      if (!_isAvailableUser(docId: doc.id, user: user)) {
        continue;
      }

      final String userBloodGroup = _normalizeBloodGroup(
        _readString(
          user,
          [
            'blood_group',
            'blood_type',
            'bloodType',
            'bloodGroup',
          ],
        ),
      );

      if (selectedBloodGroup.isNotEmpty &&
          userBloodGroup != selectedBloodGroup) {
        continue;
      }

      final double? userLatitude = _readDouble(
        user,
        [
          'latitude',
          'lat',
          'current_latitude',
          'currentLatitude',
        ],
      );

      final double? userLongitude = _readDouble(
        user,
        [
          'longitude',
          'lng',
          'current_longitude',
          'currentLongitude',
        ],
      );

      bool shouldShowUser = false;

      if (requestLatitude != null &&
          requestLongitude != null &&
          userLatitude != null &&
          userLongitude != null) {
        final double distanceKm = _calculateDistanceKm(
          startLatitude: requestLatitude,
          startLongitude: requestLongitude,
          endLatitude: userLatitude,
          endLongitude: userLongitude,
        );

        shouldShowUser = distanceKm <= radiusKm;
      } else {
        shouldShowUser = _textLocationMatches(
          user: user,
          requestCity: selectedCity,
          requestLocation: selectedLocation,
        );
      }

      if (!shouldShowUser) {
        continue;
      }

      users.add(
        _userToDonorMap(
          docId: doc.id,
          user: user,
          requestLatitude: requestLatitude,
          requestLongitude: requestLongitude,
        ),
      );
    }

    users.sort((a, b) {
      final dynamic aDistance = a['route_distance_km'];
      final dynamic bDistance = b['route_distance_km'];

      if (aDistance == null && bDistance == null) {
        return (a['name']?.toString() ?? '').compareTo(
          b['name']?.toString() ?? '',
        );
      }

      if (aDistance == null) return 1;
      if (bDistance == null) return -1;

      final double aValue = double.tryParse(aDistance.toString()) ?? 999999;
      final double bValue = double.tryParse(bDistance.toString()) ?? 999999;

      return aValue.compareTo(bValue);
    });

    return users;
  }

  static Future<Map<String, dynamic>> fetchBloodRequest({
    required String bloodRequestId,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw SdkException('Session not found. Please login again.');
    }

    if (bloodRequestId.trim().isEmpty) {
      throw SdkException('Blood request ID is required.');
    }

    try {
      final snapshot = await _firestore
          .collection(bloodRequestsCollection)
          .doc(bloodRequestId.trim())
          .get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw SdkException('Blood request not found.');
      }

      final data = Map<String, dynamic>.from(snapshot.data()!);
      data['id'] = snapshot.id;
      data['blood_request_id'] = data['blood_request_id'] ?? snapshot.id;
      data['request_id'] = data['request_id'] ?? snapshot.id;

      return data;
    } on SdkException {
      rethrow;
    } on FirebaseException catch (e) {
      throw SdkException(e.message ?? 'Failed to fetch blood request.');
    } catch (e) {
      throw SdkException('Failed to fetch blood request.');
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAvailableDonors({
    String? bloodGroup,
    double? requestLatitude,
    double? requestLongitude,
    String? requestCity,
    String? requestLocation,
    double radiusKm = 100,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw SdkException('Session not found. Please login again.');
    }

    try {
      final snapshot = await _firestore.collection(usersCollection).get();

      return _filterUsersByLocationAndBloodGroup(
        snapshot: snapshot,
        bloodGroup: bloodGroup,
        requestLatitude: requestLatitude,
        requestLongitude: requestLongitude,
        requestCity: requestCity,
        requestLocation: requestLocation,
        radiusKm: radiusKm,
      );
    } on FirebaseException catch (e) {
      throw SdkException(e.message ?? 'Failed to fetch nearby users.');
    } catch (e) {
      throw SdkException('Failed to fetch nearby users.');
    }
  }

  static Stream<List<Map<String, dynamic>>> watchAvailableDonors({
    String? bloodGroup,
    double? requestLatitude,
    double? requestLongitude,
    String? requestCity,
    String? requestLocation,
    double radiusKm = 100,
  }) {
    return _firestore.collection(usersCollection).snapshots().map((snapshot) {
      return _filterUsersByLocationAndBloodGroup(
        snapshot: snapshot,
        bloodGroup: bloodGroup,
        requestLatitude: requestLatitude,
        requestLongitude: requestLongitude,
        requestCity: requestCity,
        requestLocation: requestLocation,
        radiusKm: radiusKm,
      );
    });
  }

  static Future<NearbyDonorsResult> fetchNearbyDonors({
    required String bloodRequestId,
    double radiusKm = 100,
  }) async {
    final bloodRequest = await fetchBloodRequest(
      bloodRequestId: bloodRequestId,
    );

    final String bloodGroup = _readString(
      bloodRequest,
      [
        'blood_group',
        'bloodGroup',
        'patient_blood_group',
        'patientBloodGroup',
      ],
    );

    final String location = _readString(
      bloodRequest,
      [
        'location',
        'address',
        'current_location',
        'currentLocation',
        'patient_location',
        'patientLocation',
      ],
    );

    final String city = _readString(
      bloodRequest,
      [
        'city',
        'current_city',
        'currentCity',
        'patient_city',
        'patientCity',
      ],
    );

    final double? latitude = _readDouble(
      bloodRequest,
      [
        'latitude',
        'lat',
        'patient_latitude',
        'patientLatitude',
      ],
    );

    final double? longitude = _readDouble(
      bloodRequest,
      [
        'longitude',
        'lng',
        'patient_longitude',
        'patientLongitude',
      ],
    );

    final donors = await fetchAvailableDonors(
      bloodGroup: bloodGroup,
      requestLatitude: latitude,
      requestLongitude: longitude,
      requestCity: city.isNotEmpty ? city : _extractCityFromLocation(location),
      requestLocation: location,
      radiusKm: radiusKm,
    );

    return NearbyDonorsResult(
      bloodRequest: bloodRequest,
      donors: donors,
    );
  }

  static Future<List<Map<String, dynamic>>> fetchRequestHistory({
    String? bloodRequestId,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw SdkException('Session not found. Please login again.');
    }

    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(donationRequestsCollection)
          .where('patient_uid', isEqualTo: currentUser.uid);

      if (bloodRequestId != null && bloodRequestId.trim().isNotEmpty) {
        query = query.where(
          'blood_request_id',
          isEqualTo: bloodRequestId.trim(),
        );
      }

      final snapshot = await query.get();

      final List<Map<String, dynamic>> list = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['donation_request_id'] = data['donation_request_id'] ?? doc.id;
        return data;
      }).toList();

      list.sort((a, b) {
        final String aDate = a['created_at']?.toString() ?? '';
        final String bDate = b['created_at']?.toString() ?? '';
        return bDate.compareTo(aDate);
      });

      return list;
    } on FirebaseException catch (e) {
      throw SdkException(e.message ?? 'Failed to fetch request history.');
    } catch (e) {
      throw SdkException('Failed to fetch request history.');
    }
  }

  static Future<void> sendRequestToDonor({
    required String bloodRequestId,
    required String donorRequestId,
    required String message,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw SdkException('Session not found. Please login again.');
    }

    if (bloodRequestId.trim().isEmpty) {
      throw SdkException('Blood request ID is required.');
    }

    if (donorRequestId.trim().isEmpty) {
      throw SdkException('User ID is required.');
    }

    try {
      final bloodRequest = await fetchBloodRequest(
        bloodRequestId: bloodRequestId,
      );

      final userSnapshot = await _firestore
          .collection(usersCollection)
          .doc(donorRequestId.trim())
          .get();

      if (!userSnapshot.exists || userSnapshot.data() == null) {
        throw SdkException('User not found.');
      }

      final user = Map<String, dynamic>.from(userSnapshot.data()!);

      final String actualUserUid = _readString(user, ['auth_uid']).isNotEmpty
          ? _readString(user, ['auth_uid'])
          : _readString(user, ['uid']).isNotEmpty
              ? _readString(user, ['uid'])
              : userSnapshot.id;

      final String userBloodGroup = _readString(
        user,
        [
          'blood_group',
          'blood_type',
          'bloodType',
          'bloodGroup',
        ],
      );

      final String userName = _readString(
        user,
        [
          'name',
          'user_name',
          'full_name',
        ],
      );

      final String userPhone = _readString(
        user,
        [
          'phone',
          'phone_number',
        ],
      );

      final String patientName = _readString(
        bloodRequest,
        [
          'patient_name',
          'patientName',
        ],
      );

      final String bloodGroup = _readString(
        bloodRequest,
        [
          'blood_group',
          'bloodGroup',
        ],
      );

      final String now = _now();

      final donationRequestRef =
          _firestore.collection(donationRequestsCollection).doc();

      final donorNotificationRef =
          _firestore.collection(donorNotificationsCollection).doc();

      final Map<String, dynamic> donationRequestData = {
        'donation_request_id': donationRequestRef.id,
        'blood_request_id': bloodRequestId.trim(),
        'request_id': bloodRequestId.trim(),

        'patient_uid': currentUser.uid,
        'patient_id': currentUser.uid,
        'patient_name': patientName,
        'patient_blood_group': bloodGroup,

        'donor_uid': actualUserUid,
        'donor_id': actualUserUid,
        'donor_request_id': userSnapshot.id,
        'donor_name': userName,
        'donor_phone': userPhone,
        'donor_blood_group': userBloodGroup,

        'message': message.trim().isEmpty
            ? 'Patient needs blood urgently.'
            : message.trim(),

        'status': 'pending',
        'request_status': 'pending',
        'phone_visible_to_patient': false,
        'created_at': now,
        'updated_at': now,
      };

      final Map<String, dynamic> donorNotificationData = {
        'notification_id': donorNotificationRef.id,
        'donation_request_id': donationRequestRef.id,
        'blood_request_id': bloodRequestId.trim(),

        'patient_uid': currentUser.uid,
        'patient_id': currentUser.uid,
        'patient_name': patientName,
        'patient_blood_group': bloodGroup,

        'donor_uid': actualUserUid,
        'donor_id': actualUserUid,

        'title': 'New blood request',
        'message': '$patientName needs $bloodGroup blood.',
        'type': 'blood_request',
        'is_read': false,
        'created_at': now,
        'updated_at': now,
      };

      final batch = _firestore.batch();

      batch.set(donationRequestRef, donationRequestData);
      batch.set(donorNotificationRef, donorNotificationData);

      await batch.commit();
    } on SdkException {
      rethrow;
    } on FirebaseException catch (e) {
      throw SdkException(e.message ?? 'Failed to send request.');
    } catch (e) {
      throw SdkException('Failed to send request.');
    }
  }

  static Stream<List<Map<String, dynamic>>> watchIncomingRequestsForCurrentUser() {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(donationRequestsCollection)
        .where('donor_uid', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['donation_request_id'] = data['donation_request_id'] ?? doc.id;
        return data;
      }).toList();

      requests.sort((a, b) {
        return _readDateMillis(b).compareTo(_readDateMillis(a));
      });

      return requests;
    });
  }

  static Stream<List<Map<String, dynamic>>> watchAcceptedDonorsForCurrentUser() {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(donationRequestsCollection)
        .where('patient_uid', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) {
      final requests = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['donation_request_id'] = data['donation_request_id'] ?? doc.id;
        return data;
      }).where((item) {
        final status = _readString(item, ['status', 'request_status'])
            .toLowerCase();

        return status == 'accepted';
      }).toList();

      requests.sort((a, b) {
        return _readDateMillis(b).compareTo(_readDateMillis(a));
      });

      return requests;
    });
  }

  static Future<void> rejectRequest({
    required String donationRequestId,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw SdkException('Session not found. Please login again.');
    }

    if (donationRequestId.trim().isEmpty) {
      throw SdkException('Donation request ID is required.');
    }

    try {
      final requestRef = _firestore
          .collection(donationRequestsCollection)
          .doc(donationRequestId.trim());

      final snapshot = await requestRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw SdkException('Donation request not found.');
      }

      final data = Map<String, dynamic>.from(snapshot.data()!);
      final donorUid = _readString(data, ['donor_uid', 'donor_id']);

      if (donorUid.isNotEmpty && donorUid != currentUser.uid) {
        throw SdkException('You are not allowed to reject this request.');
      }

      await requestRef.set(
        {
          'status': 'rejected',
          'request_status': 'rejected',
          'rejected_at': _now(),
          'updated_at': _now(),
        },
        SetOptions(merge: true),
      );
    } on SdkException {
      rethrow;
    } on FirebaseException catch (e) {
      throw SdkException(e.message ?? 'Failed to reject request.');
    } catch (e) {
      throw SdkException('Failed to reject request.');
    }
  }

  static Future<void> acceptRequestWithConsent({
    required String donationRequestId,
    required String donorMessage,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw SdkException('Session not found. Please login again.');
    }

    if (donationRequestId.trim().isEmpty) {
      throw SdkException('Donation request ID is required.');
    }

    try {
      final donorProfile = await _currentUserProfile();

      final requestRef = _firestore
          .collection(donationRequestsCollection)
          .doc(donationRequestId.trim());

      final requestSnapshot = await requestRef.get();

      if (!requestSnapshot.exists || requestSnapshot.data() == null) {
        throw SdkException('Donation request not found.');
      }

      final request = Map<String, dynamic>.from(requestSnapshot.data()!);

      final donorUid = _readString(request, ['donor_uid', 'donor_id']);

      if (donorUid.isNotEmpty && donorUid != currentUser.uid) {
        throw SdkException('You are not allowed to accept this request.');
      }

      final patientUid = _readString(
        request,
        ['patient_uid', 'patient_id', 'recipient_uid', 'recipient_id'],
      );

      if (patientUid.isEmpty) {
        throw SdkException('Recipient ID is missing in request.');
      }

      final bloodRequestId = _readString(
        request,
        ['blood_request_id', 'request_id'],
      );

      if (bloodRequestId.isEmpty) {
        throw SdkException('Blood request ID is missing in donation request.');
      }

      final donorName = _readString(
        donorProfile,
        ['name', 'user_name', 'full_name'],
      );

      final donorPhone = _readString(
        donorProfile,
        ['phone', 'phone_number'],
      );

      final donorEmail = _readString(donorProfile, ['email']);

      final donorBloodGroup = _readString(
        donorProfile,
        ['blood_group', 'blood_type', 'bloodType', 'bloodGroup'],
      );

      final donorLocation = _readString(
        donorProfile,
        ['address', 'location', 'current_location', 'currentLocation'],
      );

      final patientName = _readString(
        request,
        ['patient_name', 'patientName'],
      );

      final patientBloodGroup = _readString(
        request,
        ['patient_blood_group', 'blood_group', 'bloodGroup'],
      );

      final notificationRef =
          _firestore.collection(notificationsCollection).doc();

      final bloodRequestRef = _firestore
          .collection(bloodRequestsCollection)
          .doc(bloodRequestId.trim());

      final now = _now();

      final batch = _firestore.batch();

      batch.set(
        requestRef,
        {
          'status': 'accepted',
          'request_status': 'accepted',
          'accepted_at': now,
          'updated_at': now,

          'phone_visible_to_patient': true,
          'donor_consent_accepted': true,
          'donor_consent_accepted_at': now,
          'donor_consent_message': donorMessage.trim(),

          'donor_uid': currentUser.uid,
          'donor_id': currentUser.uid,
          'donor_name': donorName,
          'donor_phone': donorPhone,
          'donor_email': donorEmail,
          'donor_blood_group': donorBloodGroup,
          'donor_location': donorLocation,
        },
        SetOptions(merge: true),
      );

      batch.set(
        bloodRequestRef,
        {
          'status': 'accepted',
          'request_status': 'accepted',
          'is_active': false,

          'accepted_at': now,
          'accepted_donation_request_id': donationRequestId.trim(),

          'accepted_donor_id': currentUser.uid,
          'accepted_donor_uid': currentUser.uid,
          'accepted_donor_name': donorName,
          'accepted_donor_phone': donorPhone,
          'accepted_donor_email': donorEmail,
          'accepted_donor_blood_group': donorBloodGroup,
          'accepted_donor_location': donorLocation,

          'updated_at': now,
        },
        SetOptions(merge: true),
      );

      batch.set(notificationRef, {
        'notification_id': notificationRef.id,
        'recipient_uid': patientUid,
        'patient_uid': patientUid,
        'role': 'patient',

        'donation_request_id': donationRequestId.trim(),
        'blood_request_id': bloodRequestId.trim(),
        'type': 'donor_request_accepted',

        'title': 'Donor accepted your request',
        'message': donorName.isNotEmpty
            ? '$donorName accepted your $patientBloodGroup blood request.'
            : 'A donor accepted your blood request.',

        'patient_name': patientName,
        'patient_blood_group': patientBloodGroup,

        'donor_uid': currentUser.uid,
        'donor_name': donorName,
        'donor_phone': donorPhone,
        'donor_email': donorEmail,
        'donor_blood_group': donorBloodGroup,
        'donor_location': donorLocation,

        'is_read': false,
        'created_at': now,
        'updated_at': now,
      });

      await batch.commit();
    } on SdkException {
      rethrow;
    } on FirebaseException catch (e) {
      throw SdkException(e.message ?? 'Failed to accept request.');
    } catch (e) {
      throw SdkException('Failed to accept request.');
    }
  }
}