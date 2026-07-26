import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
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
        AndroidInitializationSettings('@mipmap/launcher_icon');

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
      // Set local timezone location if possible
      try {
        final String timeZoneName = DateTime.now().timeZoneName;
        tz.setLocalLocation(tz.getLocation(timeZoneName));
      } catch (_) {
        // Fallback to default local timezone from tz.initializeTimeZones()
      }

      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create Android Notification Channels
      if (Platform.isAndroid) {
        final androidImplementation =
            _localNotificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        const AndroidNotificationChannel taskChannel = AndroidNotificationChannel(
          'arc_tasks_channel',
          'Task Reminders',
          description: 'Alerts and notifications for scheduled task due times',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        const AndroidNotificationChannel habitChannel = AndroidNotificationChannel(
          'arc_habits_reminder_channel',
          'Habit Reminders',
          description: 'Evening alerts for incomplete habits',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        const AndroidNotificationChannel moneyChannel = AndroidNotificationChannel(
          'arc_money_reminder_channel',
          'Money Reminders',
          description: 'Daily alerts to log transaction entries',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        await androidImplementation?.createNotificationChannel(taskChannel);
        await androidImplementation?.createNotificationChannel(habitChannel);
        await androidImplementation?.createNotificationChannel(moneyChannel);
      }

      _initialized = true;
      debugPrint('NotificationService: successfully initialized.');
      await scheduleDailyMoneyReminders();
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final notificationGranted =
          await androidImplementation?.requestNotificationsPermission() ?? false;
      final exactAlarmGranted =
          await androidImplementation?.requestExactAlarmsPermission() ?? false;
      debugPrint(
          'NotificationService permissions: Notifications=$notificationGranted, ExactAlarms=$exactAlarmGranted');
      return notificationGranted;
    } else if (Platform.isIOS) {
      final iosImplementation =
          _localNotificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      final granted = await iosImplementation?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return granted;
    }
    return true;
  }

  Future<void> showPermissionDeniedDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Permission Required'),
        content: const Text(
          'Project Arc needs notification permission to deliver timely task reminders and deadline alerts. Please enable notifications in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await requestPermissions();
            },
            child: const Text('Enable Notifications'),
          ),
        ],
      ),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('NotificationService: Notification tapped with payload: ${response.payload}');
  }

  // Generate a stable positive 32-bit integer hash from task UUID
  int getStableHash(String input) {
    int hash = 5381;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF; // Restrict to 32-bit
    }
    // Mask to 29 bits positive to prevent overflow
    return (hash.abs() & 0x1FFFFFFF);
  }

  String _getPriorityBadge(String priority) {
    switch (priority) {
      case 'High':
        return '🔴 High Priority';
      case 'Much':
        return '🟠 Must Priority';
      case 'Low':
      default:
        return '🟡 Low Priority';
    }
  }

  Future<void> scheduleTaskReminders(Task task) async {
    if (task.completed || task.dueDate == null || task.dueTime == null) {
      await cancelTaskReminders(task.id);
      return;
    }

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
      playSound: true,
      enableVibration: true,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final formattedTime = DateFormat('h:mm a').format(dueDateTime);
    final priorityBadge = _getPriorityBadge(task.priority);

    // Cancel existing scheduled notifications to prevent duplicates
    await cancelTaskReminders(task.id);

    // 1. Notification 1: 5 Minutes Before Deadline
    final time5m = dueDateTime.subtract(const Duration(minutes: 5));
    final id5m = (baseId * 2) + 0;
    if (time5m.isAfter(now)) {
      final String body5m =
          "Only 5 minutes left!\nComplete your task before the deadline.\n\nTask: ${task.title}\nPriority: $priorityBadge\nDue: $formattedTime";
      await _localNotificationsPlugin.zonedSchedule(
        id5m,
        '⏰ Task Reminder',
        body5m,
        tz.TZDateTime.from(time5m, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
        'NotificationService: Scheduled 5m reminder (ID: $id5m, TaskID: ${task.id}, Title: "${task.title}") for $time5m',
      );
    }

    // 2. Notification 2: Deadline Reached
    final idDeadline = (baseId * 2) + 1;
    if (dueDateTime.isAfter(now)) {
      final String bodyDeadline =
          "The deadline for this task has been reached.\nPlease complete it as soon as possible.\n\nTask: ${task.title}\nPriority: $priorityBadge\nDeadline: $formattedTime";
      await _localNotificationsPlugin.zonedSchedule(
        idDeadline,
        '🚨 Task Deadline Reached',
        bodyDeadline,
        tz.TZDateTime.from(dueDateTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
        'NotificationService: Scheduled Deadline reminder (ID: $idDeadline, TaskID: ${task.id}, Title: "${task.title}") for $dueDateTime',
      );
    }
  }

  Future<void> cancelTaskReminders(String taskId) async {
    final baseId = getStableHash(taskId);
    await _localNotificationsPlugin.cancel((baseId * 2) + 0);
    await _localNotificationsPlugin.cancel((baseId * 2) + 1);
    // Also cancel legacy multipliers
    await _localNotificationsPlugin.cancel((baseId * 3) + 0);
    await _localNotificationsPlugin.cancel((baseId * 3) + 1);
    await _localNotificationsPlugin.cancel((baseId * 3) + 2);
    debugPrint('NotificationService: Canceled reminders for Task ID: $taskId');
  }

  Future<void> scheduleEveningReminder(int incompleteCount) async {
    if (incompleteCount <= 0) {
      await cancelEveningReminder();
      return;
    }

    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 20, 0); // 8:00 PM
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'arc_habits_reminder_channel',
      'Habit Reminders',
      channelDescription: 'Evening alerts for incomplete habits',
      importance: Importance.max,
      priority: Priority.high,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.zonedSchedule(
      999999,
      'Incomplete Habits Left!',
      'You still have $incompleteCount habits left to complete today. Keep your streak alive!',
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('NotificationService: Scheduled evening habit reminder for $scheduledTime');
  }

  Future<void> cancelEveningReminder() async {
    await _localNotificationsPlugin.cancel(999999);
    debugPrint('NotificationService: Canceled evening habit reminder.');
  }

  Future<void> scheduleDailyMoneyReminders({bool hasTodayTx = false}) async {
    try {
      final now = DateTime.now();

      // 8 PM Daily Reminder
      var time8pm = DateTime(now.year, now.month, now.day, 20, 0);
      if (time8pm.isBefore(now)) {
        time8pm = time8pm.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'arc_money_reminder_channel',
        'Money Reminders',
        channelDescription: 'Daily alerts to log transaction entries',
        importance: Importance.max,
        priority: Priority.high,
      );
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule 8 PM Daily
      await _localNotificationsPlugin.zonedSchedule(
        888888,
        "Money Tracker",
        "Have you recorded today's transactions?",
        tz.TZDateTime.from(time8pm, tz.local),
        details,
        matchDateTimeComponents: DateTimeComponents.time,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (hasTodayTx) {
        await _localNotificationsPlugin.cancel(101010);
        debugPrint('NotificationService: Transactions recorded for today. Canceled 10 PM money reminder.');
      } else {
        // 10 PM Daily Reminder
        var time10pm = DateTime(now.year, now.month, now.day, 22, 0);
        if (time10pm.isBefore(now)) {
          time10pm = time10pm.add(const Duration(days: 1));
        }

        await _localNotificationsPlugin.zonedSchedule(
          101010,
          "Money Tracker - Final Reminder",
          "Don't forget to log your daily expenses to keep your balance up to date!",
          tz.TZDateTime.from(time10pm, tz.local),
          details,
          matchDateTimeComponents: DateTimeComponents.time,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint('NotificationService: Scheduled 10 PM final money reminder.');
      }
    } catch (e) {
      debugPrint('NotificationService: scheduleDailyMoneyReminders exception: $e');
    }
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
