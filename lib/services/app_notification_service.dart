import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

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

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await FirebaseMessaging.instance.setAutoInitEnabled(true);

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

  static Future<void> showNotification(RemoteMessage message) async {
    final String title =
        message.notification?.title?.toString() ??
        message.data['title']?.toString() ??
        'Notification';

    final String body =
        message.notification?.body?.toString() ??
        message.data['body']?.toString() ??
        '';

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
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: message.data.toString(),
    );
  }
}