import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'theme.dart';
import 'routes.dart';
import 'services/app_notification_service.dart';
import 'services/firestore_notification_listener_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();

    debugPrint('BACKGROUND FCM RECEIVED');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');
    debugPrint('Data: ${message.data}');

    await AppNotificationService.initializeForBackground();

    if (message.notification == null) {
      await AppNotificationService.showNotification(message);
    }
  } catch (e) {
    debugPrint('Background FCM handler error: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully.');

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await AppNotificationService.initialize();
    debugPrint('Notification service initialized successfully.');

    FirestoreNotificationListenerService.start();
    debugPrint('Firestore notification listener started.');
  } catch (e) {
    debugPrint('Firebase/Notification initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryMaroon,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryMaroon,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}