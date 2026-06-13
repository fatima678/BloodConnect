// lib/screens/Donor/notifications_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/sdk/core/sdk_exception.dart';
import 'package:blood_donation_app/sdk/donor/donor_notification_sdk.dart';

class DonorNotificationScreen extends StatefulWidget {
  static const String routeName = '/donor-notifications';

  const DonorNotificationScreen({super.key});

  @override
  State<DonorNotificationScreen> createState() =>
      _DonorNotificationScreenState();
}

class _DonorNotificationScreenState extends State<DonorNotificationScreen> {
  bool isLoading = true;
  String errorMessage = '';
  List<Map<String, dynamic>> notifications = [];

  static const String cacheKey = 'cached_donor_notifications';

  @override
  void initState() {
    super.initState();

    loadCachedNotifications().then((_) {
      fetchNotifications(showLoader: notifications.isEmpty);
    });
  }

  @override
  void deactivate() {
    _removeReadNotificationsFromLocalView();
    super.deactivate();
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
          .where((item) => item['is_read'] != true)
          .toList();

      if (!mounted) return;

      setState(() {
        notifications = cachedNotifications;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading donor cached notifications: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> cacheNotifications(List<Map<String, dynamic>> dataList) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final List<Map<String, dynamic>> unreadOnly = dataList
          .where((item) => item['is_read'] != true)
          .map<Map<String, dynamic>>(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();

      await prefs.setString(cacheKey, jsonEncode(unreadOnly));
    } catch (e) {
      debugPrint('Error caching donor notifications: $e');
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
          await DonorNotificationSdk.fetchDonorNotifications(
        limit: 50,
      );

      final List<Map<String, dynamic>> freshNotifications = freshList
          .where((item) => item['is_read'] != true)
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
      await DonorNotificationSdk.markAsRead(notificationId);
    } on SdkException catch (e) {
      debugPrint('Mark donor notification read SDK error: ${e.message}');
    } catch (e) {
      debugPrint('Mark donor notification read error: $e');
    }
  }

  Future<void> markNotificationViewed(
    Map<String, dynamic> item,
  ) async {
    final String notificationId =
        item['id']?.toString() ??
        item['notification_id']?.toString() ??
        '';

    setState(() {
      item['is_read'] = true;
    });

    await cacheNotifications(notifications);

    if (notificationId.trim().isNotEmpty) {
      await markAsRead(notificationId);
    }

    await _removeReadNotificationsFromLocalView();
  }

  Future<void> _removeReadNotificationsFromLocalView() async {
    if (notifications.isEmpty) return;

    final List<Map<String, dynamic>> unreadOnly = notifications
        .where((item) => item['is_read'] != true)
        .map<Map<String, dynamic>>(
          (item) => Map<String, dynamic>.from(item),
        )
        .toList();

    if (unreadOnly.length == notifications.length) {
      return;
    }

    await cacheNotifications(unreadOnly);

    if (!mounted) return;

    setState(() {
      notifications = unreadOnly;
    });
  }

  IconData getNotificationIcon(String? type) {
    switch (type) {
      case 'blood_request':
        return Icons.bloodtype;
      case 'donation_request_accepted':
        return Icons.verified;
      case 'donation_request_rejected':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color getNotificationColor(String? type) {
    switch (type) {
      case 'blood_request':
        return Colors.red;
      case 'donation_request_accepted':
        return Colors.green;
      case 'donation_request_rejected':
        return Colors.orange;
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

  String _readTitle(Map<String, dynamic> item) {
    final value = item['title']?.toString().trim();

    if (value != null && value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }

    return 'New Blood Request';
  }

  String _readBody(Map<String, dynamic> item) {
    final body = item['body']?.toString().trim();

    if (body != null && body.isNotEmpty && body.toLowerCase() != 'null') {
      return body;
    }

    final patientName = item['patient_name']?.toString().trim() ?? 'Patient';

    final bloodGroup =
        item['patient_blood_group']?.toString().trim().isNotEmpty == true
            ? item['patient_blood_group'].toString()
            : item['blood_group']?.toString().trim().isNotEmpty == true
                ? item['blood_group'].toString()
                : 'N/A';

    final hospital =
        item['hospital_name']?.toString().trim().isNotEmpty == true
            ? item['hospital_name'].toString()
            : 'Hospital not provided';

    final location =
        item['patient_location']?.toString().trim().isNotEmpty == true
            ? item['patient_location'].toString()
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
        backgroundColor: primaryMaroon,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await _removeReadNotificationsFromLocalView();
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
                        await _removeReadNotificationsFromLocalView();
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