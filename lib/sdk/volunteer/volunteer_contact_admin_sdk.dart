import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/sdk_exception.dart';

class VolunteerContactAdminSdk {
  VolunteerContactAdminSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String contactsCollection = 'volunteer_admin_contacts';
  static const String adminNotificationsCollection = 'admin_notifications';
  static const String volunteerNotificationsCollection =
      'volunteer_notifications';

  static const String volunteerRolesCollection =
      'users/roles/team_volunteers';
  static const String adminRolesCollection = 'users/roles/admins';

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
      return 'Permission denied. Please update Firestore rules.';
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

      if (value is int) return value == 1;

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

  static DateTime _parseDate(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  static void _sortMessages(List<VolunteerContactMessage> messages) {
    messages.sort((a, b) {
      final bDate = _parseDate(b.createdAt);
      final aDate = _parseDate(a.createdAt);

      return bDate.compareTo(aDate);
    });
  }

  static Future<Map<String, dynamic>> _verifyVolunteer() async {
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

      return data;
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to verify volunteer profile.'),
      );
    }
  }

  static Future<Map<String, dynamic>> _verifyAdmin() async {
    final user = _currentFirebaseUser();

    try {
      final snapshot =
          await _firestore.collection(adminRolesCollection).doc(user.uid).get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw const SdkException(
          'Admin profile not found. Please login again.',
        );
      }

      final data = Map<String, dynamic>.from(snapshot.data()!);

      final role = _readString(data, ['role']);

      if (role != 'admin') {
        throw const SdkException(
          'Admin profile not found. Please login again.',
        );
      }

      return data;
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to verify admin profile.'),
      );
    }
  }

  static VolunteerContactMessage _mapDocToMessage(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return VolunteerContactMessage.fromFirestore(
      id: doc.id,
      data: Map<String, dynamic>.from(doc.data()),
    );
  }

  static VolunteerContactMessage _mapSnapshotToMessage(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return VolunteerContactMessage.fromFirestore(
      id: doc.id,
      data: Map<String, dynamic>.from(doc.data() ?? {}),
    );
  }

  static Future<List<VolunteerContactMessage>> getVolunteerMessages() async {
    await _verifyVolunteer();

    final user = _currentFirebaseUser();

    try {
      final snapshot = await _firestore
          .collection(contactsCollection)
          .where('volunteer_uid', isEqualTo: user.uid)
          .get();

      final messages = snapshot.docs.map(_mapDocToMessage).toList();

      _sortMessages(messages);

      return messages;
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to fetch volunteer messages.'),
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to fetch volunteer messages: $e');
    }
  }

  static Stream<List<VolunteerContactMessage>> watchVolunteerMessages() {
    final user = _currentFirebaseUser();

    return Stream.fromFuture(_verifyVolunteer()).asyncExpand((_) {
      return _firestore
          .collection(contactsCollection)
          .where('volunteer_uid', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) {
        final messages = snapshot.docs.map(_mapDocToMessage).toList();

        _sortMessages(messages);

        return messages;
      });
    });
  }

  static Future<VolunteerContactMessage> getVolunteerMessageDetail(
    String contactId,
  ) async {
    await _verifyVolunteer();

    final user = _currentFirebaseUser();
    final cleanId = contactId.trim();

    if (cleanId.isEmpty) {
      throw const SdkException('Message ID is missing.');
    }

    try {
      final snapshot =
          await _firestore.collection(contactsCollection).doc(cleanId).get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw const SdkException('Message not found.');
      }

      final message = _mapSnapshotToMessage(snapshot);

      if (message.volunteerUid != user.uid) {
        throw const SdkException('Message not found.');
      }

      if (message.isReadByVolunteer == false) {
        await _firestore.collection(contactsCollection).doc(cleanId).update({
          'is_read_by_volunteer': true,
          'updated_at': _now(),
        });
      }

      return message;
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to fetch message detail.'),
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to fetch message detail: $e');
    }
  }

  static Stream<VolunteerContactMessage?> watchVolunteerMessageDetail(
    String contactId,
  ) {
    final user = _currentFirebaseUser();
    final cleanId = contactId.trim();

    if (cleanId.isEmpty) {
      return Stream.error(
        const SdkException('Message ID is missing.'),
      );
    }

    return Stream.fromFuture(_verifyVolunteer()).asyncExpand((_) {
      return _firestore
          .collection(contactsCollection)
          .doc(cleanId)
          .snapshots()
          .asyncMap((snapshot) async {
        if (!snapshot.exists || snapshot.data() == null) {
          throw const SdkException('Message not found.');
        }

        final message = _mapSnapshotToMessage(snapshot);

        if (message.volunteerUid != user.uid) {
          throw const SdkException('Message not found.');
        }

        if (message.isReadByVolunteer == false) {
          await _firestore.collection(contactsCollection).doc(cleanId).update({
            'is_read_by_volunteer': true,
            'updated_at': _now(),
          });
        }

        return message;
      });
    });
  }

  static Future<VolunteerContactMessage> sendMessageToAdmin({
    required String subject,
    required String message,
    String? issueType,
    String? phone,
  }) async {
    final profile = await _verifyVolunteer();
    final user = _currentFirebaseUser();

    final cleanSubject = subject.trim();
    final cleanMessage = message.trim();
    final cleanIssueType = issueType?.trim() ?? '';
    final cleanPhone = phone?.trim() ?? '';

    if (cleanSubject.isEmpty) {
      throw const SdkException('Subject is required.');
    }

    if (cleanMessage.isEmpty) {
      throw const SdkException('Message is required.');
    }

    final volunteerName = _readString(
      profile,
      [
        'volunteer_name',
        'volunteerName',
        'name',
        'full_name',
        'fullName',
      ],
      fallback: user.displayName ?? 'Volunteer',
    );

    final volunteerEmail = _readString(
      profile,
      [
        'volunteer_email',
        'volunteerEmail',
        'email',
      ],
      fallback: user.email ?? '',
    );

    final profilePhone = _readString(
      profile,
      [
        'volunteer_phone',
        'volunteerPhone',
        'phone',
        'phone_number',
        'phoneNumber',
      ],
      fallback: user.phoneNumber ?? '',
    );

    final now = _now();

    final contactRef = _firestore.collection(contactsCollection).doc();
    final notificationRef =
        _firestore.collection(adminNotificationsCollection).doc();

    final contactData = <String, dynamic>{
      'contact_id': contactRef.id,
      'volunteer_uid': user.uid,
      'volunteer_name': volunteerName,
      'volunteer_email': volunteerEmail,
      'volunteer_phone': cleanPhone.isNotEmpty ? cleanPhone : profilePhone,
      'subject': cleanSubject,
      'message': cleanMessage,
      'issue_type': cleanIssueType,
      'status': 'open',
      'admin_reply': '',
      'admin_replied_at': '',
      'admin_uid': '',
      'is_read_by_admin': false,
      'is_read_by_volunteer': true,
      'created_at': now,
      'updated_at': now,
    };

    final adminNotificationData = <String, dynamic>{
      'notification_id': notificationRef.id,
      'contact_id': contactRef.id,
      'volunteer_uid': user.uid,
      'volunteer_name': volunteerName,
      'title': 'New volunteer contact request',
      'subject': cleanSubject,
      'message': '$volunteerName sent a new message to admin.',
      'type': 'volunteer_contact',
      'is_read': false,
      'created_at': now,
      'updated_at': now,
    };

    try {
      final batch = _firestore.batch();

      batch.set(contactRef, contactData);
      batch.set(notificationRef, adminNotificationData);

      await batch.commit();

      final snapshot = await contactRef.get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw const SdkException('Message data not found.');
      }

      return _mapSnapshotToMessage(snapshot);
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to send message to admin.'),
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to send message to admin: $e');
    }
  }

  static Future<List<VolunteerContactMessage>> getAdminContacts() async {
    await _verifyAdmin();

    try {
      final snapshot = await _firestore.collection(contactsCollection).get();

      final contacts = snapshot.docs.map(_mapDocToMessage).toList();

      _sortMessages(contacts);

      return contacts;
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to fetch admin contacts.'),
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to fetch admin contacts: $e');
    }
  }

  static Stream<List<VolunteerContactMessage>> watchAdminContacts() {
    return Stream.fromFuture(_verifyAdmin()).asyncExpand((_) {
      return _firestore.collection(contactsCollection).snapshots().map(
        (snapshot) {
          final contacts = snapshot.docs.map(_mapDocToMessage).toList();

          _sortMessages(contacts);

          return contacts;
        },
      );
    });
  }

  static Future<VolunteerContactMessage> getAdminContactDetail(
    String contactId,
  ) async {
    await _verifyAdmin();

    final cleanId = contactId.trim();

    if (cleanId.isEmpty) {
      throw const SdkException('Contact ID is missing.');
    }

    try {
      final snapshot =
          await _firestore.collection(contactsCollection).doc(cleanId).get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw const SdkException('Contact not found.');
      }

      return _mapSnapshotToMessage(snapshot);
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to fetch contact detail.'),
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to fetch contact detail: $e');
    }
  }

  static Stream<VolunteerContactMessage?> watchAdminContactDetail(
    String contactId,
  ) {
    final cleanId = contactId.trim();

    if (cleanId.isEmpty) {
      return Stream.error(
        const SdkException('Contact ID is missing.'),
      );
    }

    return Stream.fromFuture(_verifyAdmin()).asyncExpand((_) {
      return _firestore
          .collection(contactsCollection)
          .doc(cleanId)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          throw const SdkException('Contact not found.');
        }

        return _mapSnapshotToMessage(snapshot);
      });
    });
  }

  static Future<void> markAdminContactAsRead(String contactId) async {
    await _verifyAdmin();

    final cleanId = contactId.trim();

    if (cleanId.isEmpty) {
      throw const SdkException('Contact ID is missing.');
    }

    try {
      final now = _now();

      final contactRef = _firestore.collection(contactsCollection).doc(cleanId);

      final notificationsSnapshot = await _firestore
          .collection(adminNotificationsCollection)
          .where('contact_id', isEqualTo: cleanId)
          .get();

      final batch = _firestore.batch();

      batch.update(contactRef, {
        'is_read_by_admin': true,
        'updated_at': now,
      });

      for (final doc in notificationsSnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());

        final type = _readString(data, ['type']);
        final isRead = _readBool(data, ['is_read', 'isRead']);

        if (type == 'volunteer_contact' && isRead == false) {
          batch.update(doc.reference, {
            'is_read': true,
            'updated_at': now,
          });
        }
      }

      await batch.commit();
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to mark contact as read.'),
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to mark contact as read: $e');
    }
  }

  static Future<void> replyToVolunteer({
    required String contactId,
    required String reply,
  }) async {
    await _verifyAdmin();

    final adminUser = _currentFirebaseUser();
    final cleanId = contactId.trim();
    final cleanReply = reply.trim();

    if (cleanId.isEmpty) {
      throw const SdkException('Contact ID is missing.');
    }

    if (cleanReply.isEmpty) {
      throw const SdkException('Reply message is required.');
    }

    try {
      final contactRef = _firestore.collection(contactsCollection).doc(cleanId);
      final contactSnapshot = await contactRef.get();

      if (!contactSnapshot.exists || contactSnapshot.data() == null) {
        throw const SdkException('Contact not found.');
      }

      final contact = _mapSnapshotToMessage(contactSnapshot);

      final now = _now();

      final volunteerNotificationRef =
          _firestore.collection(volunteerNotificationsCollection).doc();

      final volunteerNotificationData = <String, dynamic>{
        'notification_id': volunteerNotificationRef.id,
        'contact_id': cleanId,
        'volunteer_uid': contact.volunteerUid,
        'volunteer_name': contact.volunteerName,
        'title': 'Admin replied to your message',
        'subject': contact.subject,
        'message': 'Admin replied to your contact request.',
        'type': 'admin_contact_reply',
        'is_read': false,
        'created_at': now,
        'updated_at': now,
      };

      final batch = _firestore.batch();

      batch.update(contactRef, {
        'admin_reply': cleanReply,
        'admin_replied_at': now,
        'admin_uid': adminUser.uid,
        'status': 'replied',
        'is_read_by_admin': true,
        'is_read_by_volunteer': false,
        'updated_at': now,
      });

      batch.set(volunteerNotificationRef, volunteerNotificationData);

      await batch.commit();
    } on FirebaseException catch (e) {
      throw SdkException(
        _firebaseErrorMessage(e, 'Failed to send reply.'),
      );
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to send reply: $e');
    }
  }
}

class VolunteerContactMessage {
  final String contactId;
  final String volunteerUid;
  final String volunteerName;
  final String volunteerEmail;
  final String volunteerPhone;
  final String subject;
  final String message;
  final String issueType;
  final String status;
  final String adminReply;
  final String adminRepliedAt;
  final bool isReadByAdmin;
  final bool isReadByVolunteer;
  final String createdAt;
  final String updatedAt;

  const VolunteerContactMessage({
    required this.contactId,
    required this.volunteerUid,
    required this.volunteerName,
    required this.volunteerEmail,
    required this.volunteerPhone,
    required this.subject,
    required this.message,
    required this.issueType,
    required this.status,
    required this.adminReply,
    required this.adminRepliedAt,
    required this.isReadByAdmin,
    required this.isReadByVolunteer,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VolunteerContactMessage.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final contactId = VolunteerContactAdminSdk._readString(
      data,
      ['contact_id', 'contactId', 'id'],
    );

    return VolunteerContactMessage(
      contactId: contactId.isNotEmpty ? contactId : id,
      volunteerUid: VolunteerContactAdminSdk._readString(
        data,
        [
          'volunteer_uid',
          'volunteerUid',
          'uid',
          'user_id',
          'userId',
        ],
      ),
      volunteerName: VolunteerContactAdminSdk._readString(
        data,
        [
          'volunteer_name',
          'volunteerName',
          'name',
          'full_name',
          'fullName',
        ],
        fallback: 'Volunteer',
      ),
      volunteerEmail: VolunteerContactAdminSdk._readString(
        data,
        [
          'volunteer_email',
          'volunteerEmail',
          'email',
        ],
      ),
      volunteerPhone: VolunteerContactAdminSdk._readString(
        data,
        [
          'volunteer_phone',
          'volunteerPhone',
          'phone',
          'phone_number',
          'phoneNumber',
        ],
      ),
      subject: VolunteerContactAdminSdk._readString(
        data,
        ['subject'],
      ),
      message: VolunteerContactAdminSdk._readString(
        data,
        ['message'],
      ),
      issueType: VolunteerContactAdminSdk._readString(
        data,
        ['issue_type', 'issueType'],
      ),
      status: VolunteerContactAdminSdk._readString(
        data,
        ['status'],
        fallback: 'open',
      ),
      adminReply: VolunteerContactAdminSdk._readString(
        data,
        ['admin_reply', 'adminReply', 'reply'],
      ),
      adminRepliedAt: VolunteerContactAdminSdk._readString(
        data,
        ['admin_replied_at', 'adminRepliedAt'],
      ),
      isReadByAdmin: VolunteerContactAdminSdk._readBool(
        data,
        ['is_read_by_admin', 'isReadByAdmin'],
      ),
      isReadByVolunteer: VolunteerContactAdminSdk._readBool(
        data,
        ['is_read_by_volunteer', 'isReadByVolunteer'],
      ),
      createdAt: VolunteerContactAdminSdk._readString(
        data,
        ['created_at', 'createdAt'],
      ),
      updatedAt: VolunteerContactAdminSdk._readString(
        data,
        ['updated_at', 'updatedAt'],
      ),
    );
  }
}