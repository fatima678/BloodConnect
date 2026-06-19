import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'core/sdk_exception.dart';

class GeneralNotificationSdk {
  GeneralNotificationSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String collectionName = 'notifications';
  static const String donorNotificationsCollection = 'donor_notifications';

  static String _now() {
    return DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceFirst('Z', '+00:00');
  }

  static int _readDateMillis(Map<String, dynamic> data) {
    final dynamic value = data['created_at'] ?? data['updated_at'];

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

  static String _dedupeKey(Map<String, dynamic> item) {
    final String donationRequestId = _readString(
      item,
      ['donation_request_id'],
    );

    final String bloodRequestId = _readString(
      item,
      ['blood_request_id'],
    );

    final String type = _readString(
      item,
      ['type'],
    );

    final String recipientUid = _readString(
      item,
      ['recipient_uid', 'donor_uid', 'patient_uid'],
    );

    if (donationRequestId.isNotEmpty && type.isNotEmpty) {
      return 'donation-$donationRequestId-$type-$recipientUid';
    }

    if (bloodRequestId.isNotEmpty && type.isNotEmpty) {
      return 'blood-$bloodRequestId-$type-$recipientUid';
    }

    final String source = _readString(item, ['source_collection']);
    final String id = _readString(item, ['notification_id', 'id']);

    return '$source-$id';
  }

  static Future<List<Map<String, dynamic>>> fetchMyNotifications({
    int limit = 50,
  }) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw SdkException('Session not found. Please login again.');
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> generalSnapshot =
          await _firestore
              .collection(collectionName)
              .where('recipient_uid', isEqualTo: currentUser.uid)
              .limit(limit)
              .get();

      final QuerySnapshot<Map<String, dynamic>> donorSnapshot =
          await _firestore
              .collection(donorNotificationsCollection)
              .where('donor_uid', isEqualTo: currentUser.uid)
              .limit(limit)
              .get();

      final List<Map<String, dynamic>> allNotifications = [];

      for (final doc in generalSnapshot.docs) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());

        data['id'] = data['id'] ?? doc.id;
        data['notification_id'] = data['notification_id'] ?? doc.id;
        data['source_collection'] = collectionName;
        data['is_read'] = data['is_read'] == true;

        allNotifications.add(data);
      }

      for (final doc in donorSnapshot.docs) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data());

        data['id'] = data['id'] ?? doc.id;
        data['notification_id'] = data['notification_id'] ?? doc.id;
        data['source_collection'] = donorNotificationsCollection;
        data['recipient_uid'] = data['recipient_uid'] ?? currentUser.uid;
        data['recipient_role'] = data['recipient_role'] ?? 'donor';
        data['role'] = data['role'] ?? 'donor';
        data['body'] = data['body'] ?? data['message'] ?? '';
        data['is_read'] = data['is_read'] == true;

        allNotifications.add(data);
      }

      final Map<String, Map<String, dynamic>> uniqueNotifications = {};

      for (final item in allNotifications) {
        final String key = _dedupeKey(item);

        if (key.trim().isEmpty) continue;

        if (!uniqueNotifications.containsKey(key)) {
          uniqueNotifications[key] = item;
          continue;
        }

        final existing = uniqueNotifications[key]!;

        if (_readString(existing, ['source_collection']) ==
            donorNotificationsCollection) {
          uniqueNotifications[key] = item;
        }
      }

      final List<Map<String, dynamic>> notifications =
          uniqueNotifications.values.toList();

      notifications.sort((a, b) {
        return _readDateMillis(b).compareTo(_readDateMillis(a));
      });

      if (notifications.length > limit) {
        return notifications.take(limit).toList();
      }

      return notifications;
    } on FirebaseException catch (e) {
      throw SdkException(e.message ?? 'Failed to fetch notifications.');
    } catch (e) {
      throw SdkException('Failed to fetch notifications.');
    }
  }

  static Future<void> markAsRead(String notificationId) async {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw SdkException('Session not found. Please login again.');
    }

    if (notificationId.trim().isEmpty) {
      throw SdkException('Invalid notification id.');
    }

    try {
      DocumentReference<Map<String, dynamic>> ref =
          _firestore.collection(collectionName).doc(notificationId.trim());

      DocumentSnapshot<Map<String, dynamic>> snapshot = await ref.get();

      if (!snapshot.exists || snapshot.data() == null) {
        ref = _firestore
            .collection(donorNotificationsCollection)
            .doc(notificationId.trim());

        snapshot = await ref.get();
      }

      if (!snapshot.exists || snapshot.data() == null) {
        throw SdkException('Notification not found.');
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(snapshot.data()!);

      final String recipientUid = _readString(
        data,
        [
          'recipient_uid',
          'receiver_uid',
          'user_uid',
          'donor_uid',
          'patient_uid',
        ],
      );

      if (recipientUid != currentUser.uid &&
          _readString(data, ['donor_uid']) != currentUser.uid &&
          _readString(data, ['patient_uid']) != currentUser.uid) {
        throw SdkException('You are not allowed to update this notification.');
      }

      await ref.set(
        {
          'is_read': true,
          'read_at': _now(),
          'updated_at': _now(),
        },
        SetOptions(merge: true),
      );
    } on SdkException {
      rethrow;
    } on FirebaseException catch (e) {
      throw SdkException(e.message ?? 'Failed to mark notification as read.');
    } catch (e) {
      throw SdkException('Failed to mark notification as read.');
    }
  }

  static Future<String> createNotification({
    required String recipientUid,
    required String recipientRole,
    required String type,
    required String title,
    required String body,
    String? senderUid,
    String? senderRole,
    String? bloodRequestId,
    String? donationRequestId,
    Map<String, dynamic>? extraData,
  }) async {
    if (recipientUid.trim().isEmpty) {
      throw SdkException('Recipient user id is required.');
    }

    if (recipientRole.trim().isEmpty) {
      throw SdkException('Recipient role is required.');
    }

    if (type.trim().isEmpty) {
      throw SdkException('Notification type is required.');
    }

    if (title.trim().isEmpty) {
      throw SdkException('Notification title is required.');
    }

    if (body.trim().isEmpty) {
      throw SdkException('Notification body is required.');
    }

    try {
      final DocumentReference<Map<String, dynamic>> docRef =
          _firestore.collection(collectionName).doc();

      final String now = _now();

      final Map<String, dynamic> data = {
        'id': docRef.id,
        'notification_id': docRef.id,

        'recipient_uid': recipientUid.trim(),
        'recipient_role': recipientRole.trim().toLowerCase(),
        'role': recipientRole.trim().toLowerCase(),

        'sender_uid': senderUid?.trim() ?? '',
        'sender_role': senderRole?.trim().toLowerCase() ?? '',

        'type': type.trim().toLowerCase(),
        'title': title.trim(),
        'body': body.trim(),
        'message': body.trim(),

        'blood_request_id': bloodRequestId?.trim() ?? '',
        'donation_request_id': donationRequestId?.trim() ?? '',

        'is_read': false,
        'created_at': now,
        'updated_at': now,
      };

      if (extraData != null && extraData.isNotEmpty) {
        data.addAll(extraData);
      }

      await docRef.set(data);

      return docRef.id;
    } on FirebaseException catch (e) {
      throw SdkException(e.message ?? 'Failed to create notification.');
    } catch (e) {
      throw SdkException('Failed to create notification.');
    }
  }
}