// lib/sdk/donation/donation_request_sdk.dart

import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_sdk.dart';
import '../core/sdk_exception.dart';

class NearbyDonorsResult {
  final Map<String, dynamic> bloodRequest;
  final List<Map<String, dynamic>> donors;

  const NearbyDonorsResult({
    required this.bloodRequest,
    required this.donors,
  });
}

class DonationRequestSdk {
  DonationRequestSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String bloodRequestsCollection = 'blood_requests';
  static const String donorRequestsCollection = 'donor_requests';
  static const String donationRequestsCollection = 'donation_requests';
  static const String donorNotificationsCollection = 'donor_notifications';

  /*
   * Google Routes API key.
   * Replace this with your actual Google Maps API key.
   *
   * Required API:
   * Google Routes API must be enabled in Google Cloud Console.
   */
  static const String googleRoutesApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

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

  static String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return null;
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

  static double _degreeToRadian(double degree) {
    return degree * pi / 180;
  }

  /*
   * This is straight-line distance.
   * Now this is used only as a pre-check / backup.
   * Final displayed distance will come from Google Routes API.
   */
  static double _distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double earthRadius = 6371;

    final double dLat = _degreeToRadian(lat2 - lat1);
    final double dLng = _degreeToRadian(lng2 - lng1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreeToRadian(lat1)) *
            cos(_degreeToRadian(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return double.parse((earthRadius * c).toStringAsFixed(2));
  }

  static int _parseGoogleDurationSeconds(dynamic value) {
    if (value == null) return 0;

    final text = value.toString().trim();

    if (text.isEmpty) return 0;

    final cleanText = text.endsWith('s')
        ? text.substring(0, text.length - 1)
        : text;

    final parsed = double.tryParse(cleanText);

    if (parsed == null) return 0;

    return parsed.round();
  }

  static Future<List<Map<String, dynamic>>> _fetchGoogleRouteMatrix({
    required double originLat,
    required double originLng,
    required List<Map<String, dynamic>> donors,
  }) async {
    if (googleRoutesApiKey.trim().isEmpty ||
        googleRoutesApiKey == 'YOUR_GOOGLE_MAPS_API_KEY') {
      throw const SdkException('Google Routes API key is missing.');
    }

    if (donors.isEmpty) {
      return [];
    }

    final List<Map<String, dynamic>> updatedDonors =
        donors.map((donor) => Map<String, dynamic>.from(donor)).toList();

    /*
     * Google Routes API Compute Route Matrix supports multiple destinations.
     * To keep request size safe, we process donors in chunks.
     */
    const int chunkSize = 25;

    for (int start = 0; start < updatedDonors.length; start += chunkSize) {
      final int end = min(start + chunkSize, updatedDonors.length);
      final List<Map<String, dynamic>> chunk = updatedDonors.sublist(
        start,
        end,
      );

      final destinations = chunk.map((donor) {
        final double donorLat = donor['_donor_lat'] as double;
        final double donorLng = donor['_donor_lng'] as double;

        return {
          'waypoint': {
            'location': {
              'latLng': {
                'latitude': donorLat,
                'longitude': donorLng,
              },
            },
          },
        };
      }).toList();

      final requestBody = {
        'origins': [
          {
            'waypoint': {
              'location': {
                'latLng': {
                  'latitude': originLat,
                  'longitude': originLng,
                },
              },
            },
          },
        ],
        'destinations': destinations,
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
      };

      final response = await http.post(
        Uri.parse(
          'https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix',
        ),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': googleRoutesApiKey,
          'X-Goog-FieldMask':
              'originIndex,destinationIndex,status,condition,distanceMeters,duration',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('Google Routes API error: ${response.statusCode}');
        debugPrint(response.body);

        throw SdkException(
          'Failed to calculate road route distance. Google API error ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! List) {
        throw const SdkException('Invalid Google Routes API response.');
      }

      for (final item in decoded) {
        if (item is! Map) continue;

        final int? destinationIndex = item['destinationIndex'] is int
            ? item['destinationIndex'] as int
            : int.tryParse(item['destinationIndex']?.toString() ?? '');

        if (destinationIndex == null) continue;
        if (destinationIndex < 0 || destinationIndex >= chunk.length) continue;

        final dynamic status = item['status'];
        final String statusCode = status is Map
            ? status['code']?.toString() ?? ''
            : '';

        /*
         * If status code exists and is not 0, route failed.
         * In that case donor will not be used for route distance.
         */
        if (statusCode.isNotEmpty && statusCode != '0') {
          continue;
        }

        final int? distanceMeters = item['distanceMeters'] is int
            ? item['distanceMeters'] as int
            : int.tryParse(item['distanceMeters']?.toString() ?? '');

        if (distanceMeters == null) continue;

        final int durationSeconds = _parseGoogleDurationSeconds(
          item['duration'],
        );

        final double routeDistanceKm = double.parse(
          (distanceMeters / 1000).toStringAsFixed(2),
        );

        final int routeDurationMin = durationSeconds <= 0
            ? 0
            : max(1, (durationSeconds / 60).round());

        final int originalIndex = start + destinationIndex;

        updatedDonors[originalIndex]['distance_km'] = routeDistanceKm;
        updatedDonors[originalIndex]['distanceKm'] = routeDistanceKm;
        updatedDonors[originalIndex]['distance'] = routeDistanceKm;

        updatedDonors[originalIndex]['route_distance_km'] = routeDistanceKm;
        updatedDonors[originalIndex]['route_distance_meters'] = distanceMeters;
        updatedDonors[originalIndex]['route_duration_seconds'] =
            durationSeconds;
        updatedDonors[originalIndex]['route_duration_min'] = routeDurationMin;
        updatedDonors[originalIndex]['distance_type'] = 'road_route';
        updatedDonors[originalIndex]['travel_mode'] = 'DRIVE';
      }
    }

    updatedDonors.removeWhere((donor) {
      final distance = double.tryParse(
        donor['route_distance_km']?.toString() ?? '',
      );

      return distance == null;
    });

    return updatedDonors;
  }

  static Future<Map<String, dynamic>> getBloodRequestById(
    String bloodRequestId,
  ) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final cleanId = bloodRequestId.trim();

    if (cleanId.isEmpty) {
      throw const SdkException('Blood request ID is missing.');
    }

    final snapshot = await _firestore
        .collection(bloodRequestsCollection)
        .doc(cleanId)
        .get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw const SdkException('Blood request not found.');
    }

    final data = Map<String, dynamic>.from(snapshot.data()!);
    data['id'] = data['id'] ?? snapshot.id;
    data['request_id'] = data['request_id'] ?? snapshot.id;

    final patientUid = data['patient_uid']?.toString();

    if (patientUid != firebaseUser.uid) {
      throw const SdkException('You are not allowed to access this request.');
    }

    return data;
  }

  static Future<NearbyDonorsResult> fetchNearbyDonors({
    required String bloodRequestId,
    required double radiusKm,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final patientUser = await AuthSdk.currentAppUser(expectedRole: 'patient');

    if (patientUser == null) {
      throw const SdkException('Patient profile not found. Please login again.');
    }

    final bloodRequest = await getBloodRequestById(bloodRequestId);

    final String bloodGroup = _normalizeBloodGroup(
      _readString(bloodRequest, [
        'blood_group',
        'bloodGroup',
        'patient_blood_group',
        'patientBloodGroup',
      ]),
    );

    final double? patientLat = _readDouble(bloodRequest, [
      'latitude',
      'lat',
    ]);

    final double? patientLng = _readDouble(bloodRequest, [
      'longitude',
      'lng',
    ]);

    if (bloodGroup.isEmpty) {
      throw const SdkException('Patient blood group not found.');
    }

    if (patientLat == null || patientLng == null) {
      throw const SdkException('Patient location not found.');
    }

    final donorSnapshot =
        await _firestore.collection(donorRequestsCollection).get();

    final List<Map<String, dynamic>> preFilteredDonors = [];

    for (final doc in donorSnapshot.docs) {
      final donor = Map<String, dynamic>.from(doc.data());

      donor['id'] = donor['id'] ?? doc.id;
      donor['donor_request_id'] = donor['donor_request_id'] ?? doc.id;
      donor['request_id'] = donor['request_id'] ?? doc.id;

      final String donorStatus =
          donor['status']?.toString().toLowerCase().trim() ?? '';

      final bool isActive = donor['is_active'] == true ||
          donorStatus == 'active' ||
          donorStatus == 'available';

      if (!isActive) continue;

      final String donorBloodGroup = _normalizeBloodGroup(
        _readString(donor, [
          'blood_group',
          'bloodGroup',
          'donor_blood_group',
          'donorBloodGroup',
        ]),
      );

      if (donorBloodGroup != bloodGroup) continue;

      final double? donorLat = _readDouble(donor, [
        'latitude',
        'lat',
      ]);

      final double? donorLng = _readDouble(donor, [
        'longitude',
        'lng',
      ]);

      if (donorLat == null || donorLng == null) continue;

      /*
       * This rough distance is only used to reduce Google API calls.
       * It is NOT displayed as final nearby distance.
       *
       * We allow a wider pre-filter than selected radius because road route
       * distance can be longer than straight-line distance.
       */
      final double roughDistanceKm = _distanceKm(
        patientLat,
        patientLng,
        donorLat,
        donorLng,
      );

      final double preFilterRadiusKm = max(radiusKm * 2, radiusKm + 10);

      if (roughDistanceKm > preFilterRadiusKm) continue;

      donor['_donor_lat'] = donorLat;
      donor['_donor_lng'] = donorLng;

      donor['rough_distance_km'] = roughDistanceKm;
      donor['straight_line_distance_km'] = roughDistanceKm;

      donor['donor_blood_group'] = donorBloodGroup;
      donor['blood_group'] = donorBloodGroup;

      preFilteredDonors.add(donor);
    }

    final List<Map<String, dynamic>> routeDonors =
        await _fetchGoogleRouteMatrix(
      originLat: patientLat,
      originLng: patientLng,
      donors: preFilteredDonors,
    );

    final List<Map<String, dynamic>> donors = [];

    for (final donor in routeDonors) {
      final double routeDistanceKm = double.tryParse(
            donor['route_distance_km']?.toString() ?? '',
          ) ??
          999999;

      if (routeDistanceKm > radiusKm) continue;

      donor.remove('_donor_lat');
      donor.remove('_donor_lng');

      donors.add(donor);
    }

    donors.sort((a, b) {
      final double aDistance =
          double.tryParse(a['route_distance_km']?.toString() ?? '') ?? 999999;
      final double bDistance =
          double.tryParse(b['route_distance_km']?.toString() ?? '') ?? 999999;

      return aDistance.compareTo(bDistance);
    });

    return NearbyDonorsResult(
      bloodRequest: bloodRequest,
      donors: donors,
    );
  }

  static Future<List<Map<String, dynamic>>> fetchRequestHistory({
    String? bloodRequestId,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    Query<Map<String, dynamic>> query = _firestore
        .collection(donationRequestsCollection)
        .where('patient_uid', isEqualTo: firebaseUser.uid);

    if (bloodRequestId != null && bloodRequestId.trim().isNotEmpty) {
      query = query.where(
        'blood_request_id',
        isEqualTo: bloodRequestId.trim(),
      );
    }

    final snapshot = await query.get();

    final List<Map<String, dynamic>> history = [];

    for (final doc in snapshot.docs) {
      final item = Map<String, dynamic>.from(doc.data());

      item['id'] = item['id'] ?? doc.id;
      item['donation_request_id'] = item['donation_request_id'] ?? doc.id;

      history.add(item);
    }

    history.sort((a, b) {
      return (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? '');
    });

    return history;
  }

  static Future<String> sendRequestToDonor({
    required String bloodRequestId,
    required String donorRequestId,
    required String message,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final patientUser = await AuthSdk.currentAppUser(expectedRole: 'patient');

    if (patientUser == null) {
      throw const SdkException('Patient profile not found. Please login again.');
    }

    final cleanBloodRequestId = bloodRequestId.trim();
    final cleanDonorRequestId = donorRequestId.trim();

    if (cleanBloodRequestId.isEmpty) {
      throw const SdkException('Blood request ID is missing.');
    }

    if (cleanDonorRequestId.isEmpty) {
      throw const SdkException('Donor request ID is missing.');
    }

    final bloodRequestRef = _firestore
        .collection(bloodRequestsCollection)
        .doc(cleanBloodRequestId);

    final donorRequestRef = _firestore
        .collection(donorRequestsCollection)
        .doc(cleanDonorRequestId);

    final bloodRequestSnapshot = await bloodRequestRef.get();

    if (!bloodRequestSnapshot.exists || bloodRequestSnapshot.data() == null) {
      throw const SdkException('Blood request not found.');
    }

    final donorRequestSnapshot = await donorRequestRef.get();

    if (!donorRequestSnapshot.exists || donorRequestSnapshot.data() == null) {
      throw const SdkException('Donor request not found.');
    }

    final bloodRequest = Map<String, dynamic>.from(
      bloodRequestSnapshot.data()!,
    );

    final donorRequest = Map<String, dynamic>.from(
      donorRequestSnapshot.data()!,
    );

    if (bloodRequest['patient_uid']?.toString() != firebaseUser.uid) {
      throw const SdkException('You are not allowed to send this request.');
    }

    final String bloodRequestStatus =
        bloodRequest['status']?.toString().toLowerCase().trim() ?? '';

    if (bloodRequestStatus != 'pending') {
      throw const SdkException('This blood request is not pending.');
    }

    final String patientBloodGroup = _normalizeBloodGroup(
      bloodRequest['blood_group'],
    );

    final String donorBloodGroup = _normalizeBloodGroup(
      donorRequest['blood_group'],
    );

    if (patientBloodGroup != donorBloodGroup) {
      throw const SdkException(
        'You can send request only to matching blood group donors.',
      );
    }

    /*
     * Secure existing request check:
     * patient_uid filter zaroori hai, warna Firestore rules query ko deny kar sakti hain.
     */
    final existingSnapshot = await _firestore
        .collection(donationRequestsCollection)
        .where('blood_request_id', isEqualTo: cleanBloodRequestId)
        .where('patient_uid', isEqualTo: firebaseUser.uid)
        .get();

    for (final doc in existingSnapshot.docs) {
      final item = doc.data();

      if (item['donor_request_id']?.toString() == cleanDonorRequestId) {
        throw const SdkException('Request already sent to this donor.');
      }
    }

    final docRef = _firestore.collection(donationRequestsCollection).doc();
    final donationRequestId = docRef.id;

    final notificationRef =
        _firestore.collection(donorNotificationsCollection).doc();

    final notificationId = notificationRef.id;

    final now = DateTime.now().toIso8601String();

    final String donorUid = donorRequest['donor_uid']?.toString() ??
        donorRequest['uid']?.toString() ??
        donorRequest['user_id']?.toString() ??
        '';

    if (donorUid.trim().isEmpty) {
      throw const SdkException('Donor UID missing.');
    }

    final String patientName =
        bloodRequest['patient_name']?.toString().trim().isNotEmpty == true
            ? bloodRequest['patient_name'].toString()
            : 'Patient';

    final String hospitalName =
        bloodRequest['hospital_name']?.toString().trim().isNotEmpty == true
            ? bloodRequest['hospital_name'].toString()
            : 'Hospital not provided';

    final String patientLocation =
        (bloodRequest['patient_location'] ?? bloodRequest['location'])
                    ?.toString()
                    .trim()
                    .isNotEmpty ==
                true
            ? (bloodRequest['patient_location'] ?? bloodRequest['location'])
                .toString()
            : 'Location not provided';

    final String finalMessage = message.trim().isEmpty
        ? 'Patient needs blood urgently.'
        : message.trim();

    final donationRequestData = <String, dynamic>{
      'id': donationRequestId,
      'donation_request_id': donationRequestId,

      'blood_request_id': cleanBloodRequestId,
      'donor_request_id': cleanDonorRequestId,

      'patient_uid': firebaseUser.uid,
      'donor_uid': donorUid,

      'patient_name': patientName,
      'patient_email': patientUser.email,
      'patient_phone': patientUser.phone,
      'patient_location': patientLocation,
      'hospital_name': hospitalName,

      'donor_name': donorRequest['donor_name'] ?? donorRequest['name'],
      'donor_email': donorRequest['donor_email'],
      'donor_phone': donorRequest['donor_phone'] ?? donorRequest['phone'],

      'blood_group': patientBloodGroup,
      'patient_blood_group': patientBloodGroup,
      'donor_blood_group': donorBloodGroup,

      'message': finalMessage,

      'status': 'pending',
      'request_status': 'pending',
      'is_read_by_donor': false,
      'phone_visible_to_patient': false,

      'created_at': now,
      'updated_at': now,
    };

    final donorNotificationData = <String, dynamic>{
      'id': notificationId,
      'notification_id': notificationId,

      'donation_request_id': donationRequestId,
      'blood_request_id': cleanBloodRequestId,
      'donor_request_id': cleanDonorRequestId,

      'donor_uid': donorUid,
      'patient_uid': firebaseUser.uid,

      'title': 'New Blood Request',
      'body':
          '$patientName needs $patientBloodGroup blood at $hospitalName. Location: $patientLocation',

      'type': 'blood_request',
      'status': 'pending',
      'is_read': false,

      'patient_name': patientName,
      'patient_blood_group': patientBloodGroup,
      'blood_group': patientBloodGroup,
      'patient_location': patientLocation,
      'hospital_name': hospitalName,
      'message': finalMessage,

      'created_at': now,
      'updated_at': now,
    };

    final batch = _firestore.batch();

    batch.set(docRef, donationRequestData);
    batch.set(notificationRef, donorNotificationData);

    batch.update(bloodRequestRef, {
      'sent_donor_uids': FieldValue.arrayUnion([donorUid]),
      'sent_donor_request_ids': FieldValue.arrayUnion([cleanDonorRequestId]),
      'updated_at': now,
    });

    await batch.commit();

    debugPrint('Donation request created through SDK: $donationRequestId');
    debugPrint('Donor notification created through SDK: $notificationId');

    return donationRequestId;
  }
}