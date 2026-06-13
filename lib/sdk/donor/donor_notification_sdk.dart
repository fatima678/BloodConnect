// lib/sdk/notifications/donor_notification_sdk.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_sdk.dart';
import '../core/sdk_exception.dart';

class DonorNotificationSdk {
  DonorNotificationSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // IMPORTANT:
  // Aapki DB screenshot ke mutabiq donor notifications yahan save ho rahi hain.
  static const String notificationsCollection = 'donor_notifications';

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

  static Future<List<Map<String, dynamic>>> fetchDonorNotifications({
    int limit = 50,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final donorUser = await AuthSdk.currentAppUser(expectedRole: 'donor');

    if (donorUser == null) {
      throw const SdkException('Donor profile not found. Please login again.');
    }

    try {
      debugPrint('Fetching donor notifications for UID: ${firebaseUser.uid}');
      debugPrint('Collection: $notificationsCollection');

      final snapshot = await _firestore
          .collection(notificationsCollection)
          .where('donor_uid', isEqualTo: firebaseUser.uid)
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

          'title': title.isNotEmpty ? title : 'New Blood Request',
          'body': body.isNotEmpty ? body : 'Patient needs blood urgently.',
          'message': _readString(data, ['message', 'body']),

          'type': type.isNotEmpty ? type : 'blood_request',

          // Screen compatibility
          'role': 'donor',
          'recipient_uid': data['donor_uid'],
          'donor_uid': data['donor_uid'],

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

      debugPrint('Donor notifications fetched: ${notifications.length}');

      if (notifications.length > limit) {
        return notifications.take(limit).toList();
      }

      return notifications;
    } on FirebaseException catch (e) {
      debugPrint('DonorNotificationSdk Firebase error: ${e.code}');
      debugPrint('DonorNotificationSdk message: ${e.message}');

      if (e.code == 'permission-denied') {
        throw const SdkException(
          'Permission denied. Please update Firestore rules for donor_notifications.',
        );
      }

      throw SdkException(
        e.message ?? 'Failed to fetch donor notifications.',
      );
    } catch (e) {
      debugPrint('DonorNotificationSdk unknown error: $e');
      throw SdkException('Failed to fetch donor notifications: $e');
    }
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

    try {
      final docRef = _firestore.collection(notificationsCollection).doc(cleanId);
      final snapshot = await docRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw const SdkException('Notification not found.');
      }

      final data = snapshot.data()!;

      final String donorUid = _readString(data, [
        'donor_uid',
        'recipient_uid',
        'receiver_uid',
        'user_uid',
      ]);

      if (donorUid != firebaseUser.uid) {
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

      debugPrint('Donor notification marked as read: $cleanId');
    } on FirebaseException catch (e) {
      debugPrint('Mark donor notification Firebase error: ${e.code}');
      debugPrint('Mark donor notification message: ${e.message}');

      if (e.code == 'permission-denied') {
        throw const SdkException(
          'Permission denied. Please update Firestore rules for donor_notifications.',
        );
      }

      throw SdkException(
        e.message ?? 'Failed to mark notification as read.',
      );
    }
  }
}