// lib/sdk/events/volunteer_event_sdk.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_sdk.dart';
import '../core/sdk_exception.dart';

class VolunteerEventSdk {
  VolunteerEventSdk._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String eventsCollection = 'events';

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

  static int _readInt(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];

      if (value == null) continue;

      if (value is int) return value;

      if (value is num) return value.toInt();

      final parsed = int.tryParse(value.toString());

      if (parsed != null) return parsed;
    }

    return 0;
  }

  static Future<void> _verifyVolunteer() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw const SdkException('Session not found. Please login again.');
    }

    final volunteerUser = await AuthSdk.currentAppUser(
      expectedRole: 'team_volunteer',
    );

    if (volunteerUser == null) {
      throw const SdkException(
        'Volunteer profile not found. Please login again.',
      );
    }
  }

  static EventModel _mapDocToEvent(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = Map<String, dynamic>.from(doc.data());

    return EventModel.fromFirestore(
      id: doc.id,
      data: data,
    );
  }

  static EventModel _mapSnapshotToEvent(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = Map<String, dynamic>.from(doc.data() ?? {});

    return EventModel.fromFirestore(
      id: doc.id,
      data: data,
    );
  }

  static Future<List<EventModel>> fetchEvents({
    int limit = 100,
  }) async {
    await _verifyVolunteer();

    try {
      final snapshot = await _firestore.collection(eventsCollection).get();

      final List<EventModel> events = [];

      for (final doc in snapshot.docs) {
        final event = _mapDocToEvent(doc);

        final status = event.status.toLowerCase().trim();

        final bool isVisible = status.isEmpty ||
            status == 'active' ||
            status == 'upcoming' ||
            status == 'completed';

        if (!isVisible) continue;

        events.add(event);
      }

      events.sort((a, b) {
        final bTime = b.createdAt.isNotEmpty ? b.createdAt : b.date;
        final aTime = a.createdAt.isNotEmpty ? a.createdAt : a.date;

        return bTime.compareTo(aTime);
      });

      if (events.length > limit) {
        return events.take(limit).toList();
      }

      return events;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const SdkException(
          'Permission denied. Please update Firestore rules for events.',
        );
      }

      throw SdkException(e.message ?? 'Failed to fetch events.');
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to fetch events: $e');
    }
  }

  static Future<EventModel> fetchEventDetail(String eventId) async {
    await _verifyVolunteer();

    final cleanId = eventId.trim();

    if (cleanId.isEmpty) {
      throw const SdkException('Event ID is missing.');
    }

    try {
      final snapshot =
          await _firestore.collection(eventsCollection).doc(cleanId).get();

      if (!snapshot.exists || snapshot.data() == null) {
        throw const SdkException('Event not found.');
      }

      return _mapSnapshotToEvent(snapshot);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const SdkException(
          'Permission denied. Please update Firestore rules for events.',
        );
      }

      throw SdkException(e.message ?? 'Failed to fetch event detail.');
    } catch (e) {
      if (e is SdkException) rethrow;

      throw SdkException('Failed to fetch event detail: $e');
    }
  }
}

class EventModel {
  final String eventId;
  final String title;
  final String description;
  final String location;
  final String date;
  final String time;
  final String organizer;
  final String bloodGroupNeeded;
  final int maxVolunteers;
  final String status;
  final String bannerUrl;
  final String createdAt;
  final String updatedAt;

  const EventModel({
    required this.eventId,
    required this.title,
    required this.description,
    required this.location,
    required this.date,
    required this.time,
    required this.organizer,
    required this.bloodGroupNeeded,
    required this.maxVolunteers,
    required this.status,
    required this.bannerUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventModel.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return EventModel(
      eventId: VolunteerEventSdk._readString(
        data,
        ['event_id', 'eventId', 'id'],
      ).isNotEmpty
          ? VolunteerEventSdk._readString(data, ['event_id', 'eventId', 'id'])
          : id,
      title: VolunteerEventSdk._readString(
        data,
        ['title', 'event_title', 'eventTitle'],
      ),
      description: VolunteerEventSdk._readString(
        data,
        ['description', 'event_description', 'eventDescription'],
      ),
      location: VolunteerEventSdk._readString(
        data,
        ['location', 'address', 'venue'],
      ),
      date: VolunteerEventSdk._readString(
        data,
        ['date', 'event_date', 'eventDate'],
      ),
      time: VolunteerEventSdk._readString(
        data,
        ['time', 'event_time', 'eventTime'],
      ),
      organizer: VolunteerEventSdk._readString(
        data,
        ['organizer', 'organizer_name', 'organizerName'],
      ),
      bloodGroupNeeded: VolunteerEventSdk._readString(
        data,
        ['blood_group_needed', 'bloodGroupNeeded', 'blood_group'],
      ),
      maxVolunteers: VolunteerEventSdk._readInt(
        data,
        ['max_volunteers', 'maxVolunteers', 'volunteers_required'],
      ),
      status: VolunteerEventSdk._readString(
        data,
        ['status'],
      ).isNotEmpty
          ? VolunteerEventSdk._readString(data, ['status'])
          : 'active',
      bannerUrl: VolunteerEventSdk._readString(
        data,
        ['banner_url', 'bannerUrl', 'image_url', 'imageUrl'],
      ),
      createdAt: VolunteerEventSdk._readString(
        data,
        ['created_at', 'createdAt'],
      ),
      updatedAt: VolunteerEventSdk._readString(
        data,
        ['updated_at', 'updatedAt'],
      ),
    );
  }
}