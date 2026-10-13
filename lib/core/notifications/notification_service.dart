import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
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
      final tzName = DateTime.now().timeZoneName;

      // 1. Direct match if it's already a valid Olson identifier (macOS/Linux/Android)
      if (tzName.isNotEmpty) {
        try {
          final location = tz.getLocation(tzName);
          tz.setLocalLocation(location);
          return location;
        } catch (_) {}
      }

      // 2. Map standard Windows and abbreviated timezone names to canonical Olson locations
      const Map<String, String> commonNameMap = {
        'India Standard Time': 'Asia/Kolkata',
        'IST': 'Asia/Kolkata',
        'Eastern Standard Time': 'America/New_York',
        'Eastern Daylight Time': 'America/New_York',
        'EDT': 'America/New_York',
        'EST': 'America/New_York',
        'Central Standard Time': 'America/Chicago',
        'Central Daylight Time': 'America/Chicago',
        'CDT': 'America/Chicago',
        'CST': 'America/Chicago',
        'Pacific Standard Time': 'America/Los_Angeles',
        'Pacific Daylight Time': 'America/Los_Angeles',
        'PDT': 'America/Los_Angeles',
        'PST': 'America/Los_Angeles',
        'Mountain Standard Time': 'America/Denver',
        'Mountain Daylight Time': 'America/Denver',
        'MDT': 'America/Denver',
        'MST': 'America/Denver',
        'GMT Standard Time': 'Europe/London',
        'Greenwich Standard Time': 'UTC',
        'W. Europe Standard Time': 'Europe/Berlin',
        'Central European Standard Time': 'Europe/Warsaw',
        'Tokyo Standard Time': 'Asia/Tokyo',
        'Singapore Standard Time': 'Asia/Singapore',
        'China Standard Time': 'Asia/Shanghai',
        'AUS Eastern Standard Time': 'Australia/Sydney',
        'UTC': 'UTC',
      };
      if (commonNameMap.containsKey(tzName)) {
        try {
          final location = tz.getLocation(commonNameMap[tzName]!);
          tz.setLocalLocation(location);
          return location;
        } catch (_) {}
      }

      // 3. Fallback: match by current system offset in milliseconds against known locations
      final offsetMillis = DateTime.now().timeZoneOffset.inMilliseconds;
      final nowEpoch = DateTime.now().millisecondsSinceEpoch;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        final tzInfo = loc.timeZone(nowEpoch);
        if (tzInfo.offset == offsetMillis) {
          tz.setLocalLocation(loc);
          return loc;
        }
      }

      // 4. Fallback to UTC if no matching offset is found
      final utc = tz.UTC;
      tz.setLocalLocation(utc);
      return utc;
    } catch (e) {
      return tz.UTC;
    }
  }

  Future<void> _configureLocalTimezone() async {
    final location = _ensureLocalTimezone();
    debugPrint('NotificationService: Local timezone verified as ${location.name}.');
  }

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      debugPrint('NotificationService: Local notifications are not supported on Web; marked initialized.');
      return;
    }

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
      if (!kIsWeb && Platform.isAndroid) {
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
    } catch (e) {
      debugPrint('NotificationService: Engine initialization notice (app will continue): $e');
      _initialized = true;
    }
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return true;
    try {
      if (!kIsWeb && Platform.isAndroid) {
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
      } else if (!kIsWeb && Platform.isIOS) {
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

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final androidImplementation =
            _localNotificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        return await androidImplementation?.areNotificationsEnabled() ?? true;
      }
    } catch (e) {
      debugPrint('NotificationService areNotificationsEnabled error: $e');
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
      } else if (type == 'money') {
        debugPrint('NotificationService: Direct navigation to Money Manager');
        appRouter.go('/money');
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

  // Fixed system reminder notification IDs
  static const int moneyReminderId = 888888;
  static const int eveningHabitReminderId = 999999;
  static const int moneyReminderEarlyId = 888888;
  static const int moneyReminderLateId = 101010;

  // Disjoint namespaces to guarantee collision freedom:
  // Task pre-deadline: [10,000,000, 399,999,999]
  // Task deadline:     [400,000,000, 799,999,999]
  // Habit deadline:    [800,000,000, 1,099,999,999]
  // Habit rem_time:    [1,100,000,000, 1,399,999,999]
  // Money reminder:    Fixed user-safe deterministic ID (888888)
  static const int taskPreDeadlineMin = 10000000;
  static const int taskPreDeadlineRange = 390000000;

  static const int taskDeadlineMin = 400000000;
  static const int taskDeadlineRange = 400000000;

  static const int habitDeadlineMin = 800000000;
  static const int habitDeadlineRange = 300000000;

  static const int habitRemTimeMin = 1100000000;
  static const int habitRemTimeRange = 300000000;

  // Generate a stable positive 31-bit integer hash from task/habit string key
  // Does NOT use Dart runtime hashCode
  int getStableHash(String input) {
    int hash = 5381;
    for (int i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
      hash &= 0x7FFFFFFF; // Restrict to positive 31-bit signed integer
    }
    return hash;
  }

  int getTaskNotificationId5m(String taskId) {
    return taskPreDeadlineMin + (getStableHash('task_pre_$taskId') % taskPreDeadlineRange);
  }

  int getTaskNotificationIdDeadline(String taskId) {
    return taskDeadlineMin + (getStableHash('task_dead_$taskId') % taskDeadlineRange);
  }

  int getHabitNotificationIdDeadline(String habitId) {
    return habitDeadlineMin + (getStableHash('habit_dead_$habitId') % habitDeadlineRange);
  }

  int getHabitNotificationIdRemTime(String habitId) {
    return habitRemTimeMin + (getStableHash('habit_rem_$habitId') % habitRemTimeRange);
  }

  int getHabitNotificationId(String habitId) => getHabitNotificationIdDeadline(habitId);

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
    if (kIsWeb) return;

    bool canScheduleExact = true;
    if (!kIsWeb && Platform.isAndroid) {
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
    if (kIsWeb) return;
    if (task.completed || task.dueDate == null || task.dueTime == null) {
      await cancelTaskReminders(task.id);
      return;
    }

    final date = task.dueDate!;
    final parts = task.dueTime!.split(':');
    if (parts.length != 2) return;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;
    final dueDateTime = DateTime(date.year, date.month, date.day, hour, minute);

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

    final payload = jsonEncode({'type': 'task', 'id': task.id});

    // Cancel existing scheduled notifications to prevent duplicates
    await cancelTaskReminders(task.id);

    final currentZone = _ensureLocalTimezone();

    // 1. Notification 1: 5 Minutes Before Deadline
    final time5m = dueDateTime.subtract(const Duration(minutes: 5));
    final id5m = getTaskNotificationId5m(task.id);
    if (time5m.isAfter(now)) {
      final String body5m = "${task.title} is due in 5 minutes.";
      await _safeZonedSchedule(
        id5m,
        'Task due soon',
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
    final idDeadline = getTaskNotificationIdDeadline(task.id);
    if (dueDateTime.isAfter(now)) {
      final String bodyDeadline = "${task.title} is due now.";
      await _safeZonedSchedule(
        idDeadline,
        'Task deadline reached',
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
      await _localNotificationsPlugin.cancel(getTaskNotificationId5m(taskId));
      await _localNotificationsPlugin.cancel(getTaskNotificationIdDeadline(taskId));
      // Also cancel legacy IDs to prevent orphaned notifications
      final baseId = getStableHash(taskId) % 300000000;
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

  Future<void> scheduleHabitReminders({
    required Habit habit,
    required bool completedToday,
    required String remTime,
  }) async {
    if (kIsWeb) return;

    final now = DateTime.now();
    final currentZone = _ensureLocalTimezone();

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
    final payload = jsonEncode({'type': 'habit', 'id': habit.id});

    final deadlineId = getHabitNotificationIdDeadline(habit.id);
    final remTimeId = getHabitNotificationIdRemTime(habit.id);

    // Cancel existing scheduled notifications for this habit first
    await cancelHabitReminders(habit.id);

    // 1. Notification 1 — Habit Deadline
    if (!completedToday && habit.reminderTime != null && habit.reminderTime!.trim().isNotEmpty) {
      final parts = habit.reminderTime!.trim().split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          final deadlineToday = DateTime(now.year, now.month, now.day, hour, minute);
          if (deadlineToday.isAfter(now)) {
            await _safeZonedSchedule(
              deadlineId,
              'Habit reminder',
              'Time to complete: ${habit.name}',
              tz.TZDateTime.from(deadlineToday, currentZone),
              details,
              payload: payload,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
            debugPrint(
              'NotificationService: Scheduled Habit Deadline reminder (ID: $deadlineId, Habit: "${habit.name}") at $deadlineToday',
            );
          }
        }
      }
    }

    // 2. Notification 2 — Global rem_time
    if (!completedToday && remTime.trim().isNotEmpty) {
      final parts = remTime.trim().split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        if (hour != null && minute != null) {
          final remTimeToday = DateTime(now.year, now.month, now.day, hour, minute);
          if (remTimeToday.isAfter(now)) {
            await _safeZonedSchedule(
              remTimeId,
              'Habit still pending',
              "You haven't completed ${habit.name} today.",
              tz.TZDateTime.from(remTimeToday, currentZone),
              details,
              payload: payload,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
            debugPrint(
              'NotificationService: Scheduled Habit rem_time reminder (ID: $remTimeId, Habit: "${habit.name}") at $remTimeToday',
            );
          }
        }
      }
    }
  }

  Future<void> cancelHabitReminders(String habitId) async {
    try {
      final deadlineId = getHabitNotificationIdDeadline(habitId);
      final remTimeId = getHabitNotificationIdRemTime(habitId);
      await _localNotificationsPlugin.cancel(deadlineId);
      await _localNotificationsPlugin.cancel(remTimeId);

      // Legacy IDs cleanup
      await _localNotificationsPlugin.cancel(getStableHash('habit_$habitId') % 400000000 + 1000000000);
      await _localNotificationsPlugin.cancel(getStableHash(habitId));
      debugPrint('NotificationService: Canceled all reminders for Habit ID: $habitId (Deadline ID: $deadlineId, rem_time ID: $remTimeId)');
    } catch (e) {
      debugPrint('NotificationService cancelHabitReminders notice: $e');
    }
  }

  // Compatibility alias for habit reminder scheduling
  Future<void> scheduleHabitReminder(Habit habit, {bool completedToday = false, String remTime = '21:00'}) async {
    await scheduleHabitReminders(habit: habit, completedToday: completedToday, remTime: remTime);
  }

  // Compatibility alias
  Future<void> cancelHabitReminder(String habitId) async => cancelHabitReminders(habitId);

  Future<void> scheduleEveningReminder(int incompleteCount) async {
    if (kIsWeb) return;
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
      eveningHabitReminderId,
      'Habit reminder',
      "Don't forget today's habits. You have $incompleteCount incomplete habits left for today.",
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
      await _localNotificationsPlugin.cancel(eveningHabitReminderId);
      debugPrint('NotificationService: Canceled evening habit reminder.');
    } catch (e) {
      debugPrint('NotificationService cancelEveningReminder notice: $e');
    }
  }

  /// Schedules daily Money Manager reminder at `rem_time`.
  /// Only one Money Manager reminder exists per day.
  Future<void> scheduleDailyMoneyReminder(String remTime) async {
    if (kIsWeb) return;
    try {
      final now = DateTime.now();
      final currentZone = _ensureLocalTimezone();

      final parts = remTime.trim().split(':');
      if (parts.length != 2) return;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return;

      var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
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

      // Cancel any old money reminders to ensure exactly one exists
      await cancelMoneyReminders();

      final payload = jsonEncode({'type': 'money', 'id': 'daily_money'});

      await _safeZonedSchedule(
        moneyReminderId,
        "Update today's spending",
        "Don't forget to add today's expenses to ARC.",
        tz.TZDateTime.from(scheduledTime, currentZone),
        details,
        payload: payload,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('NotificationService: Scheduled daily money reminder (ID: $moneyReminderId) at $scheduledTime');
    } catch (e) {
      debugPrint('NotificationService: scheduleDailyMoneyReminder exception: $e');
    }
  }

  // Compatibility method
  Future<void> scheduleDailyMoneyReminders({bool hasTodayTx = false, String remTime = '21:00'}) async {
    await scheduleDailyMoneyReminder(remTime);
  }

  Future<void> cancelMoneyReminders() async {
    try {
      await _localNotificationsPlugin.cancel(moneyReminderId);
      await _localNotificationsPlugin.cancel(moneyReminderEarlyId);
      await _localNotificationsPlugin.cancel(moneyReminderLateId);
      debugPrint('NotificationService: Canceled money reminders.');
    } catch (e) {
      debugPrint('NotificationService cancelMoneyReminders notice: $e');
    }
  }

  Future<void> cancelAllUserNotifications() async {
    try {
      await _localNotificationsPlugin.cancelAll();
      debugPrint('NotificationService: All user-scoped notifications successfully cancelled.');
    } catch (e) {
      debugPrint('NotificationService cancelAllUserNotifications notice: $e');
    }
  }

  Future<void> reconcileScheduledNotifications({
    List<Task>? tasks,
    List<Habit>? habits,
    List<HabitEntry>? habitEntries,
    bool? hasTodayTx,
    String remTime = '21:00',
  }) async {
    if (kIsWeb) return;
    try {
      debugPrint('NotificationService: Reconciling scheduled notifications...');

      // 1. Reconcile Tasks
      if (tasks != null) {
        final now = DateTime.now();
        for (final task in tasks) {
          if (task.completed || task.dueDate == null || task.dueTime == null) {
            await cancelTaskReminders(task.id);
          } else {
            final parts = task.dueTime!.split(':');
            if (parts.length == 2) {
              final hour = int.tryParse(parts[0]);
              final minute = int.tryParse(parts[1]);
              if (hour != null && minute != null) {
                final dueDateTime = DateTime(
                  task.dueDate!.year,
                  task.dueDate!.month,
                  task.dueDate!.day,
                  hour,
                  minute,
                );
                if (dueDateTime.isBefore(now)) {
                  await cancelTaskReminders(task.id);
                } else {
                  await scheduleTaskReminders(task);
                }
              }
            }
          }
        }
      }

      // 2. Reconcile Habits
      if (habits != null) {
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        for (final habit in habits) {
          final completedToday = habitEntries?.any(
                (e) => e.habitId == habit.id && e.dateStr == todayStr && e.completed,
              ) ??
              false;
          await scheduleHabitReminders(
            habit: habit,
            completedToday: completedToday,
            remTime: remTime,
          );
        }
      }

      // 3. Reconcile Money Reminders
      await scheduleDailyMoneyReminder(remTime);

      debugPrint('NotificationService: Reconciliation completed successfully.');
    } catch (e) {
      debugPrint('NotificationService reconciliation warning: $e');
    }
  }

  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return;
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
