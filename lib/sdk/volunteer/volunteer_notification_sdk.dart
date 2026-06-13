import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/sdk_exception.dart';

class VolunteerNotificationSdk {
  VolunteerNotificationSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String notificationsCollection = 'volunteer_notifications';
  static const String eventsCollection = 'events';
  static const String volunteerRolesCollection =
      'users/roles/team_volunteers';

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
      return 'Permission denied. Please update Firestore rules for volunteer notifications.';
    }

    return e.message ?? fallback;
  }

  static Future<void> _verifyVolunteer() async {
    final user = _currentFirebaseUser();

    try {
      final snapshot = await _firestore
          .collection(volunteerRolesCollection)
          .doc(user.uid)
          .get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw const SdkException(
          'Volunteer profile not found. Please login again.',
        );
      }

      final data = Map<String, dynamic>.from(snapshot.data()!);
      final role = _readString(data, ['role']);

      if (role != 'team_volunteer') {
        throw const SdkException(
          'Volunteer profile not found. Please login again.',
        );
      }
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to verify volunteer profile.'),
      );
    }
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
        return value.toDate().toIso8601String();
      }

      if (value is DateTime) {
        return value.toIso8601String();
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
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value == true) return true;
      if (value == false) return false;

      if (value is num) return value == 1;

      if (value is String) {
        final text = value.toLowerCase().trim();

        if (text == 'true' || text == '1' || text == 'yes') {
          return true;
        }

        if (text == 'false' || text == '0' || text == 'no') {
          return false;
        }
      }
    }

    return false;
  }

  static DateTime _readDateTime(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      final parsed = DateTime.tryParse(value.toString().trim());

      if (parsed != null) {
        return parsed;
      }
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Map) {
      return _normalizeMap(Map<String, dynamic>.from(value));
    }

    if (value is List) {
      return value.map(_normalizeValue).toList();
    }

    return value;
  }

  static Map<String, dynamic> _normalizeMap(Map<String, dynamic> data) {
    final normalized = <String, dynamic>{};

    data.forEach((key, value) {
      normalized[key] = _normalizeValue(value);
    });

    return normalized;
  }

  static VolunteerNotificationModel _mapDocToNotification(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = _normalizeMap(Map<String, dynamic>.from(doc.data()));

    return VolunteerNotificationModel.fromMap({
      ...data,
      'doc_id': doc.id,
    });
  }

  static VolunteerNotificationModel _mapSnapshotToNotification(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = _normalizeMap(Map<String, dynamic>.from(doc.data() ?? {}));

    return VolunteerNotificationModel.fromMap({
      ...data,
      'doc_id': doc.id,
    });
  }

  static Future<List<VolunteerNotificationModel>> fetchNotifications() async {
    await _verifyVolunteer();

    final user = _currentFirebaseUser();

    try {
      final snapshot = await _firestore
          .collection(notificationsCollection)
          .where('volunteer_uid', isEqualTo: user.uid)
          .get();

      final notifications = snapshot.docs.map(_mapDocToNotification).toList();

      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return notifications;
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to fetch notifications.'),
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to fetch notifications: $e');
    }
  }

  static Future<DocumentReference<Map<String, dynamic>>?>
      _findNotificationReference(String notificationId) async {
    final user = _currentFirebaseUser();
    final cleanId = notificationId.trim();

    if (cleanId.isEmpty) {
      return null;
    }

    final directRef = _firestore.collection(notificationsCollection).doc(cleanId);
    final directSnapshot = await directRef.get();

    if (directSnapshot.exists && directSnapshot.data() != null) {
      final data = Map<String, dynamic>.from(directSnapshot.data()!);
      final volunteerUid = _readString(data, ['volunteer_uid', 'volunteerUid']);

      if (volunteerUid == user.uid) {
        return directRef;
      }
    }

    final querySnapshot = await _firestore
        .collection(notificationsCollection)
        .where('notification_id', isEqualTo: cleanId)
        .where('volunteer_uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    return querySnapshot.docs.first.reference;
  }

  static Future<void> markAsRead(String notificationId) async {
    await _verifyVolunteer();

    final cleanId = notificationId.trim();

    if (cleanId.isEmpty) return;

    try {
      final ref = await _findNotificationReference(cleanId);

      if (ref == null) return;

      await ref.update({
        'is_read': true,
        'updated_at': _now(),
      });
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to mark notification as read.'),
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to mark notification as read: $e');
    }
  }

  static Future<Map<String, dynamic>> loadNotificationDetail(
    VolunteerNotificationModel notification,
  ) async {
    await _verifyVolunteer();

    final notificationMap = Map<String, dynamic>.from(notification.raw);
    final eventId = notification.eventId.trim();

    if (eventId.isEmpty) {
      return notificationMap;
    }

    try {
      final snapshot =
          await _firestore.collection(eventsCollection).doc(eventId).get();

      if (!snapshot.exists || snapshot.data() == null) {
        return notificationMap;
      }

      final eventMap = _normalizeMap(Map<String, dynamic>.from(
        snapshot.data()!,
      ));

      return {
        ...notificationMap,
        ...eventMap,
        'event_id': eventId,
      };
    } on FirebaseException {
      return notificationMap;
    } catch (_) {
      return notificationMap;
    }
  }
}

class VolunteerNotificationModel {
  final String notificationId;
  final String eventId;
  final String title;
  final String message;
  final String bloodBankTitle;
  final String eventTitle;
  final String bloodGroup;
  final String location;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic> raw;

  const VolunteerNotificationModel({
    required this.notificationId,
    required this.eventId,
    required this.title,
    required this.message,
    required this.bloodBankTitle,
    required this.eventTitle,
    required this.bloodGroup,
    required this.location,
    required this.createdAt,
    required this.isRead,
    required this.raw,
  });

  factory VolunteerNotificationModel.fromMap(Map<String, dynamic> map) {
    final flatMap = <String, dynamic>{...map};

    if (map['data'] is Map) {
      flatMap.addAll(Map<String, dynamic>.from(map['data']));
    }

    String first(List<String> keys) {
      for (final key in keys) {
        final value = flatMap[key];

        if (value == null) continue;

        if (value is Timestamp) {
          return value.toDate().toIso8601String();
        }

        if (value is DateTime) {
          return value.toIso8601String();
        }

        final text = value.toString().trim();

        if (text.isNotEmpty && text.toLowerCase() != 'null') {
          return text;
        }
      }

      return '';
    }

    DateTime parseDate() {
      final createdAt = VolunteerNotificationSdk._readDateTime(
        flatMap,
        [
          'created_at',
          'createdAt',
          'date',
          'event_date',
          'eventDate',
        ],
      );

      return createdAt;
    }

    bool parseRead() {
      return VolunteerNotificationSdk._readBool(
        flatMap,
        ['is_read', 'isRead'],
      );
    }

    final docId = first([
      'doc_id',
    ]);

    final notificationId = first([
      'notification_id',
      'notificationId',
      'id',
    ]);

    return VolunteerNotificationModel(
      notificationId: notificationId.isNotEmpty ? notificationId : docId,
      eventId: first([
        'event_id',
        'eventId',
      ]),
      title: first([
        'title',
        'notification_title',
        'notificationTitle',
      ]),
      message: first([
        'message',
        'body',
        'description',
      ]),
      bloodBankTitle: first([
        'blood_bank_title',
        'bloodBankTitle',
        'blood_bank_name',
        'bloodBankName',
        'hospital_name',
        'hospitalName',
        'bank_name',
        'bankName',
      ]),
      eventTitle: first([
        'event_title',
        'eventTitle',
        'event_name',
        'eventName',
      ]),
      bloodGroup: first([
        'blood_group',
        'bloodGroup',
        'blood_type',
        'bloodType',
        'required_blood_group',
        'requiredBloodGroup',
      ]),
      location: first([
        'location',
        'address',
        'city',
        'venue',
      ]),
      createdAt: parseDate(),
      isRead: parseRead(),
      raw: flatMap,
    );
  }

  String get displayTitle {
    if (bloodBankTitle.isNotEmpty) return bloodBankTitle;
    if (eventTitle.isNotEmpty) return eventTitle;
    if (title.isNotEmpty) return title;
    return 'Blood Notification';
  }

  String get readableDate {
    if (createdAt.millisecondsSinceEpoch == 0) return '';

    final day = createdAt.day.toString().padLeft(2, '0');
    final month = createdAt.month.toString().padLeft(2, '0');
    final year = createdAt.year.toString();

    return '$day-$month-$year';
  }
}