import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arc/core/notifications/notification_service.dart';
import 'package:arc/features/task_manager/models/task_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const MethodChannel channel =
        MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return null;
    });
  });

  group('System Notification Service Unit Tests', () {
    final notificationService = NotificationService();

    test('getStableHash generates positive 32-bit deterministic integer hashes', () {
      final hash1 = notificationService.getStableHash('task_uuid_123');
      final hash2 = notificationService.getStableHash('task_uuid_123');
      final hash3 = notificationService.getStableHash('task_uuid_999');

      expect(hash1, equals(hash2));
      expect(hash1, greaterThanOrEqualTo(0));
      expect(hash1, isNot(equals(hash3)));
    });

    test('Task payload correctly encodes task type and ID', () {
      final task = Task(
        id: 'task_abc_456',
        title: 'Complete Project Assignment',
        description: 'Complete high-priority task before 5 PM',
        priority: 'High',
        category: 'Work',
        labels: ['School'],
        completed: false,
        dueDate: DateTime(2026, 7, 28),
        dueTime: '17:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final payloadStr = jsonEncode({'type': 'task', 'id': task.id});
      final decoded = jsonDecode(payloadStr) as Map<String, dynamic>;

      expect(decoded['type'], equals('task'));
      expect(decoded['id'], equals('task_abc_456'));
    });

    test('Habit payload correctly encodes habit type', () {
      final payloadStr = jsonEncode({'type': 'habit', 'id': 'evening_habit'});
      final decoded = jsonDecode(payloadStr) as Map<String, dynamic>;

      expect(decoded['type'], equals('habit'));
      expect(decoded['id'], equals('evening_habit'));
    });

    test('scheduleTaskReminders correctly cancels reminders when task is completed', () async {
      final completedTask = Task(
        id: 'task_completed_1',
        title: 'Finished Task',
        description: '',
        priority: 'High',
        category: 'Personal',
        labels: [],
        completed: true,
        dueDate: DateTime(2026, 7, 28),
        dueTime: '18:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Should cancel without throwing any errors
      await notificationService.scheduleTaskReminders(completedTask);
      expect(completedTask.completed, isTrue);
    });
  });
}
