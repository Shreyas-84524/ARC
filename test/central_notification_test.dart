import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:arc/core/notifications/notification_controller.dart';
import 'package:arc/core/notifications/notification_models.dart';
import 'package:arc/core/notifications/notification_policy.dart';
import 'package:arc/core/notifications/notification_service.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/settings/models/settings_model.dart';
import 'package:arc/features/task_manager/models/task_model.dart';

class _FakeGateway implements LocalNotificationGateway {
  final Map<int, ArcPendingNotification> pending = {};
  final StreamController<ArcNotificationPayload> taps =
      StreamController<ArcNotificationPayload>.broadcast();
  ArcNotificationPermissionState permission =
      ArcNotificationPermissionState.granted;
  bool initialized = false;
  int scheduleCount = 0;
  int cancelCount = 0;

  @override
  bool get isInitialized => initialized;

  @override
  String get timezoneName => 'Asia/Kolkata';

  @override
  Stream<ArcNotificationPayload> get notificationTaps => taps.stream;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<ArcNotificationPermissionState> permissionState() async => permission;

  @override
  Future<ArcNotificationPermissionState> requestPermission() async => permission;

  @override
  Future<List<ArcPendingNotification>> pendingNotifications() async =>
      pending.values.toList(growable: false);

  @override
  Future<void> schedule(ArcNotificationSpec spec) async {
    scheduleCount++;
    pending[spec.id] = ArcPendingNotification(id: spec.id, payload: spec.payload);
  }

  @override
  Future<void> show(ArcNotificationSpec spec) async {
    scheduleCount++;
    pending[spec.id] = ArcPendingNotification(id: spec.id, payload: spec.payload);
  }

  @override
  Future<void> cancel(int id) async {
    cancelCount++;
    pending.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelCount += pending.length;
    pending.clear();
  }

  @override
  Future<void> dispose() => taps.close();
}

NotificationSnapshot _snapshot({
  required SettingsModel settings,
  List<Task> tasks = const [],
  List<Habit> habits = const [],
  DateTime? now,
}) {
  return NotificationSnapshot(
    userId: 'test-user',
    settings: settings,
    tasks: tasks,
    habits: habits,
    habitEntries: const [],
    transactions: const [],
    now: now ?? DateTime(2026, 10, 20, 10, 0),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationPolicy', () {
    final policy = NotificationPolicy();

    test('creates task reminder and deadline specs', () {
      final now = DateTime(2026, 10, 20, 10, 0);
      final task = Task(
        id: 'task-1',
        title: 'Submit report',
        description: '',
        priority: 'High',
        category: 'Work',
        labels: const [],
        dueDate: DateTime(2026, 10, 20),
        dueTime: '12:00',
        reminder: DateTime(2026, 10, 20, 11, 55),
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      final specs = policy.build(_snapshot(
        settings: SettingsModel.defaultSettings(),
        tasks: [task],
        now: now,
      ));

      expect(specs.map((spec) => spec.type), containsAll([
        ArcNotificationType.taskReminder,
        ArcNotificationType.taskDeadline,
      ]));
    });

    test('creates daily habit schedules and advances after completion', () {
      final habit = Habit(
        id: 'habit-1',
        name: 'Read',
        category: 'Personal',
        colorValue: 0xffffffff,
        reminderTime: '18:00',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
      final specs = policy.build(_snapshot(
        settings: SettingsModel.defaultSettings(),
        habits: [habit],
      ));
      final reminder = specs.firstWhere(
        (spec) => spec.type == ArcNotificationType.habitReminder,
      );
      expect(reminder.recurrence, ArcNotificationRecurrence.daily);
      expect(reminder.scheduledAt, DateTime(2026, 10, 20, 18));
    });

    test('disabled master switch produces no desired schedules', () {
      final settings = SettingsModel.defaultSettings().copyWith(
        masterNotificationsEnabled: false,
      );
      expect(policy.build(_snapshot(settings: settings)), isEmpty);
    });
  });

  test('controller reconciles desired schedules and cancels them when disabled', () async {
    final gateway = _FakeGateway();
    final controller = NotificationController(gateway: gateway);
    final settings = SettingsModel.defaultSettings();
    final snapshot = _snapshot(settings: settings);

    await controller.initialize();
    await controller.reconcile(snapshot, reason: 'test');
    expect(gateway.initialized, isTrue);
    expect(controller.state.desiredCount, greaterThan(0));
    expect(gateway.pending, isNotEmpty);

    await controller.reconcile(
      _snapshot(
        settings: settings.copyWith(masterNotificationsEnabled: false),
      ),
      reason: 'disabled',
    );
    expect(gateway.pending, isEmpty);
    expect(gateway.cancelCount, greaterThan(0));
    controller.dispose();
  });
}
