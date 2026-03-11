import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'services/cart/cart_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/order_history_screen.dart';
  
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void handleDeepLink(dynamic data) {
  debugPrint("Click Detected! Payload: $data");

  if (data is Map && data.containsKey('orderId')) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAuth.instance
        .setPersistence(kIsWeb ? Persistence.LOCAL : Persistence.LOCAL);

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      await FirebaseMessaging.instance
          .requestPermission(alert: true, badge: true, sound: true);

      // 🚨 NATIVE ANDROID 13+ PERMISSION POPUP TRIGGER
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        importance: Importance.max,
      );

      // ⬜ ICON UPDATE NOTE: Jab aap transparent white logo bana lein,
      // toh '@mipmap/ic_launcher' ko badal kar '@drawable/ic_stat_notify' kar dijiyega.
      const initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await flutterLocalNotificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            try {
              final dynamic data = jsonDecode(response.payload!);
              handleDeepLink(data);
            } catch (e) {
              debugPrint("Failed to decode payload: $e");
            }
          }
        },
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  } catch (e) {
    debugPrint("Firebase Ignition Warning: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupInteractions();
  }

  Future<void> _setupInteractions() async {
    if (kIsWeb) return;

    // 📡 STATE 0: THE TOKEN RADAR (Automatically catches new tokens)
    FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) async {
      debugPrint("🔄 GHOST RADAR: New FCM Token Detected! $newToken");
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'fcmTokens': FieldValue.arrayUnion([newToken])
        });
      }
    });

    // STATE 1: App Killed
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        handleDeepLink(initialMessage.data);
      });
    }

    // STATE 2: App Background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleDeepLink(message.data);
    });

    // STATE 3: App Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          payload: jsonEncode(message.data),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel',
              'High Importance Notifications',
              icon: '@drawable/ic_stat_notify',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClickOut',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
