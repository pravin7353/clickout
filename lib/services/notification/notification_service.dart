import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart'; // Colors ke liye zaroori hai

// 🛑 BACKGROUND HANDLER
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🌙 Background Notification: ${message.notification?.title}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // 🚀 INITIALIZE FUNCTION
// 🚀 INITIALIZE FUNCTION (Updated)
  // 🚀 INITIALIZE FUNCTION (Fixed Parameter Name)
  Future<void> initialize() async {
    // 1. Permissions
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint("✅ Permission Granted");
    }

    // 2. Token Save
    await _saveToken();
    _fcm.onTokenRefresh.listen(_updateTokenInDatabase);

    // 3. Local Notifications Setup
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    // 🛠️ FIX IS HERE: 'initializationSettings' -> 'settings'
    await _localNotifications.initialize(
      settings: initSettings, // ✅ Correct Name
    );

    // 4. Foreground Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("☀️ Foreground Message: ${message.notification?.title}");
      _showLocalNotification(message);
    });
  }

  // 💾 SAVE TOKEN
  Future<void> _saveToken() async {
    String? token = await _fcm.getToken();
    if (token != null) {
      debugPrint("🔥 FCM Token: $token");
      await _updateTokenInDatabase(token);
    }
  }

  Future<void> _updateTokenInDatabase(String token) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // 🔔 SHOW NOTIFICATION
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      // 🛠️ FIX 2: 'const' hataya taaki Color error na aaye
      AndroidNotificationDetails androidDetails =
          const AndroidNotificationDetails(
        'clickout_channel',
        'ClickOut Notifications',
        channelDescription: 'Order updates and alerts',
        importance: Importance.max,
        priority: Priority.high,
        color: Color(0xFFC62828), // Cherry Red
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      // 🛠️ FIX 3: Named Arguments (id, title, body, notificationDetails) use kiye
      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: platformDetails,
      );
    }
  }
}
