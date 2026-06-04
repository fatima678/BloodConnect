// lib/screens/notifications_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Cache ke liye import kiya
import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

class PatientNotificationsScreen extends StatefulWidget {
  static const String routeName = '/notifications';

  const PatientNotificationsScreen({super.key});

  @override
  State<PatientNotificationsScreen> createState() =>
      _PatientNotificationsScreenState();
}

class _PatientNotificationsScreenState
    extends State<PatientNotificationsScreen> {
  String errorMessage = '';
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    // 1. Instantly local cache se purana data load karo (0 milliseconds lagenge)
    loadCachedNotifications().then((_) {
      // 2. Uske baad background mein silently server se naya data fetch karo
      fetchNotifications();
    });
  }

  // Local device storage se data uthane ka function
  Future<void> loadCachedNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString('cached_patient_notifications');
      
      if (cachedData != null) {
        final List decodedList = jsonDecode(cachedData);
        setState(() {
          notifications = decodedList
              .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading cached data: $e');
    }
  }

  // Local storage me data save karne ka function
  Future<void> cacheNotifications(List<Map<String, dynamic>> dataList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_patient_notifications', jsonEncode(dataList));
    } catch (e) {
      debugPrint('Error caching data: $e');
    }
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await AuthTokenService.authorizedGet(
        '/notifications?role=patient&limit=50',
      );

      debugPrint('Patient Notifications Status: ${response.statusCode}');

      Map<String, dynamic> body = {};
      try {
        body = jsonDecode(response.body);
      } catch (_) {}

      if (!mounted) return;

      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] is List ? body['data'] : [];
        
        final List<Map<String, dynamic>> freshNotifications = list
            .map<Map<String, dynamic>>((item) => Map<String, dynamic>.from(item))
            .toList();

        setState(() {
          notifications = freshNotifications;
          errorMessage = '';
        });

        // Naye data ko local cache me save karlo taaki agli baar ye instantly dikhe
        cacheNotifications(freshNotifications);
      } else {
        if (notifications.isEmpty) {
          setState(() {
            errorMessage = body['message'] ?? 'Failed to fetch notifications.';
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (notifications.isEmpty) {
        setState(() {
          errorMessage = 'Connection Error: $e';
        });
      }
    }
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      await AuthTokenService.authorizedPut(
        '/notifications/$notificationId/read',
        {},
      );
    } catch (e) {
      debugPrint('Mark patient notification read error: $e');
    }
  }

  IconData getNotificationIcon(String? type) {
    switch (type) {
      case 'donation_request_accepted':
        return Icons.verified;
      case 'donation_request_rejected':
        return Icons.cancel;
      case 'blood_request':
        return Icons.bloodtype;
      default:
        return Icons.notifications;
    }
  }

  Color getNotificationColor(String? type) {
    switch (type) {
      case 'donation_request_accepted':
        return Colors.green;
      case 'donation_request_rejected':
        return Colors.red;
      case 'blood_request':
        return Colors.red;
      default:
        return primaryMaroon;
    }
  }

  String formatTime(dynamic value) {
    if (value == null) return '';
    final String text = value.toString();
    try {
      final DateTime date = DateTime.parse(text).toLocal();
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays == 1) return 'Yesterday';

      return '${difference.inDays}d ago';
    } catch (_) {
      return text;
    }
  }

  String getFriendlyTitle(String? type, String title) {
    switch (type) {
      case 'donation_request_accepted':
        return 'Request Accepted';
      case 'donation_request_rejected':
        return 'Request Rejected';
      default:
        return title;
    }
  }

  Widget buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 80, color: Colors.grey),
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
    final String id = item['id']?.toString() ?? '';
    final String title = item['title']?.toString() ?? 'Notification';
    final String body = item['body']?.toString() ?? '';
    final String? type = item['type']?.toString();
    final bool isRead = item['is_read'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isRead ? 0 : 2,
      color: isRead ? Colors.white : const Color(0xFFF8FFF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead
              ? Colors.grey.shade200
              : getNotificationColor(type).withOpacity(0.25),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: getNotificationColor(type).withOpacity(0.12),
          child: Icon(getNotificationIcon(type), color: getNotificationColor(type)),
        ),
        title: Text(
          getFriendlyTitle(type, title),
          style: TextStyle(
            fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(body, style: const TextStyle(color: Colors.black54)),
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
                decoration: const BoxDecoration(color: primaryMaroon, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
        onTap: () {
          // Optimistic UI Update: Instantly read ho jayega bina response ke wait kiye
          setState(() {
            item['is_read'] = true;
          });
          markAsRead(id);
          cacheNotifications(notifications); // Updates local storage read status state
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
            onPressed: fetchNotifications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: errorMessage.isNotEmpty && notifications.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: fetchNotifications,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : notifications.isEmpty
              ? const SizedBox.shrink() // Jab tak local memory bilkul khali hai tab tak silent blank tile build hogi
              : RefreshIndicator(
                  onRefresh: fetchNotifications,
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