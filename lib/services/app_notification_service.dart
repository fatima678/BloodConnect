import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _isLocalInitialized = false;

  static const AndroidNotificationChannel _channel =
      AndroidNotificationChannel(
    'blood_requests_channel',
    'Blood Requests',
    description: 'Blood donation request notifications',
    importance: Importance.max,
    playSound: true,
    showBadge: true,
  );

  static Future<void> initialize() async {
    await _initializeLocalNotifications();

    await _requestNotificationPermissions();

    await FirebaseMessaging.instance.setAutoInitEnabled(true);

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FOREGROUND FCM RECEIVED');
      debugPrint('Title: ${message.notification?.title}');
      debugPrint('Body: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');

      showNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('NOTIFICATION CLICKED FROM BACKGROUND');
      debugPrint('Data: ${message.data}');
    });

    final RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      debugPrint('APP OPENED FROM TERMINATED NOTIFICATION');
      debugPrint('Data: ${initialMessage.data}');
    }
  }

  static Future<void> initializeForBackground() async {
    await _initializeLocalNotifications();
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_isLocalInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification clicked payload: ${response.payload}');
      },
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(_channel);

    _isLocalInitialized = true;
  }

  static Future<void> _requestNotificationPermissions() async {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
  }

  static Future<void> showNotification(RemoteMessage message) async {
    final String title =
        message.notification?.title?.toString() ??
            message.data['title']?.toString() ??
            message.data['notification_title']?.toString() ??
            'Blood Connect';

    final String body =
        message.notification?.body?.toString() ??
            message.data['body']?.toString() ??
            message.data['message']?.toString() ??
            '';

    await showLocalNotification(
      title: title,
      body: body,
      payload: message.data.toString(),
    );
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _initializeLocalNotifications();

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'blood_requests_channel',
      'Blood Requests',
      channelDescription: 'Blood donation request notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }
}