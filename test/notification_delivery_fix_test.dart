import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:arc/core/notifications/notification_service.dart';
import 'package:arc/features/task_manager/models/task_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tz.initializeTimeZones();
  });

  group('Notification System Reliability Tests', () {
    test('Test A — Timezone: Asia/Kolkata is explicitly resolved and configured', () async {
      final notificationService = NotificationService();
      await notificationService.init();

      expect(tz.local.name, equals('Asia/Kolkata'));
      expect(tz.local.name, isNot(equals('IST')));
      expect(tz.local.name, isNot(equals('UTC')));
    });

    test('Test B — Initialization resilience: NotificationService.init() marks isInitialized as true without throwing', () async {
      final notificationService = NotificationService();
      await notificationService.init();

      expect(notificationService.isInitialized, isTrue);
    });

    test('Test C — Exact Alarm Fallback & Task Reminders: Scheduling task reminders executes safely', () async {
      final notificationService = NotificationService();
      await notificationService.init();

      final now = DateTime.now();
      final task = Task(
        id: 'notification_test_task_1',
        title: 'Test Notification Task',
        description: 'Testing exact alarm fallback and scheduling',
        labels: const [],
        dueDate: now.add(const Duration(days: 1)),
        dueTime: '18:00',
        priority: 'High',
        category: 'Work',
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      // Should complete cleanly without throwing PlatformException
      await notificationService.scheduleTaskReminders(task);
      await notificationService.cancelTaskReminders(task.id);
    });

    test('Test D — Existing Notification Behavior: Money and Habit reminders schedule cleanly', () async {
      final notificationService = NotificationService();
      await notificationService.init();

      // Schedule Evening Habit Reminder
      await notificationService.scheduleEveningReminder(3);
      await notificationService.cancelEveningReminder();

      // Schedule Daily Money Reminders
      await notificationService.scheduleDailyMoneyReminders(hasTodayTx: false);
      await notificationService.scheduleDailyMoneyReminders(hasTodayTx: true);
    });

    test('Test E — Startup Resilience: Main initialization flow is non-blocking', () async {
      // Simulating main.dart notification initialization sequence
      try {
        final notificationService = NotificationService();
        await notificationService.init();
        await notificationService.requestPermissions();
        await notificationService.checkAppLaunchNotification();
      } catch (e) {
        fail('NotificationService startup flow threw an uncaught error: $e');
      }

      // Verify that Flutter binding and timezone state remain valid
      expect(tz.local.name, equals('Asia/Kolkata'));
    });
  });
}
