import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;

    // Android Settings
    // Uses the default launcher icon that flutter create outputs
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      _initialized = true;
      debugPrint('NotificationService: successfully initialized.');
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      final iosImplementation =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped with payload: ${response.payload}');
  }

  // Placeholder methods for scheduling future notifications
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'arc_general_channel',
      'General Notifications',
      channelDescription: 'General reminders and announcements',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(id, title, body, details, payload: payload);
  }
}
