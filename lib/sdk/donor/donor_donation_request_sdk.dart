// lib/sdk/donor/donor_donation_request_sdk.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_sdk.dart';
import '../core/sdk_exception.dart';

class DonorDonationRequestSdk {
  DonorDonationRequestSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String donationRequestsCollection = 'donation_requests';
  static const String notificationsCollection = 'notifications';

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

  static Future<List<Map<String, dynamic>>> fetchIncomingRequests() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final donorUser = await AuthSdk.currentAppUser(expectedRole: 'donor');

    if (donorUser == null) {
      throw const SdkException('Donor profile not found. Please login again.');
    }

    final snapshot = await _firestore
        .collection(donationRequestsCollection)
        .where('donor_uid', isEqualTo: firebaseUser.uid)
        .get();

    final List<Map<String, dynamic>> requests = [];

    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());

      final String status = _readString(data, [
        'status',
        'request_status',
      ]);

      final item = <String, dynamic>{
        ...data,
        'id': data['id'] ?? data['donation_request_id'] ?? doc.id,
        'donation_request_id': data['donation_request_id'] ?? doc.id,
        'patient_name': _readString(data, ['patient_name', 'name']).isNotEmpty
            ? _readString(data, ['patient_name', 'name'])
            : 'Patient',
        'blood_group': _readString(data, [
          'blood_group',
          'patient_blood_group',
          'donor_blood_group',
        ]),
        'donor_blood_group': _readString(data, [
          'donor_blood_group',
          'blood_group',
        ]),
        'patient_location': _readString(data, [
          'patient_location',
          'location',
          'current_location',
        ]),
        'patient_phone': _readString(data, [
          'patient_phone',
          'phone',
        ]),
        'message': _readString(data, [
          'message',
          'case_description',
        ]),
        'status': status.isNotEmpty ? status : 'pending',
        'created_at': data['created_at'],
      };

      requests.add(item);
    }

    requests.sort((a, b) {
      return (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? '');
    });

    return requests;
  }

  static Future<void> rejectRequest({
    required String donationRequestId,
    String reason = 'Donor cannot donate blood right now.',
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final cleanId = donationRequestId.trim();

    if (cleanId.isEmpty) {
      throw const SdkException('Donation request ID missing.');
    }

    final docRef = _firestore.collection(donationRequestsCollection).doc(cleanId);

    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw const SdkException('Donation request not found.');
    }

    final data = snapshot.data()!;

    if (data['donor_uid']?.toString() != firebaseUser.uid) {
      throw const SdkException(
        'You are not allowed to reject this request.',
      );
    }

    final String currentStatus =
        data['status']?.toString().trim().toLowerCase() ?? '';

    if (currentStatus != 'pending') {
      throw const SdkException('This request is already responded.');
    }

    final now = DateTime.now().toIso8601String();

    await docRef.update({
      'status': 'rejected',
      'request_status': 'rejected',
      'reject_reason': reason.trim().isEmpty
          ? 'Donor cannot donate blood right now.'
          : reason.trim(),
      'rejected_by_donor_uid': firebaseUser.uid,
      'rejected_at': now,
      'updated_at': now,
    });
  }

  static Future<void> acceptConsent({
    required String donationRequestId,
    required String donorMessage,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final donorUser = await AuthSdk.currentAppUser(expectedRole: 'donor');

    if (donorUser == null) {
      throw const SdkException('Donor profile not found. Please login again.');
    }

    final cleanId = donationRequestId.trim();

    if (cleanId.isEmpty) {
      throw const SdkException('Donation request ID missing.');
    }

    final donationRequestRef =
        _firestore.collection(donationRequestsCollection).doc(cleanId);

    final snapshot = await donationRequestRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw const SdkException('Donation request not found.');
    }

    final data = Map<String, dynamic>.from(snapshot.data()!);

    final String donorUid = data['donor_uid']?.toString() ?? '';

    if (donorUid != firebaseUser.uid) {
      throw const SdkException(
        'You are not allowed to accept this request.',
      );
    }

    final String currentStatus =
        data['status']?.toString().trim().toLowerCase() ?? '';

    if (currentStatus != 'pending') {
      throw const SdkException('This request is already responded.');
    }

    final String patientUid = data['patient_uid']?.toString() ?? '';

    if (patientUid.trim().isEmpty) {
      throw const SdkException('Patient UID missing in request.');
    }

    final String now = DateTime.now().toIso8601String();

    final String patientName =
        data['patient_name']?.toString().trim().isNotEmpty == true
            ? data['patient_name'].toString()
            : 'Patient';

    final String donorName =
        data['donor_name']?.toString().trim().isNotEmpty == true
            ? data['donor_name'].toString()
            : 'Donor';

    final String bloodGroup =
        data['blood_group']?.toString().trim().isNotEmpty == true
            ? data['blood_group'].toString()
            : data['patient_blood_group']?.toString().trim().isNotEmpty == true
                ? data['patient_blood_group'].toString()
                : 'Blood';

    final String finalMessage = donorMessage.trim();

    final notificationRef = _firestore.collection(notificationsCollection).doc();
    final String notificationId = notificationRef.id;

    final Map<String, dynamic> consentData = {
      'agreed': true,
      'donor_message': finalMessage,
      'is_willing_to_donate': true,
      'accepted_terms': true,
      'accepted_at': now,
    };

    final Map<String, dynamic> patientNotificationData = {
      'id': notificationId,
      'notification_id': notificationId,

      'donation_request_id': cleanId,
      'blood_request_id': data['blood_request_id'],
      'donor_request_id': data['donor_request_id'],

      'recipient_uid': patientUid,
      'receiver_uid': patientUid,
      'user_uid': patientUid,
      'patient_uid': patientUid,

      'sender_uid': firebaseUser.uid,
      'donor_uid': firebaseUser.uid,

      'role': 'patient',
      'recipient_role': 'patient',

      'title': 'Donation Request Accepted',
      'body': '$donorName accepted your $bloodGroup blood request.',
      'type': 'donation_request_accepted',

      'status': 'accepted',
      'is_read': false,

      'patient_name': patientName,
      'donor_name': donorName,
      'blood_group': bloodGroup,
      'donor_message': finalMessage,

      'created_at': now,
      'updated_at': now,
    };

    final batch = _firestore.batch();

    batch.update(donationRequestRef, {
      'status': 'accepted',
      'request_status': 'accepted',
      'donor_response': 'accepted',

      'consent_data': consentData,
      'donor_message': finalMessage,

      'phone_visible_to_patient': true,
      'is_read_by_patient': false,

      'accepted_by_donor_uid': firebaseUser.uid,
      'accepted_at': now,
      'updated_at': now,
    });

    batch.set(notificationRef, patientNotificationData);

    await batch.commit();
  }
}