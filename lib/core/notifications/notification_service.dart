import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/routes/app_router.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  tz.Location _ensureLocalTimezone() {
    tz.initializeTimeZones();
    try {
      final location = tz.getLocation('Asia/Kolkata');
      tz.setLocalLocation(location);
      return location;
    } catch (e) {
      try {
        final utc = tz.getLocation('UTC');
        tz.setLocalLocation(utc);
        return utc;
      } catch (_) {
        return tz.UTC;
      }
    }
  }

  Future<void> _configureLocalTimezone() async {
    final location = _ensureLocalTimezone();
    debugPrint('NotificationService: Local timezone verified as ${location.name}.');
  }

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
      await _configureLocalTimezone();

      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create Android Notification Channels
      if (Platform.isAndroid) {
        final androidImplementation =
            _localNotificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        const AndroidNotificationChannel remindersChannel = AndroidNotificationChannel(
          'arc_reminders_channel',
          'Project Arc Reminders',
          description: 'Task and Habit Reminder Notifications',
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

        await androidImplementation?.createNotificationChannel(remindersChannel);
        await androidImplementation?.createNotificationChannel(moneyChannel);
      }

      _initialized = true;
      debugPrint('NotificationService: Core plugin & high-importance channels successfully initialized.');

      // Non-blocking initial reminder scheduling in isolated try-catch
      try {
        await scheduleDailyMoneyReminders();
      } catch (e) {
        debugPrint('NotificationService: Non-blocking warning during initial money reminder schedule: $e');
      }
    } catch (e) {
      debugPrint('NotificationService: Engine initialization notice (app will continue): $e');
      _initialized = true;
    }
  }

  Future<bool> requestPermissions() async {
    try {
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
    } catch (e) {
      debugPrint('NotificationService: Permission request warning: $e');
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
    if (response.payload == null || response.payload!.isEmpty) return;

    try {
      final data = jsonDecode(response.payload!);
      final type = data['type'];
      final id = data['id'];

      if (type == 'task') {
        debugPrint('NotificationService: Direct navigation to Task Manager for Task ID: $id');
        appRouter.go('/tasks');
      } else if (type == 'habit') {
        debugPrint('NotificationService: Direct navigation to Habit Tracker for Habit ID: $id');
        appRouter.go('/habits');
      }
    } catch (e) {
      debugPrint('NotificationService: Error parsing notification payload: $e');
    }
  }

  Future<void> checkAppLaunchNotification() async {
    try {
      final details =
          await _localNotificationsPlugin.getNotificationAppLaunchDetails();
      if (details != null &&
          details.didNotificationLaunchApp &&
          details.notificationResponse != null) {
        debugPrint(
            'NotificationService: App cold launched from notification payload: ${details.notificationResponse!.payload}');
        _onNotificationTapped(details.notificationResponse!);
      }
    } catch (e) {
      debugPrint('NotificationService checkAppLaunchNotification warning: $e');
    }
  }

  // Generate a stable positive 32-bit integer hash from task UUID
  int getStableHash(String input) {
    int hash = 5381;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
      hash = hash & 0xFFFFFFFF; // Restrict to 32-bit
    }
    return (hash.abs() & 0x1FFFFFFF);
  }

  String _getPriorityBadge(String priority) {
    switch (priority) {
      case 'High':
        return '🔴 High Priority';
      case 'Must':
      case 'Much':
        return '🟠 Must Priority';
      case 'Low':
      default:
        return '🟡 Low Priority';
    }
  }

  // Safe zoned schedule wrapper handling exact alarm availability and fallback
  Future<void> _safeZonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    bool canScheduleExact = true;
    if (Platform.isAndroid) {
      try {
        final androidImplementation =
            _localNotificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final exactPermission =
            await androidImplementation?.canScheduleExactNotifications();
        if (exactPermission != null && !exactPermission) {
          canScheduleExact = false;
        }
      } catch (e) {
        debugPrint('NotificationService: Exact alarm check warning: $e');
      }
    }

    final primaryMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      await _localNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: primaryMode,
        uiLocalNotificationDateInterpretation: uiLocalNotificationDateInterpretation,
        payload: payload,
        matchDateTimeComponents: matchDateTimeComponents,
      );
      debugPrint(
        'NotificationService: Scheduled notification ID $id for $scheduledDate (mode: $primaryMode)',
      );
    } catch (e) {
      debugPrint(
        'NotificationService: Primary scheduling ($primaryMode) failed for ID $id ($e). Attempting inexact fallback...',
      );
      try {
        await _localNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: uiLocalNotificationDateInterpretation,
          payload: payload,
          matchDateTimeComponents: matchDateTimeComponents,
        );
        debugPrint(
          'NotificationService: Inexact fallback scheduling succeeded for ID $id at $scheduledDate',
        );
      } catch (fallbackError) {
        debugPrint(
          'NotificationService: Both exact and inexact scheduling failed for ID $id: $fallbackError',
        );
      }
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
      'arc_reminders_channel',
      'Project Arc Reminders',
      channelDescription: 'Task and Habit Reminder Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
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
    final payload = jsonEncode({'type': 'task', 'id': task.id});

    // Cancel existing scheduled notifications to prevent duplicates
    await cancelTaskReminders(task.id);

    final currentZone = _ensureLocalTimezone();

    // 1. Notification 1: 5 Minutes Before Deadline
    final time5m = dueDateTime.subtract(const Duration(minutes: 5));
    final id5m = (baseId * 2) + 0;
    if (time5m.isAfter(now)) {
      final String body5m =
          "Only 5 minutes left!\n\nTask: ${task.title}\nPriority: $priorityBadge\nDeadline: $formattedTime";
      await _safeZonedSchedule(
        id5m,
        '⏰ Task Reminder',
        body5m,
        tz.TZDateTime.from(time5m, currentZone),
        details,
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
        'NotificationService: Scheduled 5m system notification (ID: $id5m, TaskID: ${task.id}, Title: "${task.title}") for $time5m',
      );
    }

    // 2. Notification 2: Deadline Reached
    final idDeadline = (baseId * 2) + 1;
    if (dueDateTime.isAfter(now)) {
      final String bodyDeadline =
          "The deadline has been reached.\nPlease complete this task as soon as possible.\n\nTask: ${task.title}\nPriority: $priorityBadge";
      await _safeZonedSchedule(
        idDeadline,
        '🚨 Task Deadline Reached',
        bodyDeadline,
        tz.TZDateTime.from(dueDateTime, currentZone),
        details,
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint(
        'NotificationService: Scheduled Deadline system notification (ID: $idDeadline, TaskID: ${task.id}, Title: "${task.title}") for $dueDateTime',
      );
    }
  }

  Future<void> cancelTaskReminders(String taskId) async {
    try {
      final baseId = getStableHash(taskId);
      await _localNotificationsPlugin.cancel((baseId * 2) + 0);
      await _localNotificationsPlugin.cancel((baseId * 2) + 1);
      await _localNotificationsPlugin.cancel((baseId * 3) + 0);
      await _localNotificationsPlugin.cancel((baseId * 3) + 1);
      await _localNotificationsPlugin.cancel((baseId * 3) + 2);
      debugPrint('NotificationService: Canceled all system reminders for Task ID: $taskId');
    } catch (e) {
      debugPrint('NotificationService cancelTaskReminders notice: $e');
    }
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
      'arc_reminders_channel',
      'Project Arc Reminders',
      channelDescription: 'Task and Habit Reminder Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({'type': 'habit', 'id': 'evening_habit'});
    final currentZone = _ensureLocalTimezone();

    await _safeZonedSchedule(
      999999,
      '🌱 Habit Reminder',
      "Don't forget today's habit.\n\nYou have $incompleteCount incomplete habits left for today.",
      tz.TZDateTime.from(scheduledTime, currentZone),
      details,
      payload: payload,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    debugPrint('NotificationService: Scheduled system evening habit reminder for $scheduledTime');
  }

  Future<void> cancelEveningReminder() async {
    try {
      await _localNotificationsPlugin.cancel(999999);
      debugPrint('NotificationService: Canceled evening habit reminder.');
    } catch (e) {
      debugPrint('NotificationService cancelEveningReminder notice: $e');
    }
  }

  Future<void> scheduleDailyMoneyReminders({bool hasTodayTx = false}) async {
    try {
      final now = DateTime.now();
      final currentZone = _ensureLocalTimezone();

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
        visibility: NotificationVisibility.public,
      );
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Schedule 8 PM Daily
      await _safeZonedSchedule(
        888888,
        "Money Tracker",
        "Have you recorded today's transactions?",
        tz.TZDateTime.from(time8pm, currentZone),
        details,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      if (hasTodayTx) {
        try {
          await _localNotificationsPlugin.cancel(101010);
        } catch (_) {}
        debugPrint('NotificationService: Transactions recorded for today. Canceled 10 PM money reminder.');
      } else {
        // 10 PM Daily Reminder
        var time10pm = DateTime(now.year, now.month, now.day, 22, 0);
        if (time10pm.isBefore(now)) {
          time10pm = time10pm.add(const Duration(days: 1));
        }

        await _safeZonedSchedule(
          101010,
          "Money Tracker - Final Reminder",
          "Don't forget to log your daily expenses to keep your balance up to date!",
          tz.TZDateTime.from(time10pm, currentZone),
          details,
          matchDateTimeComponents: DateTimeComponents.time,
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
      'arc_reminders_channel',
      'Project Arc Reminders',
      channelDescription: 'Task and Habit Reminder Notifications',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotificationsPlugin.show(id, title, body, details, payload: payload);
    } catch (e) {
      debugPrint('NotificationService showInstantNotification notice: $e');
    }
  }
}
