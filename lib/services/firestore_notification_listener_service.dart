import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../sdk/auth/auth_sdk.dart';
import 'app_notification_service.dart';

class FirestoreNotificationListenerService {
  FirestoreNotificationListenerService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static StreamSubscription<User?>? _authSubscription;
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _notificationSubscription;

  static String? _activeUid;
  static String? _activeRole;
  static bool _skipInitialSnapshot = true;

  static final Set<String> _shownNotificationIds = <String>{};

  static void start() {
    _authSubscription ??= _auth.authStateChanges().listen((firebaseUser) async {
      if (firebaseUser == null) {
        stopNotificationListener();
        return;
      }

      await startForCurrentUser();
    });
  }

  static Future<void> startForCurrentUser() async {
    try {
      final firebaseUser = _auth.currentUser;

      if (firebaseUser == null) {
        stopNotificationListener();
        return;
      }

      final appUser = await AuthSdk.currentAppUser();

      if (appUser == null) {
        debugPrint('Notification listener: app user not found.');
        return;
      }

      final uid = appUser.uid;
      final role = AuthSdk.normalizeRole(appUser.role);

      if (_activeUid == uid && _activeRole == role) {
        return;
      }

      stopNotificationListener();

      _activeUid = uid;
      _activeRole = role;
      _skipInitialSnapshot = true;
      _shownNotificationIds.clear();

      final query = _buildNotificationQuery(
        uid: uid,
        role: role,
      );

      if (query == null) {
        debugPrint('Notification listener: unsupported role $role');
        return;
      }

      _notificationSubscription = query.snapshots().listen(
        (snapshot) {
          _handleNotificationSnapshot(snapshot);
        },
        onError: (error) {
          debugPrint('Notification listener error: $error');
        },
      );

      debugPrint('Notification listener started for $role / $uid');
    } catch (e) {
      debugPrint('Failed to start notification listener: $e');
    }
  }

  static Query<Map<String, dynamic>>? _buildNotificationQuery({
    required String uid,
    required String role,
  }) {
    if (role == 'patient') {
      return _firestore
          .collection('notifications')
          .where('recipient_uid', isEqualTo: uid)
          .where('role', isEqualTo: 'patient');
    }

    if (role == 'donor') {
      return _firestore
          .collection('donor_notifications')
          .where('donor_uid', isEqualTo: uid);
    }

    if (role == 'team_volunteer') {
      return _firestore
          .collection('volunteer_notifications')
          .where('volunteer_uid', isEqualTo: uid);
    }

    return null;
  }

  static void _handleNotificationSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (_skipInitialSnapshot) {
      for (final doc in snapshot.docs) {
        _shownNotificationIds.add(doc.id);

        final data = doc.data();
        final notificationId = _readString(
          data,
          ['notification_id', 'id'],
          fallback: doc.id,
        );

        _shownNotificationIds.add(notificationId);
      }

      _skipInitialSnapshot = false;
      return;
    }

    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) {
        continue;
      }

      final doc = change.doc;
      final data = doc.data();

      if (data == null) {
        continue;
      }

      final notificationId = _readString(
        data,
        ['notification_id', 'id'],
        fallback: doc.id,
      );

      if (_shownNotificationIds.contains(notificationId) ||
          _shownNotificationIds.contains(doc.id)) {
        continue;
      }

      final bool isRead = _readBool(data, ['is_read', 'isRead']);

      if (isRead) {
        continue;
      }

      _shownNotificationIds.add(notificationId);
      _shownNotificationIds.add(doc.id);

      final title = _readString(
        data,
        [
          'title',
          'notification_title',
          'event_title',
          'blood_bank_title',
          'hospital_name',
        ],
        fallback: 'Blood Connect',
      );

      final body = _readString(
        data,
        [
          'body',
          'message',
          'description',
          'short_message',
        ],
        fallback: 'You have a new notification.',
      );

      AppNotificationService.showLocalNotification(
        title: title,
        body: body,
        payload: data.toString(),
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

  static void stopNotificationListener() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;

    _activeUid = null;
    _activeRole = null;
    _skipInitialSnapshot = true;
    _shownNotificationIds.clear();
  }

  static void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;

    stopNotificationListener();
  }
}