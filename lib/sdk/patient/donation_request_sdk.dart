// lib/sdk/patient/donation_request_sdk.dart

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/sdk_exception.dart';

class NearbyDonorsResult {
  final Map<String, dynamic> bloodRequest;
  final List<Map<String, dynamic>> donors;

  NearbyDonorsResult({
    required this.bloodRequest,
    required this.donors,
  });
}

class DonationRequestSdk {
  DonationRequestSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String usersCollection = 'users';
  static const String bloodRequestsCollection = 'blood_requests';
  static const String donationRequestsCollection = 'donation_requests';
  static const String donorNotificationsCollection = 'donor_notifications';

  static const bool enableDebugLogs = true;

  static void _debug(String message) {
    if (!enableDebugLogs) return;
    debugPrint('[DonationRequestDebug] $message');
  }

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

    for (final part in parts) {
      final city = part.trim();
      final lowerCity = city.toLowerCase();

      if (city.isEmpty) continue;
      if (lowerCity == 'pakistan' || lowerCity == 'punjab') continue;
      if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(city)) continue;

      return city;
    }

    return parts.first.trim();
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

  static String? _unavailableUserReason({
    required String docId,
    required Map<String, dynamic> user,
  }) {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      return 'no_current_auth_user';
    }

    final String authUid = _readString(user, ['auth_uid']);
    final String uid = _readString(user, ['uid']);

    if (docId == currentUser.uid ||
        authUid == currentUser.uid ||
        uid == currentUser.uid) {
      return 'current_logged_in_user_hidden';
    }

    final String status = _readString(user, ['status']).toLowerCase();

    if (status.isNotEmpty && status != 'active') {
      return 'inactive_status_$status';
    }

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

    if ((latitude == null || longitude == null) &&
        address.isEmpty &&
        city.isEmpty) {
      return 'missing_location_lat_lng_address_city';
    }

    return null;
  }

  static String _debugUserLabel({
    required String docId,
    required Map<String, dynamic> user,
  }) {
    final name = _readString(user, ['name', 'user_name', 'full_name']);
    final phone = _readString(user, ['phone', 'phone_number']);
    final blood = _readString(
      user,
      ['blood_group', 'blood_type', 'bloodType', 'bloodGroup'],
    );
    final city = _readString(user, ['city', 'current_city', 'currentCity']);
    final address = _readString(
      user,
      ['address', 'location', 'current_location', 'currentLocation'],
    );
    final lat = _readDouble(
      user,
      ['latitude', 'lat', 'current_latitude', 'currentLatitude'],
    );
    final lng = _readDouble(
      user,
      ['longitude', 'lng', 'current_longitude', 'currentLongitude'],
    );

    return 'docId=$docId, name=$name, phone=$phone, blood=$blood, city=$city, address=$address, lat=$lat, lng=$lng';
  }

  static void _increaseCounter(
    Map<String, int> counters,
    String key,
  ) {
    counters[key] = (counters[key] ?? 0) + 1;
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

  static List<Map<String, dynamic>> _filterUsersByLocation({
    required QuerySnapshot<Map<String, dynamic>> snapshot,
    String? bloodGroup,
    double? requestLatitude,
    double? requestLongitude,
    String? requestCity,
    String? requestLocation,
    double radiusKm = 100,
  }) {
    final User? currentUser = _auth.currentUser;

    final String selectedBloodGroup = _normalizeBloodGroup(bloodGroup);
    final String selectedCity = requestCity?.trim() ?? '';
    final String selectedLocation = requestLocation?.trim() ?? '';

    final Map<String, int> counters = {};
    final List<Map<String, dynamic>> users = [];

    _debug(
      'FILTER START -> authUid=${currentUser?.uid}, totalUsers=${snapshot.docs.length}, '
      'optionalBloodFilter=$selectedBloodGroup, requestCity=$selectedCity, '
      'requestLocation=$selectedLocation, requestLat=$requestLatitude, '
      'requestLng=$requestLongitude, radiusKm=$radiusKm',
    );

    for (final doc in snapshot.docs) {
      final user = Map<String, dynamic>.from(doc.data());

      final unavailableReason = _unavailableUserReason(
        docId: doc.id,
        user: user,
      );

      if (unavailableReason != null) {
        _increaseCounter(counters, unavailableReason);
        _debug(
          'SKIP USER -> reason=$unavailableReason, ${_debugUserLabel(docId: doc.id, user: user)}',
        );
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
        _increaseCounter(counters, 'blood_group_mismatch');
        _debug(
          'SKIP USER -> reason=blood_group_mismatch, required=$selectedBloodGroup, userBlood=$userBloodGroup, ${_debugUserLabel(docId: doc.id, user: user)}',
        );
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
      double? distanceKm;

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

        shouldShowUser = distanceKm <= radiusKm;

        if (!shouldShowUser) {
          _increaseCounter(counters, 'outside_radius');
          _debug(
            'SKIP USER -> reason=outside_radius, distanceKm=${distanceKm.toStringAsFixed(2)}, radiusKm=$radiusKm, ${_debugUserLabel(docId: doc.id, user: user)}',
          );
        }
      } else {
        shouldShowUser = _textLocationMatches(
          user: user,
          requestCity: selectedCity,
          requestLocation: selectedLocation,
        );

        if (!shouldShowUser) {
          _increaseCounter(counters, 'location_text_mismatch_or_missing_coordinates');
          _debug(
            'SKIP USER -> reason=location_text_mismatch_or_missing_coordinates, '
            'requestCity=$selectedCity, requestLocation=$selectedLocation, '
            'requestLat=$requestLatitude, requestLng=$requestLongitude, '
            'userLat=$userLatitude, userLng=$userLongitude, '
            '${_debugUserLabel(docId: doc.id, user: user)}',
          );
        }
      }

      if (!shouldShowUser) {
        continue;
      }

      _increaseCounter(counters, 'included_users');

      _debug(
        'INCLUDE USER -> distanceKm=${distanceKm?.toStringAsFixed(2) ?? 'N/A'}, ${_debugUserLabel(docId: doc.id, user: user)}',
      );

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

    _debug(
      'FILTER END -> returnedUsers=${users.length}, counters=$counters',
    );

    return users;
  }

  static Future<Map<String, dynamic>> fetchBloodRequest({
    required String bloodRequestId,
  }) async {
    final User? currentUser = _auth.currentUser;

    _debug(
      'FETCH BLOOD REQUEST START -> authUid=${currentUser?.uid}, bloodRequestId=$bloodRequestId',
    );

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
        _debug(
          'FETCH BLOOD REQUEST FAILED -> request not found, bloodRequestId=$bloodRequestId',
        );
        throw SdkException('Blood request not found.');
      }

      final data = Map<String, dynamic>.from(snapshot.data()!);
      data['id'] = snapshot.id;
      data['blood_request_id'] = data['blood_request_id'] ?? snapshot.id;
      data['request_id'] = data['request_id'] ?? snapshot.id;

      _debug(
        'FETCH BLOOD REQUEST SUCCESS -> id=${snapshot.id}, '
        'bloodGroup=${_readString(data, [
          'blood_group',
          'bloodGroup',
          'patient_blood_group',
          'patientBloodGroup',
        ])}, '
        'location=${_readString(data, [
          'location',
          'address',
          'current_location',
          'currentLocation',
          'patient_location',
          'patientLocation',
        ])}, '
        'city=${_readString(data, [
          'city',
          'current_city',
          'currentCity',
          'patient_city',
          'patientCity',
        ])}, '
        'lat=${_readDouble(data, [
          'latitude',
          'lat',
          'patient_latitude',
          'patientLatitude',
        ])}, '
        'lng=${_readDouble(data, [
          'longitude',
          'lng',
          'patient_longitude',
          'patientLongitude',
        ])}, '
        'status=${_readString(data, ['status', 'request_status'])}',
      );

      return data;
    } on SdkException {
      rethrow;
    } on FirebaseException catch (e) {
      _debug(
        'FETCH BLOOD REQUEST FIREBASE ERROR -> code=${e.code}, message=${e.message}',
      );
      throw SdkException(e.message ?? 'Failed to fetch blood request.');
    } catch (e) {
      _debug('FETCH BLOOD REQUEST ERROR -> $e');
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

    _debug(
      'FETCH AVAILABLE USERS START -> authUid=${currentUser?.uid}, optionalBloodFilter=$bloodGroup, '
      'requestLat=$requestLatitude, requestLng=$requestLongitude, '
      'requestCity=$requestCity, requestLocation=$requestLocation, radiusKm=$radiusKm',
    );

    if (currentUser == null) {
      throw SdkException('Session not found. Please login again.');
    }

    try {
      final snapshot = await _firestore.collection(usersCollection).get();

      _debug(
        'USERS SNAPSHOT FETCHED -> totalUsers=${snapshot.docs.length}',
      );

      return _filterUsersByLocation(
        snapshot: snapshot,
        bloodGroup: bloodGroup,
        requestLatitude: requestLatitude,
        requestLongitude: requestLongitude,
        requestCity: requestCity,
        requestLocation: requestLocation,
        radiusKm: radiusKm,
      );
    } on FirebaseException catch (e) {
      _debug(
        'FETCH AVAILABLE USERS FIREBASE ERROR -> code=${e.code}, message=${e.message}',
      );
      throw SdkException(e.message ?? 'Failed to fetch nearby users.');
    } catch (e) {
      _debug('FETCH AVAILABLE USERS ERROR -> $e');
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
    _debug(
      'WATCH AVAILABLE USERS START -> optionalBloodFilter=$bloodGroup, '
      'requestLat=$requestLatitude, requestLng=$requestLongitude, '
      'requestCity=$requestCity, requestLocation=$requestLocation, radiusKm=$radiusKm',
    );

    return _firestore.collection(usersCollection).snapshots().map((snapshot) {
      _debug(
        'WATCH USERS SNAPSHOT -> totalUsers=${snapshot.docs.length}',
      );

      return _filterUsersByLocation(
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
    String? bloodGroup,
    double radiusKm = 100,
  }) async {
    _debug(
      'FETCH NEARBY USERS START -> bloodRequestId=$bloodRequestId, optionalBloodFilter=$bloodGroup, radiusKm=$radiusKm',
    );

    final bloodRequest = await fetchBloodRequest(
      bloodRequestId: bloodRequestId,
    );

    final String requestBloodGroup = _readString(
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

    _debug(
      'BLOOD REQUEST META FOR NEARBY -> requestBloodGroup=$requestBloodGroup, optionalBloodFilter=$bloodGroup, city=$city, '
      'fallbackCity=${city.isNotEmpty ? city : _extractCityFromLocation(location)}, '
      'location=$location, lat=$latitude, lng=$longitude',
    );

    final donors = await fetchAvailableDonors(
      bloodGroup: bloodGroup,
      requestLatitude: latitude,
      requestLongitude: longitude,
      requestCity: city.isNotEmpty ? city : _extractCityFromLocation(location),
      requestLocation: location,
      radiusKm: radiusKm,
    );

    _debug(
      'FETCH NEARBY USERS END -> returnedUsers=${donors.length}',
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

    _debug(
      'FETCH REQUEST HISTORY START -> authUid=${currentUser?.uid}, bloodRequestId=$bloodRequestId',
    );

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

      _debug(
        'FETCH REQUEST HISTORY END -> totalHistory=${list.length}',
      );

      return list;
    } on FirebaseException catch (e) {
      _debug(
        'FETCH REQUEST HISTORY FIREBASE ERROR -> code=${e.code}, message=${e.message}',
      );
      throw SdkException(e.message ?? 'Failed to fetch request history.');
    } catch (e) {
      _debug('FETCH REQUEST HISTORY ERROR -> $e');
      throw SdkException('Failed to fetch request history.');
    }
  }

  static Future<void> sendRequestToDonor({
    required String bloodRequestId,
    required String donorRequestId,
    required String message,
  }) async {
    final User? currentUser = _auth.currentUser;

    _debug(
      'SEND REQUEST START -> authUid=${currentUser?.uid}, bloodRequestId=$bloodRequestId, donorUserDocId=$donorRequestId',
    );

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
        _debug(
          'SEND REQUEST FAILED -> donor user doc not found, donorUserDocId=$donorRequestId',
        );
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

      _debug(
        'SEND REQUEST SUCCESS -> donationRequestId=${donationRequestRef.id}, donorNotificationId=${donorNotificationRef.id}, donorUid=$actualUserUid',
      );
    } on SdkException {
      rethrow;
    } on FirebaseException catch (e) {
      _debug(
        'SEND REQUEST FIREBASE ERROR -> code=${e.code}, message=${e.message}',
      );
      throw SdkException(e.message ?? 'Failed to send request.');
    } catch (e) {
      _debug('SEND REQUEST ERROR -> $e');
      throw SdkException('Failed to send request.');
    }
  }
}
