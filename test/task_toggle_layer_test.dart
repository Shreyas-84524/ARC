import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/task_manager/screens/tasks_screen.dart';
import 'package:arc/providers/global_providers.dart';

class InMemoryTaskRepository implements TaskRepository {
  final List<Task> _tasks = [];

  @override
  String? get userId => 'test_user';

  @override
  List<Task> getTasks() => List.unmodifiable(_tasks);

  @override
  Future<void> saveTask(Task task) async {
    final idx = _tasks.indexWhere((t) => t.id == task.id);
    if (idx != -1) {
      _tasks[idx] = task;
    } else {
      _tasks.add(task);
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    _tasks.removeWhere((t) => t.id == id);
  }

  @override
  Future<bool> syncPending() async => true;

  @override
  Future<int> performEndOfDayCleanup({String? overrideDateStr}) async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.now();

  setUpAll(() {
    tz.initializeTimeZones();
    const MethodChannel channel =
        MethodChannel('dexterous.com/flutter/local_notifications');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'requestNotificationsPermission') return true;
      if (call.method == 'requestExactAlarmsPermission') return true;
      if (call.method == 'canScheduleExactNotifications') return true;
      if (call.method == 'areNotificationsEnabled') return true;
      return null;
    });
  });

  Widget buildTestWidget({required List<Task> initialTasks}) {
    final repo = InMemoryTaskRepository();
    for (final t in initialTasks) {
      repo.saveTask(t);
    }

    return ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const TasksScreen(),
      ),
    );
  }

  group('Task Toggle SnackBar Layer Tests', () {
    testWidgets('Tapping task checkbox displays 5-second SnackBar with black text, black icon, and black Undo action', (WidgetTester tester) async {
      final task = Task(
        id: 'task_toggle_1',
        title: 'Review System Metrics',
        description: '',
        labels: const [],
        dueDate: now.add(const Duration(days: 1)),
        dueTime: '15:00',
        priority: 'High',
        category: 'Work',
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(buildTestWidget(initialTasks: [task]));
      await tester.pumpAndSettle();

      // Tap on the task completion checkbox using its specific Key
      final checkboxFinder = find.byKey(Key('task_checkbox_${task.id}'));
      expect(checkboxFinder, findsOneWidget);

      await tester.tap(checkboxFinder);
      await tester.pump(); // Start snackbar animation
      await tester.pump(const Duration(milliseconds: 500)); // Fully visible

      // 1. Verify SnackBar widget is present
      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);

      final SnackBar snackBar = tester.widget(snackBarFinder);

      // 2. Verify duration is 5 seconds
      expect(snackBar.duration, const Duration(seconds: 5));

      // 3. Verify dismiss direction is down
      expect(snackBar.dismissDirection, DismissDirection.down);

      // 4. Verify text color is black
      final textFinder = find.text('Task Completed');
      expect(textFinder, findsOneWidget);
      final Text textWidget = tester.widget(textFinder);
      expect(textWidget.style?.color, Colors.black);

      // 5. Verify icon color is black
      final iconFinder = find.byIcon(LucideIcons.checkCircle2);
      expect(iconFinder, findsOneWidget);
      final Icon iconWidget = tester.widget(iconFinder);
      expect(iconWidget.color, Colors.black);

      // 6. Verify Undo action text color is black
      final SnackBarAction action = snackBar.action!;
      expect(action.label, 'Undo');
      expect(action.textColor, Colors.black);

      // 7. Verify auto-dismiss after 5 seconds:
      // After 4 seconds, still visible
      await tester.pump(const Duration(seconds: 4));
      expect(find.byType(SnackBar), findsOneWidget);

      // Advance clock past the remaining 1 second (total > 5s)
      await tester.pump(const Duration(seconds: 2));
      // Pump to process timer callback and begin reverse animation
      await tester.pump();
      // Pump past reverse animation transition duration (250ms)
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Tapping completed task marks incomplete and shows black rotateCcw icon and text', (WidgetTester tester) async {
      final task = Task(
        id: 'task_toggle_2',
        title: 'Submit Expense Report',
        description: '',
        labels: const [],
        dueDate: now.add(const Duration(days: 1)),
        dueTime: '17:00',
        priority: 'Must',
        category: 'Finance',
        completed: true,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(buildTestWidget(initialTasks: [task]));
      await tester.pumpAndSettle();

      // Select 'Completed' tab so the completed task is rendered
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      // Tap on the task completion checkbox to mark incomplete
      final checkboxFinder = find.byKey(Key('task_checkbox_${task.id}'));
      expect(checkboxFinder, findsOneWidget);

      await tester.tap(checkboxFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Verify SnackBar widget is present
      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);

      final SnackBar snackBar = tester.widget(snackBarFinder);
      expect(snackBar.duration, const Duration(seconds: 5));
      expect(snackBar.dismissDirection, DismissDirection.down);

      // 2. Verify text is 'Task Marked Incomplete' and color is black
      final textFinder = find.text('Task Marked Incomplete');
      expect(textFinder, findsOneWidget);
      final Text textWidget = tester.widget(textFinder);
      expect(textWidget.style?.color, Colors.black);

      // 3. Verify icon is rotateCcw and color is black
      final iconFinder = find.byIcon(LucideIcons.rotateCcw);
      expect(iconFinder, findsOneWidget);
      final Icon iconWidget = tester.widget(iconFinder);
      expect(iconWidget.color, Colors.black);

      // 4. Verify Undo action color is black
      expect(snackBar.action?.textColor, Colors.black);
    });

    testWidgets('Sliding the layer down dismisses it immediately', (WidgetTester tester) async {
      final task = Task(
        id: 'task_toggle_3',
        title: 'Review PR',
        description: '',
        labels: const [],
        dueDate: now.add(const Duration(days: 1)),
        dueTime: '11:00',
        priority: 'Low',
        category: 'Work',
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(buildTestWidget(initialTasks: [task]));
      await tester.pumpAndSettle();

      // Tap checkbox to show SnackBar
      final checkboxFinder = find.byKey(Key('task_checkbox_${task.id}'));
      expect(checkboxFinder, findsOneWidget);

      await tester.tap(checkboxFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SnackBar), findsOneWidget);

      // Drag down on the SnackBar to slide it down
      await tester.drag(find.byType(SnackBar), const Offset(0, 300));
      await tester.pumpAndSettle();

      // SnackBar dismissed immediately by sliding down
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('Tapping Undo in SnackBar reverts task status immediately', (WidgetTester tester) async {
      final task = Task(
        id: 'task_toggle_4',
        title: 'Draft Quarterly Goals',
        description: '',
        labels: const [],
        dueDate: now.add(const Duration(days: 1)),
        dueTime: '14:00',
        priority: 'High',
        category: 'Work',
        completed: false,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(buildTestWidget(initialTasks: [task]));
      await tester.pumpAndSettle();

      // Tap checkbox to complete task
      final checkboxFinder = find.byKey(Key('task_checkbox_${task.id}'));
      await tester.tap(checkboxFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // SnackBar is shown with black Undo button
      expect(find.text('Task Completed'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify task is reverted back to pending and visible in pending list
      expect(find.text('Draft Quarterly Goals'), findsOneWidget);
    });
  });
}
