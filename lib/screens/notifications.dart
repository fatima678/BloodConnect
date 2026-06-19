import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/sdk/core/sdk_exception.dart';
import 'package:blood_donation_app/sdk/general_notification_sdk.dart';

class NotificationScreen extends StatefulWidget {
  static const String routeName = '/notifications';

  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool isLoading = true;
  String errorMessage = '';
  List<Map<String, dynamic>> notifications = [];

  String get cacheKey {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'cached_notifications_$uid';
  }

  @override
  void initState() {
    super.initState();

    loadCachedNotifications().then((_) {
      fetchNotifications(showLoader: notifications.isEmpty);
    });
  }

  Future<void> loadCachedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString(cacheKey);

      if (cachedData == null || cachedData.trim().isEmpty) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        return;
      }

      final decoded = jsonDecode(cachedData);

      if (decoded is! List) {
        if (!mounted) return;

        setState(() {
          isLoading = false;
        });

        return;
      }

      final List<Map<String, dynamic>> cachedNotifications = decoded
          .map<Map<String, dynamic>>(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        notifications = cachedNotifications;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading cached notifications: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> cacheNotifications(List<Map<String, dynamic>> dataList) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final List<Map<String, dynamic>> cleanList = dataList
          .map<Map<String, dynamic>>(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();

      await prefs.setString(cacheKey, jsonEncode(cleanList));
    } catch (e) {
      debugPrint('Error caching notifications: $e');
    }
  }

  Future<void> fetchNotifications({bool showLoader = true}) async {
    if (showLoader && notifications.isEmpty) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    } else {
      setState(() {
        errorMessage = '';
      });
    }

    try {
      final List<Map<String, dynamic>> freshList =
          await GeneralNotificationSdk.fetchMyNotifications(
        limit: 50,
      );

      final List<Map<String, dynamic>> freshNotifications = freshList
          .map<Map<String, dynamic>>(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();

      if (!mounted) return;

      setState(() {
        notifications = freshNotifications;
        errorMessage = '';
        isLoading = false;
      });

      await cacheNotifications(freshNotifications);
    } on SdkException catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = notifications.isEmpty ? e.message : '';
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = notifications.isEmpty ? 'Error: $e' : '';
        isLoading = false;
      });
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.trim().isEmpty) return;

    try {
      await GeneralNotificationSdk.markAsRead(notificationId);
    } on SdkException catch (e) {
      debugPrint('Mark notification read SDK error: ${e.message}');
    } catch (e) {
      debugPrint('Mark notification read error: $e');
    }
  }

  Future<void> markNotificationViewed(
    Map<String, dynamic> item,
  ) async {
    final String notificationId = item['id']?.toString() ??
        item['notification_id']?.toString() ??
        '';

    setState(() {
      item['is_read'] = true;
    });

    await cacheNotifications(notifications);

    if (notificationId.trim().isNotEmpty) {
      await markAsRead(notificationId);
    }
  }

  IconData getNotificationIcon(String? type) {
    switch (type) {
      case 'blood_request':
      case 'new_blood_request':
        return Icons.bloodtype;

      case 'request_accepted':
      case 'donation_request_accepted':
      case 'blood_request_accepted':
      case 'donor_request_accepted':
        return Icons.verified;

      case 'request_rejected':
      case 'donation_request_rejected':
      case 'blood_request_rejected':
      case 'donor_request_rejected':
        return Icons.cancel;

      case 'donor_response':
        return Icons.volunteer_activism;

      default:
        return Icons.notifications;
    }
  }

  Color getNotificationColor(String? type) {
    switch (type) {
      case 'blood_request':
      case 'new_blood_request':
        return Colors.red;

      case 'request_accepted':
      case 'donation_request_accepted':
      case 'blood_request_accepted':
      case 'donor_request_accepted':
        return Colors.green;

      case 'request_rejected':
      case 'donation_request_rejected':
      case 'blood_request_rejected':
      case 'donor_request_rejected':
        return Colors.orange;

      case 'donor_response':
        return Colors.blue;

      default:
        return primaryMaroon;
    }
  }

  String formatTime(dynamic value) {
    if (value == null) return '';

    final text = value.toString();

    try {
      final date = DateTime.parse(text).toLocal();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays == 1) return 'Yesterday';

      return '${difference.inDays}d ago';
    } catch (_) {
      return text;
    }
  }

  String _cleanString(dynamic value) {
    if (value == null) return '';

    final String text = value.toString().trim();

    if (text.isEmpty || text.toLowerCase() == 'null') {
      return '';
    }

    return text;
  }

  String _readTitle(Map<String, dynamic> item) {
    final String value = _cleanString(item['title']);

    if (value.isNotEmpty) {
      return value;
    }

    final String type = _cleanString(item['type']);

    switch (type) {
      case 'blood_request':
      case 'new_blood_request':
        return 'New Blood Request';

      case 'request_accepted':
      case 'donation_request_accepted':
      case 'blood_request_accepted':
      case 'donor_request_accepted':
        return 'Request Accepted';

      case 'request_rejected':
      case 'donation_request_rejected':
      case 'blood_request_rejected':
      case 'donor_request_rejected':
        return 'Request Rejected';

      default:
        return 'New Notification';
    }
  }

  String _readBody(Map<String, dynamic> item) {
    final String body = _cleanString(item['body']);

    if (body.isNotEmpty) {
      return body;
    }

    final String message = _cleanString(item['message']);

    if (message.isNotEmpty) {
      return message;
    }

    final String type = _cleanString(item['type']);

    if (type == 'request_accepted' ||
        type == 'donation_request_accepted' ||
        type == 'blood_request_accepted' ||
        type == 'donor_request_accepted') {
      final String donorName = _cleanString(item['donor_name']);
      final String donorPhone = _cleanString(item['donor_phone']);

      if (donorName.isNotEmpty) {
        return donorPhone.isNotEmpty
            ? '$donorName accepted your blood request. Phone: $donorPhone'
            : '$donorName accepted your blood request.';
      }

      return 'A donor accepted your blood request.';
    }

    if (type == 'request_rejected' ||
        type == 'donation_request_rejected' ||
        type == 'blood_request_rejected' ||
        type == 'donor_request_rejected') {
      final String donorName = _cleanString(item['donor_name']);

      if (donorName.isNotEmpty) {
        return '$donorName rejected your blood request.';
      }

      return 'Your blood request was rejected.';
    }

    final String patientName = _cleanString(item['patient_name']).isNotEmpty
        ? _cleanString(item['patient_name'])
        : 'Patient';

    final String bloodGroup = _cleanString(item['patient_blood_group']).isNotEmpty
        ? _cleanString(item['patient_blood_group'])
        : _cleanString(item['blood_group']).isNotEmpty
            ? _cleanString(item['blood_group'])
            : 'N/A';

    final String hospital = _cleanString(item['hospital_name']).isNotEmpty
        ? _cleanString(item['hospital_name'])
        : 'Hospital not provided';

    final String location = _cleanString(item['patient_location']).isNotEmpty
        ? _cleanString(item['patient_location'])
        : _cleanString(item['location']).isNotEmpty
            ? _cleanString(item['location'])
            : 'Location not provided';

    return '$patientName needs $bloodGroup blood at $hospital. Location: $location';
  }

  Widget buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 12),
          Text(
            'No notifications yet',
            style: TextStyle(fontSize: 17, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget buildNotificationTile(Map<String, dynamic> item) {
    final String title = _readTitle(item);
    final String body = _readBody(item);
    final String? type = item['type']?.toString();
    final bool isRead = item['is_read'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 0 : 2,
      color: isRead ? Colors.white : const Color(0xFFFFF7F7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead
              ? Colors.grey.shade200
              : getNotificationColor(type).withOpacity(0.25),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: getNotificationColor(type).withOpacity(0.12),
          child: Icon(
            getNotificationIcon(type),
            color: getNotificationColor(type),
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            body,
            style: const TextStyle(color: Colors.black54),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formatTime(item['created_at']),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            if (!isRead) ...[
              const SizedBox(height: 6),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: primaryMaroon,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          markNotificationViewed(item);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await fetchNotifications(showLoader: false);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty && notifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: () => fetchNotifications(showLoader: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : notifications.isEmpty
                  ? buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: () async {
                        await fetchNotifications(showLoader: false);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          return buildNotificationTile(notifications[index]);
                        },
                      ),
                    ),
    );
  }
}