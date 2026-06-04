// lib/screens/Donor/notifications_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:blood_donation_app/theme.dart';
import 'package:blood_donation_app/services/auth_token_service.dart';

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

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await AuthTokenService.authorizedGet(
        '/notifications?role=donor&limit=50',
      );

      debugPrint('Donor Notifications Status: ${response.statusCode}');
      debugPrint('Donor Notifications Body: ${response.body}');

      Map<String, dynamic> body = {};

      try {
        body = jsonDecode(response.body);
      } catch (_) {
        body = {};
      }

      if (!mounted) return;

      if (response.statusCode == 200 && body['success'] == true) {
        final List list = body['data'] is List ? body['data'] : [];

        setState(() {
          notifications = list
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item),
              )
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = body['message'] ?? 'Failed to fetch notifications.';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Connection Error: $e';
        isLoading = false;
      });
    }
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
    final String title = item['title']?.toString() ?? 'Notification';
    final String body = item['body']?.toString() ?? '';
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
        trailing: Text(
          formatTime(item['created_at']),
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
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
                          onPressed: fetchNotifications,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : notifications.isEmpty
                  ? buildEmptyState()
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