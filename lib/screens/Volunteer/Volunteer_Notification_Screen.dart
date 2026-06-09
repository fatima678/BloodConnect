import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VolunteerNotificationScreen extends StatelessWidget {
  final String? authToken;

  const VolunteerNotificationScreen({
    super.key,
    this.authToken,
  });

  @override
  Widget build(BuildContext context) {
    return VolunteerNotificationPage(authToken: authToken);
  }
}

class VolunteerNotificationPage extends StatefulWidget {
  final String? authToken;

  const VolunteerNotificationPage({
    super.key,
    this.authToken,
  });

  @override
  State<VolunteerNotificationPage> createState() =>
      _VolunteerNotificationPageState();
}

class _VolunteerNotificationPageState extends State<VolunteerNotificationPage> {
  static const String _baseUrl =
      'https://manliness-smugness-qualm.ngrok-free.dev/api';

  static const Color _maroon = Color(0xFF7B1020);
  static const Color _maroonDark = Color(0xFF5C0B17);
  static const Color _softWhite = Color(0xFFFAF7F8);
  static const Color _borderColor = Color(0xFFEAD8DC);

  String? _token;
  late Future<List<VolunteerNotificationModel>> _notificationsFuture;
  
  @override
  void initState() {
    super.initState();
    _notificationsFuture = _fetchNotifications();
  }

  Future<String> _getToken({bool forceRefresh = false}) async {
    final token = await _VolunteerAuthTokenHelper.getToken(
      providedToken: widget.authToken,
      forceRefresh: forceRefresh,
    );

    _token = token;
    return token;
  }

  Map<String, String> _headers(String token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',
    };
  }

  Future<http.Response> _authorizedGet(Uri uri) async {
    final token = await _getToken();

    http.Response response = await http
        .get(
          uri,
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 401 || response.statusCode == 403) {
      try {
        final freshToken = await _getToken(forceRefresh: true);

        response = await http
            .get(
              uri,
              headers: _headers(freshToken),
            )
            .timeout(const Duration(seconds: 25));
      } catch (_) {
        // Keep original response if refresh is not possible.
      }
    }

    return response;
  }

  Future<http.Response> _authorizedPatch(Uri uri) async {
    final token = await _getToken();

    http.Response response = await http
        .patch(
          uri,
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 401 || response.statusCode == 403) {
      try {
        final freshToken = await _getToken(forceRefresh: true);

        response = await http
            .patch(
              uri,
              headers: _headers(freshToken),
            )
            .timeout(const Duration(seconds: 25));
      } catch (_) {
        // Keep original response if refresh is not possible.
      }
    }

    return response;
  }

  Future<List<VolunteerNotificationModel>> _fetchNotifications() async {
    final uri = Uri.parse('$_baseUrl/volunteer/notifications');

    final response = await _authorizedGet(uri);
    final decoded = _decodeResponse(response.body);

    if (response.statusCode != 200) {
      final message = decoded is Map && decoded['message'] != null
          ? decoded['message'].toString()
          : 'Failed to fetch notifications.';

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw _AuthRequiredException(
          message.trim().isNotEmpty
              ? message
              : 'Session expired. Please login again.',
        );
      }

      throw Exception(message);
    }

    List dataList = [];

    if (decoded is Map && decoded['data'] is List) {
      dataList = decoded['data'] as List;
    } else if (decoded is List) {
      dataList = decoded;
    }

    final notifications = dataList
        .whereType<Map>()
        .map(
          (item) => VolunteerNotificationModel.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();

    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return notifications;
  }

  dynamic _decodeResponse(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {};
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;

    try {
      final uri = Uri.parse(
        '$_baseUrl/volunteer/notifications/${Uri.encodeComponent(notificationId)}/read',
      );

      await _authorizedPatch(uri);
    } catch (_) {
      // Silent fail. Detail screen should still open.
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _notificationsFuture = _fetchNotifications();
    });

    await _notificationsFuture;
  }

  void _openDetail(VolunteerNotificationModel notification) async {
    await _markAsRead(notification.notificationId);

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VolunteerNotificationDetailPage(
          notification: notification,
          authToken: _token,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _notificationsFuture = _fetchNotifications();
    });
  }

  bool _isAuthError(Object error) {
    final message = error.toString().toLowerCase();

    return error is _AuthRequiredException ||
        message.contains('authorization') ||
        message.contains('token') ||
        message.contains('expired') ||
        message.contains('unauthenticated') ||
        message.contains('invalid');
  }

  void _goToLogin() async {
    await _VolunteerAuthTokenHelper.clearSavedTokens();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/volunteer-login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softWhite,
      appBar: AppBar(
        backgroundColor: _maroon,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Volunteer Notifications',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<List<VolunteerNotificationModel>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: _maroon,
              ),
            );
          }

          if (snapshot.hasError) {
            final isAuthError = _isAuthError(snapshot.error!);

            return _ErrorView(
              message: snapshot.error.toString().replaceFirst('Exception: ', ''),
              onRetry: () {
                setState(() {
                  _notificationsFuture = _fetchNotifications();
                });
              },
              onLogin: isAuthError ? _goToLogin : null,
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return RefreshIndicator(
              color: _maroon,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 80,
                    color: _maroon,
                  ),
                  SizedBox(height: 18),
                  Center(
                    child: Text(
                      'No notifications found.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final unreadCount = notifications.where((item) => !item.isRead).length;

          return RefreshIndicator(
            color: _maroon,
            onRefresh: _refresh,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: _borderColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Total: ${notifications.length}',
                          style: const TextStyle(
                            color: _maroonDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: unreadCount > 0
                              ? _maroon.withOpacity(0.08)
                              : Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Unread: $unreadCount',
                          style: TextStyle(
                            color: unreadCount > 0 ? _maroon : Colors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = notifications[index];

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => _openDetail(item),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: item.isRead
                                  ? _borderColor
                                  : _maroon.withOpacity(0.35),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _maroon.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.bloodtype_rounded,
                                      color: _maroon,
                                      size: 28,
                                    ),
                                  ),
                                  if (!item.isRead)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: Container(
                                        width: 11,
                                        height: 11,
                                        decoration: BoxDecoration(
                                          color: _maroon,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.displayTitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _maroonDark,
                                        fontSize: 16,
                                        fontWeight: item.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      item.message.isNotEmpty
                                          ? item.message
                                          : 'Tap to view full detail.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13.5,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        if (item.bloodGroup.isNotEmpty)
                                          _SmallChip(
                                            text: item.bloodGroup,
                                            icon: Icons.water_drop_rounded,
                                          ),
                                        if (item.location.isNotEmpty)
                                          _SmallChip(
                                            text: item.location,
                                            icon: Icons.location_on_rounded,
                                          ),
                                        if (item.readableDate.isNotEmpty)
                                          _SmallChip(
                                            text: item.readableDate,
                                            icon: Icons.calendar_month_rounded,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 16,
                                color: Colors.black38,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class VolunteerNotificationDetailPage extends StatefulWidget {
  final VolunteerNotificationModel notification;
  final String? authToken;

  const VolunteerNotificationDetailPage({
    super.key,
    required this.notification,
    this.authToken,
  });

  @override
  State<VolunteerNotificationDetailPage> createState() =>
      _VolunteerNotificationDetailPageState();
}

class _VolunteerNotificationDetailPageState
    extends State<VolunteerNotificationDetailPage> {
  static const String _baseUrl =
      'https://manliness-smugness-qualm.ngrok-free.dev/api';

  static const Color _maroon = Color(0xFF7B1020);
  static const Color _maroonDark = Color(0xFF5C0B17);
  static const Color _softWhite = Color(0xFFFAF7F8);
  static const Color _borderColor = Color(0xFFEAD8DC);

  late Future<Map<String, dynamic>> _detailFuture;

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetail();
  }

  Future<String?> _getToken({bool forceRefresh = false}) async {
    try {
      return await _VolunteerAuthTokenHelper.getToken(
        providedToken: widget.authToken,
        forceRefresh: forceRefresh,
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _headers(String? token) {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };

    if (token != null && token.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${token.trim()}';
    }

    return headers;
  }

  Future<http.Response> _authorizedGet(Uri uri) async {
    final token = await _getToken();

    http.Response response = await http
        .get(
          uri,
          headers: _headers(token),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 401 || response.statusCode == 403) {
      try {
        final freshToken = await _getToken(forceRefresh: true);

        response = await http
            .get(
              uri,
              headers: _headers(freshToken),
            )
            .timeout(const Duration(seconds: 25));
      } catch (_) {
        // Keep original response if refresh is not possible.
      }
    }

    return response;
  }

  Future<Map<String, dynamic>> _loadDetail() async {
    final notificationMap = Map<String, dynamic>.from(widget.notification.raw);
    final eventId = widget.notification.eventId;

    if (eventId.isEmpty) {
      return notificationMap;
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl/admin/events/${Uri.encodeComponent(eventId)}',
      );

      final response = await _authorizedGet(uri);

      if (response.statusCode != 200) {
        return notificationMap;
      }

      final decoded = jsonDecode(response.body);

      Map<String, dynamic> eventMap = {};

      if (decoded is Map && decoded['data'] is Map) {
        eventMap = Map<String, dynamic>.from(decoded['data']);
      } else if (decoded is Map && decoded['event'] is Map) {
        eventMap = Map<String, dynamic>.from(decoded['event']);
      } else if (decoded is Map) {
        eventMap = Map<String, dynamic>.from(decoded);
      }

      return {
        ...notificationMap,
        ...eventMap,
      };
    } catch (_) {
      return notificationMap;
    }
  }

  String _first(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];

      if (value == null) continue;

      final text = value.toString().trim();

      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }

    return '';
  }

  String _formatDate(String raw) {
    if (raw.trim().isEmpty) return '';

    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;

      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();

      int hour = dt.hour;
      final minute = dt.minute.toString().padLeft(2, '0');
      final amPm = hour >= 12 ? 'PM' : 'AM';
      hour = hour % 12;
      if (hour == 0) hour = 12;

      return '$day-$month-$year  $hour:$minute $amPm';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _softWhite,
      appBar: AppBar(
        backgroundColor: _maroon,
        elevation: 0,
        title: const Text(
          'Notification Detail',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: _maroon,
              ),
            );
          }

          final data = snapshot.data ?? widget.notification.raw;

          final title = _first(data, [
            'event_title',
            'blood_bank_title',
            'blood_bank_name',
            'hospital_name',
            'title',
            'name',
          ]);

          final imageUrl = _first(data, [
            'image_url',
            'event_image_url',
            'event_image',
            'image',
            'img_url',
            'banner_url',
            'banner',
            'photo_url',
            'thumbnail',
            'cloudinary_url',
            'secure_url',
          ]);

          final message = _first(data, [
            'message',
            'short_message',
          ]);

          final description = _first(data, [
            'description',
            'event_description',
            'case_description',
            'details',
            'detail',
          ]);

          final organizer = _first(data, [
            'organizer',
            'organizer_name',
            'admin_name',
            'created_by',
          ]);

          final bloodBank = _first(data, [
            'blood_bank_title',
            'blood_bank_name',
            'hospital_name',
            'bank_name',
          ]);

          final bloodGroup = _first(data, [
            'blood_group',
            'blood_type',
            'required_blood_group',
          ]);

          final location = _first(data, [
            'location',
            'address',
            'city',
            'venue',
          ]);

          final date = _first(data, [
            'date',
            'event_date',
            'created_at',
          ]);

          final time = _first(data, [
            'time',
            'event_time',
          ]);

          final phone = _first(data, [
            'phone',
            'phone_number',
            'contact',
            'contact_number',
            'mobile',
          ]);

          final status = _first(data, [
            'status',
            'event_status',
          ]);

          final type = _first(data, [
            'type',
            'notification_type',
          ]);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      headers: const {
                        'ngrok-skip-browser-warning': 'true',
                      },
                      errorBuilder: (_, __, ___) => _ImagePlaceholder(),
                    ),
                  )
                else
                  _ImagePlaceholder(),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isNotEmpty ? title : 'Notification Detail',
                        style: const TextStyle(
                          color: _maroonDark,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          message,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _DetailCard(
                  title: 'Important Information',
                  children: [
                    if (bloodBank.isNotEmpty)
                      _DetailRow(
                        icon: Icons.local_hospital_rounded,
                        label: 'Blood Bank / Hospital',
                        value: bloodBank,
                      ),
                    if (bloodGroup.isNotEmpty)
                      _DetailRow(
                        icon: Icons.water_drop_rounded,
                        label: 'Blood Group',
                        value: bloodGroup,
                      ),
                    if (organizer.isNotEmpty)
                      _DetailRow(
                        icon: Icons.person_rounded,
                        label: 'Organizer',
                        value: organizer,
                      ),
                    if (location.isNotEmpty)
                      _DetailRow(
                        icon: Icons.location_on_rounded,
                        label: 'Location',
                        value: location,
                      ),
                    if (date.isNotEmpty)
                      _DetailRow(
                        icon: Icons.calendar_month_rounded,
                        label: 'Date',
                        value: _formatDate(date),
                      ),
                    if (time.isNotEmpty)
                      _DetailRow(
                        icon: Icons.access_time_rounded,
                        label: 'Time',
                        value: time,
                      ),
                    if (phone.isNotEmpty)
                      _DetailRow(
                        icon: Icons.phone_rounded,
                        label: 'Contact',
                        value: phone,
                      ),
                    if (status.isNotEmpty)
                      _DetailRow(
                        icon: Icons.verified_rounded,
                        label: 'Status',
                        value: status,
                      ),
                    if (type.isNotEmpty)
                      _DetailRow(
                        icon: Icons.notifications_rounded,
                        label: 'Type',
                        value: type,
                      ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Description',
                          style: TextStyle(
                            color: _maroonDark,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          description,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
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

  VolunteerNotificationModel({
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

        final text = value.toString().trim();

        if (text.isNotEmpty && text != 'null') {
          return text;
        }
      }

      return '';
    }

    DateTime parseDate() {
      final rawDate = first([
        'created_at',
        'date',
        'event_date',
      ]);

      final parsed = DateTime.tryParse(rawDate);
      return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    bool parseRead() {
      final value = flatMap['is_read'];

      if (value is bool) return value;

      if (value is String) {
        return value.toLowerCase() == 'true' || value == '1';
      }

      if (value is num) {
        return value == 1;
      }

      return false;
    }

    return VolunteerNotificationModel(
      notificationId: first([
        'notification_id',
        'id',
        'doc_id',
      ]),
      eventId: first([
        'event_id',
        'eventId',
      ]),
      title: first([
        'title',
        'notification_title',
      ]),
      message: first([
        'message',
        'body',
        'description',
      ]),
      bloodBankTitle: first([
        'blood_bank_title',
        'blood_bank_name',
        'hospital_name',
        'bank_name',
      ]),
      eventTitle: first([
        'event_title',
        'event_name',
      ]),
      bloodGroup: first([
        'blood_group',
        'blood_type',
        'required_blood_group',
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

class _VolunteerAuthTokenHelper {
  static const List<String> _tokenKeys = [
    'auth_token',
    'volunteer_auth_token',
    'volunteer_token',
    'token',
    'idToken',
    'id_token',
    'firebase_token',
    'firebase_id_token',
    'access_token',
    'bearer_token',
  ];

  static Future<String> getToken({
    String? providedToken,
    bool forceRefresh = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final directToken = _cleanToken(providedToken);

    if (directToken != null) {
      await _saveToken(prefs, directToken);
      return directToken;
    }

    if (!forceRefresh) {
      final savedToken = _readSavedToken(prefs);

      if (savedToken != null) {
        return savedToken;
      }
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final firebaseToken = await user.getIdToken(forceRefresh);
        final tokenText = (firebaseToken ?? '').trim();

        if (tokenText.isNotEmpty) {
          await _saveToken(prefs, tokenText);
          return tokenText;
        }
      }
    } catch (_) {
      // Continue to final auth error.
    }

    throw _AuthRequiredException(
      'Session not found. Please login again.',
    );
  }

  static String? _readSavedToken(SharedPreferences prefs) {
    for (final key in _tokenKeys) {
      final value = prefs.getString(key);
      final token = _cleanToken(value);

      if (token != null) {
        return token;
      }
    }

    for (final key in prefs.getKeys()) {
      final lowerKey = key.toLowerCase();

      if (lowerKey.contains('token') ||
          lowerKey.contains('bearer') ||
          lowerKey.contains('authorization')) {
        final value = prefs.get(key);

        if (value is String) {
          final token = _cleanToken(value);

          if (token != null) {
            return token;
          }
        }
      }
    }

    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);

      if (value is String) {
        final token = _extractTokenFromJsonString(value);

        if (token != null) {
          return token;
        }
      }
    }

    return null;
  }

  static String? _extractTokenFromJsonString(String value) {
    try {
      final decoded = jsonDecode(value);
      return _findTokenInDecoded(decoded);
    } catch (_) {
      return null;
    }
  }

  static String? _findTokenInDecoded(dynamic decoded) {
    if (decoded is Map) {
      for (final key in _tokenKeys) {
        final value = decoded[key];

        if (value is String) {
          final token = _cleanToken(value);

          if (token != null) {
            return token;
          }
        }
      }

      for (final entry in decoded.entries) {
        final keyText = entry.key.toString().toLowerCase();

        if (keyText.contains('token') ||
            keyText.contains('bearer') ||
            keyText.contains('authorization')) {
          if (entry.value is String) {
            final token = _cleanToken(entry.value.toString());

            if (token != null) {
              return token;
            }
          }
        }
      }

      for (final value in decoded.values) {
        final token = _findTokenInDecoded(value);

        if (token != null) {
          return token;
        }
      }
    }

    if (decoded is List) {
      for (final value in decoded) {
        final token = _findTokenInDecoded(value);

        if (token != null) {
          return token;
        }
      }
    }

    if (decoded is String) {
      final token = _cleanToken(decoded);

      if (token != null && token.startsWith('eyJ')) {
        return token;
      }
    }

    return null;
  }

  static String? _cleanToken(String? value) {
    if (value == null) return null;

    String token = value.trim();

    if (token.isEmpty || token == 'null') {
      return null;
    }

    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }

    if (token.length < 20) {
      return null;
    }

    return token;
  }

  static Future<void> _saveToken(
    SharedPreferences prefs,
    String token,
  ) async {
    await prefs.setString('auth_token', token);
    await prefs.setString('idToken', token);
    await prefs.setString('firebase_token', token);
  }

  static Future<void> clearSavedTokens() async {
    final prefs = await SharedPreferences.getInstance();

    for (final key in _tokenKeys) {
      await prefs.remove(key);
    }
  }
}

class _AuthRequiredException implements Exception {
  final String message;

  const _AuthRequiredException(this.message);

  @override
  String toString() => message;
}

class _SmallChip extends StatelessWidget {
  final String text;
  final IconData icon;

  const _SmallChip({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    const Color maroon = Color(0xFF7B1020);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: maroon.withOpacity(0.07),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: maroon,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: maroon,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    const Color maroonDark = Color(0xFF5C0B17);
    const Color borderColor = Color(0xFFEAD8DC);

    final visibleChildren = children.where((item) => item is! SizedBox).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: maroonDark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (visibleChildren.isEmpty)
            const Text(
              'No extra information available.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            )
          else
            ...visibleChildren,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    const Color maroon = Color(0xFF7B1020);

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: maroon.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: maroon,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const Color maroon = Color(0xFF7B1020);

    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFEAD8DC),
        ),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bloodtype_rounded,
            size: 64,
            color: maroon,
          ),
          SizedBox(height: 10),
          Text(
            'Blood Connect Notification',
            style: TextStyle(
              color: maroon,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onLogin;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    const Color maroon = Color(0xFF7B1020);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: maroon,
              size: 62,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: maroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (onLogin != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Login Again'),
                style: TextButton.styleFrom(
                  foregroundColor: maroon,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}