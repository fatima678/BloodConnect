// lib/sdk/notifications/patient_notification_sdk.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_sdk.dart';
import '../core/sdk_exception.dart';

class PatientNotificationSdk {
  PatientNotificationSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  static Future<List<Map<String, dynamic>>> fetchPatientNotifications({
    int limit = 50,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final patientUser = await AuthSdk.currentAppUser(expectedRole: 'patient');

    if (patientUser == null) {
      throw const SdkException('Patient profile not found. Please login again.');
    }

    final snapshot = await _firestore
        .collection(notificationsCollection)
        .where('recipient_uid', isEqualTo: firebaseUser.uid)
        .where('role', isEqualTo: 'patient')
        .get();

    final List<Map<String, dynamic>> notifications = [];

    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());

      final String notificationId = _readString(data, [
        'id',
        'notification_id',
      ]).isNotEmpty
          ? _readString(data, ['id', 'notification_id'])
          : doc.id;

      final String title = _readString(data, ['title']);
      final String body = _readString(data, ['body', 'message']);
      final String type = _readString(data, ['type']);

      final item = <String, dynamic>{
        ...data,
        'id': notificationId,
        'notification_id': notificationId,
        'title': title.isNotEmpty ? title : 'Notification',
        'body': body,
        'type': type.isNotEmpty ? type : 'notification',
        'role': 'patient',
        'is_read': data['is_read'] == true,
        'created_at': data['created_at'],
        'updated_at': data['updated_at'],
      };

      notifications.add(item);
    }

    notifications.sort((a, b) {
      return (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? '');
    });

    if (notifications.length > limit) {
      return notifications.take(limit).toList();
    }

    return notifications;
  }

  static Future<void> markAsRead(String notificationId) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final cleanId = notificationId.trim();

    if (cleanId.isEmpty) {
      throw const SdkException('Notification ID is missing.');
    }

    final docRef = _firestore.collection(notificationsCollection).doc(cleanId);
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw const SdkException('Notification not found.');
    }

    final data = snapshot.data()!;

    final String recipientUid = _readString(data, [
      'recipient_uid',
      'receiver_uid',
      'user_uid',
      'patient_uid',
    ]);

    if (recipientUid != firebaseUser.uid) {
      throw const SdkException(
        'You are not allowed to update this notification.',
      );
    }

    final now = DateTime.now().toIso8601String();

    await docRef.update({
      'is_read': true,
      'read_at': now,
      'updated_at': now,
    });
  }
}