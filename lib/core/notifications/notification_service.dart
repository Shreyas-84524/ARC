import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:arc/core/notifications/notification_models.dart';

abstract class LocalNotificationGateway {
  bool get isInitialized;
  String get timezoneName;
  Stream<ArcNotificationPayload> get notificationTaps;

  Future<void> initialize();
  Future<ArcNotificationPermissionState> permissionState();
  Future<ArcNotificationPermissionState> requestPermission();
  Future<List<ArcPendingNotification>> pendingNotifications();
  Future<void> schedule(ArcNotificationSpec spec);
  Future<void> show(ArcNotificationSpec spec);
  Future<void> cancel(int id);
  Future<void> cancelAll();
  Future<void> dispose();
}

/// The only class allowed to communicate with flutter_local_notifications.
/// Business rules live in NotificationPolicy and orchestration lives in the
/// notification controller.
class FlutterLocalNotificationGateway implements LocalNotificationGateway {
  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<ArcNotificationPayload> _tapController =
      StreamController<ArcNotificationPayload>.broadcast(sync: true);

  bool _initialized = false;
  String _timezoneName = 'Unknown';

  FlutterLocalNotificationGateway({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  bool get isInitialized => _initialized;

  @override
  String get timezoneName => _timezoneName;

  @override
  Stream<ArcNotificationPayload> get notificationTaps =>
      _tapController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _timezoneName = 'Unsupported on web';
      _initialized = true;
      return;
    }

    final location = _configureLocalTimezone();
    _timezoneName = location.name;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    final initialized = await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleResponse,
    );
    if (initialized == false) {
      throw StateError('Local notification plugin initialization returned false.');
    }

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'arc_tasks_channel',
        'Task Reminders',
        description: 'Task deadlines and upcoming task alerts',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'arc_habits_channel',
        'Habit Reminders',
        description: 'Habit times and daily habit check-ins',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'arc_money_channel',
        'Money Reminders',
        description: 'Daily prompts to record expenses',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'arc_feedback_channel',
        'Feedback Updates',
        description: 'Updates and thank-you notes for submitted feedback',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ));
    }

    _initialized = true;

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchResponse != null) {
      _handleResponse(launchResponse);
    }
  }

  @override
  Future<ArcNotificationPermissionState> permissionState() async {
    if (kIsWeb) return ArcNotificationPermissionState.unsupported;
    try {
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        final enabled = await android?.areNotificationsEnabled();
        return enabled == false
            ? ArcNotificationPermissionState.denied
            : ArcNotificationPermissionState.granted;
      }
      if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        final settings = await ios?.checkPermissions();
        if (settings == null) return ArcNotificationPermissionState.unknown;
        return settings.isEnabled
            ? ArcNotificationPermissionState.granted
            : ArcNotificationPermissionState.denied;
      }
      return ArcNotificationPermissionState.unsupported;
    } catch (_) {
      return ArcNotificationPermissionState.error;
    }
  }

  @override
  Future<ArcNotificationPermissionState> requestPermission() async {
    if (kIsWeb) return ArcNotificationPermissionState.unsupported;
    try {
      bool? granted;
      if (Platform.isAndroid) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        granted = await android?.requestNotificationsPermission();
      } else if (Platform.isIOS) {
        final ios = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      if (granted == null) return await permissionState();
      return granted
          ? ArcNotificationPermissionState.granted
          : ArcNotificationPermissionState.denied;
    } catch (_) {
      return ArcNotificationPermissionState.error;
    }
  }

  @override
  Future<List<ArcPendingNotification>> pendingNotifications() async {
    if (kIsWeb) return const [];
    final pending = await _plugin.pendingNotificationRequests();
    return pending
        .map((request) => ArcPendingNotification(
              id: request.id,
              payload: request.payload,
            ))
        .toList(growable: false);
  }

  @override
  Future<void> schedule(ArcNotificationSpec spec) async {
    if (kIsWeb) return;
    if (!_initialized) {
      throw StateError('Notification gateway must be initialized before scheduling.');
    }

    final channel = _channelDetails(spec.channel);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.$1,
        channel.$2,
        channelDescription: channel.$3,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.zonedSchedule(
      spec.id,
      spec.title,
      spec.body,
      tz.TZDateTime.from(spec.scheduledAt, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: spec.payload,
      matchDateTimeComponents:
          spec.recurrence == ArcNotificationRecurrence.daily
              ? DateTimeComponents.time
              : null,
    );
  }

  @override
  Future<void> show(ArcNotificationSpec spec) async {
    if (kIsWeb) return;
    if (!_initialized) {
      await initialize();
    }

    final channel = _channelDetails(spec.channel);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.$1,
        channel.$2,
        channelDescription: channel.$3,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      spec.id,
      spec.title,
      spec.body,
      details,
      payload: spec.payload,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> dispose() async {
    await _tapController.close();
  }

  void _handleResponse(NotificationResponse response) {
    final payload = ArcNotificationPayload.tryParse(response.payload);
    if (payload != null && !_tapController.isClosed) {
      _tapController.add(payload);
    }
  }

  (String, String, String) _channelDetails(
    ArcNotificationChannel channel,
  ) {
    return switch (channel) {
      ArcNotificationChannel.tasks => (
          'arc_tasks_channel',
          'Task Reminders',
          'Task deadlines and upcoming task alerts',
        ),
      ArcNotificationChannel.habits => (
          'arc_habits_channel',
          'Habit Reminders',
          'Habit times and daily habit check-ins',
        ),
      ArcNotificationChannel.money => (
          'arc_money_channel',
          'Money Reminders',
          'Daily prompts to record expenses',
        ),
      ArcNotificationChannel.feedback => (
          'arc_feedback_channel',
          'Feedback Updates',
          'Updates and thank-you notes for submitted feedback',
        ),
    };
  }

  tz.Location _configureLocalTimezone() {
    tz.initializeTimeZones();
    final systemName = DateTime.now().timeZoneName;

    if (systemName.isNotEmpty) {
      try {
        final location = tz.getLocation(systemName);
        tz.setLocalLocation(location);
        return location;
      } catch (_) {}
    }

    const aliases = <String, String>{
      'India Standard Time': 'Asia/Kolkata',
      'IST': 'Asia/Kolkata',
      'Eastern Standard Time': 'America/New_York',
      'Eastern Daylight Time': 'America/New_York',
      'EST': 'America/New_York',
      'EDT': 'America/New_York',
      'Central Standard Time': 'America/Chicago',
      'Central Daylight Time': 'America/Chicago',
      'CST': 'America/Chicago',
      'CDT': 'America/Chicago',
      'Mountain Standard Time': 'America/Denver',
      'Mountain Daylight Time': 'America/Denver',
      'MST': 'America/Denver',
      'MDT': 'America/Denver',
      'Pacific Standard Time': 'America/Los_Angeles',
      'Pacific Daylight Time': 'America/Los_Angeles',
      'PST': 'America/Los_Angeles',
      'PDT': 'America/Los_Angeles',
      'GMT Standard Time': 'Europe/London',
      'W. Europe Standard Time': 'Europe/Berlin',
      'Tokyo Standard Time': 'Asia/Tokyo',
      'Singapore Standard Time': 'Asia/Singapore',
      'China Standard Time': 'Asia/Shanghai',
      'AUS Eastern Standard Time': 'Australia/Sydney',
      'UTC': 'UTC',
    };
    final alias = aliases[systemName];
    if (alias != null) {
      final location = tz.getLocation(alias);
      tz.setLocalLocation(location);
      return location;
    }

    final offsetMillis = DateTime.now().timeZoneOffset.inMilliseconds;
    final epoch = DateTime.now().millisecondsSinceEpoch;
    for (final location in tz.timeZoneDatabase.locations.values) {
      if (location.timeZone(epoch).offset == offsetMillis) {
        tz.setLocalLocation(location);
        return location;
      }
    }

    tz.setLocalLocation(tz.UTC);
    return tz.UTC;
  }
}
