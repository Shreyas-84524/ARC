import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:arc/features/task_manager/models/task_model.dart';

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

  // Generate a stable positive 32-bit integer hash from task UUID
  int getStableHash(String input) {
    int hash = 5381;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF; // Restrict to 32-bit
    }
    // Mask to 29 bits positive to prevent overflow when multiplied by 3
    return (hash.abs() & 0x1FFFFFFF);
  }

  Future<void> scheduleTaskReminders(Task task) async {
    if (task.dueDate == null || task.dueTime == null) return;
    
    final date = task.dueDate!;
    final parts = task.dueTime!.split(':');
    if (parts.length != 2) return;
    
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final dueDateTime = DateTime(date.year, date.month, date.day, hour, minute);
    
    final baseId = getStableHash(task.id);
    final now = DateTime.now();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'arc_tasks_channel',
      'Task Reminders',
      channelDescription: 'Alerts and notifications for scheduled task due times',
      importance: Importance.max,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 1. One Hour Before
    final time1h = dueDateTime.subtract(const Duration(hours: 1));
    if (time1h.isAfter(now)) {
      await _localNotificationsPlugin.zonedSchedule(
        (baseId * 3) + 0,
        'Task Due in 1 hour',
        task.title,
        tz.TZDateTime.from(time1h, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Scheduled task notification (1h before): ID=${(baseId * 3) + 0} at $time1h');
    }

    // 2. 30 Minutes Before
    final time30m = dueDateTime.subtract(const Duration(minutes: 30));
    if (time30m.isAfter(now)) {
      await _localNotificationsPlugin.zonedSchedule(
        (baseId * 3) + 1,
        'Task Due in 30 minutes',
        task.title,
        tz.TZDateTime.from(time30m, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Scheduled task notification (30m before): ID=${(baseId * 3) + 1} at $time30m');
    }

    // 3. At Due Time
    if (dueDateTime.isAfter(now)) {
      await _localNotificationsPlugin.zonedSchedule(
        (baseId * 3) + 2,
        'Task Due Now',
        task.title,
        tz.TZDateTime.from(dueDateTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Scheduled task notification (due time): ID=${(baseId * 3) + 2} at $dueDateTime');
    }
  }

  Future<void> cancelTaskReminders(String taskId) async {
    final baseId = getStableHash(taskId);
    await _localNotificationsPlugin.cancel((baseId * 3) + 0);
    await _localNotificationsPlugin.cancel((baseId * 3) + 1);
    await _localNotificationsPlugin.cancel((baseId * 3) + 2);
    debugPrint('Canceled all notifications for task ID: $taskId');
  }

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
