import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/repository/feedback_repository.dart';
import 'package:arc/features/feedback/providers/feedback_providers.dart';
import 'package:arc/features/feedback/screens/my_feedback_screen.dart';
import 'package:arc/features/settings/screens/settings_screen.dart';
import 'package:arc/features/settings/repository/settings_repository.dart';
import 'package:arc/features/settings/models/settings_model.dart';
import 'package:arc/features/task_manager/repository/task_repository.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/repository/habit_repository.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/providers/global_providers.dart';

/// Controllable UserContext notifier for test suites
class TestUserContextNotifier extends UserContextNotifier {
  TestUserContextNotifier([UserContext? initial]) {
    if (initial != null) {
      state = initial;
    }
  }

  void setUser(String userId, String username) {
    state = UserContext(
      userId: userId,
      profile: UserProfile(
        id: userId,
        username: username,
        displayName: username,
        email: '$username@test.com',
        createdAt: DateTime.now(),
      ),
      isInitializing: false,
    );
  }

  void setInitializing() {
    state = UserContext.initializing;
  }

  void setUnauthenticated() {
    state = UserContext.legacy;
  }
}

/// Controllable feedback repository for testing streams, isolation, and status changes
class TestFeedbackRepository implements IFeedbackRepository {
  final List<FeedbackModel> allFeedback = [];
  String? activeUserId;
  final StreamController<List<FeedbackModel>> _streamController =
      StreamController<List<FeedbackModel>>.broadcast();

  TestFeedbackRepository({this.activeUserId});

  @override
  String? get currentUserId => activeUserId;

  void emitAll() {
    if (activeUserId == null) {
      _streamController.add(const []);
    } else {
      _streamController.add(
        allFeedback.where((f) => f.userId == activeUserId).toList(),
      );
    }
  }

  void emitError(Object error) {
    _streamController.addError(error);
  }

  @override
  Future<FeedbackModel> submitFeedback({
    required String category,
    required String module,
    required String message,
    int? rating,
    String? contactEmail,
    String? appVersion,
    String? feedbackId,
  }) async {
    final uid = activeUserId ?? 'test_user';
    final model = FeedbackModel(
      feedbackId: feedbackId ?? 'fb_${allFeedback.length + 1}',
      userId: uid,
      category: category,
      module: module,
      message: message,
      rating: rating,
      contactEmail: contactEmail,
      appVersion: appVersion ?? '1.3.5',
      createdAt: DateTime.now(),
      status: FeedbackStatus.submitted,
    );
    allFeedback.add(model);
    emitAll();
    return model;
  }

  @override
  Future<List<FeedbackModel>> getCurrentUserFeedback({String? userId}) async {
    final uid = userId ?? activeUserId;
    if (uid == null) return const [];
    return allFeedback.where((f) => f.userId == uid).toList();
  }

  @override
  Stream<List<FeedbackModel>> watchCurrentUserFeedback({String? userId}) {
    final uid = userId ?? activeUserId;
    if (uid == null) return Stream.value(const []);

    // Create a stream that emits current state immediately then listens
    final controller = StreamController<List<FeedbackModel>>();
    controller.add(allFeedback.where((f) => f.userId == uid).toList());

    final sub = _streamController.stream.listen(
      (list) {
        controller.add(allFeedback.where((f) => f.userId == uid).toList());
      },
      onError: (err) => controller.addError(err),
    );

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  @override
  Future<FeedbackModel?> getFeedbackStatus(String feedbackId) async {
    try {
      return allFeedback.firstWhere((f) => f.feedbackId == feedbackId);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<FeedbackModel?> watchFeedbackStatus(String feedbackId) {
    return _streamController.stream.map((list) {
      try {
        return allFeedback.firstWhere((f) => f.feedbackId == feedbackId);
      } catch (_) {
        return null;
      }
    });
  }

  @override
  Future<List<FeedbackModel>> getFeedbackForAdmin({
    String? status,
    String? category,
    int limit = 50,
  }) async =>
      allFeedback;

  @override
  Future<void> updateFeedbackAdminStatus({
    required String feedbackId,
    required String status,
    DateTime? reviewedAt,
    DateTime? acknowledgedAt,
  }) async {
    final index = allFeedback.indexWhere((f) => f.feedbackId == feedbackId);
    if (index != -1) {
      allFeedback[index] = allFeedback[index].copyWith(
        status: status,
        reviewedAt: reviewedAt,
        acknowledgedAt: acknowledgedAt,
      );
      emitAll();
    }
  }

  void dispose() {
    _streamController.close();
  }
}

// Minimal mocks for SettingsScreen dependencies
class MockTaskRepo implements TaskRepository {
  @override
  String? get userId => null;
  @override
  List<Task> getTasks() => [];
  @override
  Future<void> saveTask(Task task) async {}
  @override
  Future<void> deleteTask(String id) async {}
  @override
  Future<bool> syncPending() async => true;
  @override
  Future<int> performEndOfDayCleanup({String? overrideDateStr}) async => 0;
}

class MockHabitRepo implements HabitRepository {
  @override
  String? get userId => null;
  @override
  List<Habit> getHabits() => [];
  @override
  List<HabitEntry> getEntries() => [];
  @override
  Future<void> saveHabit(Habit habit) async {}
  @override
  Future<void> deleteHabit(String id) async {}
  @override
  Future<void> toggleEntry(String habitId, String dateStr, bool completed) async {}
  @override
  Future<bool> syncPending() async => true;
}

class MockMoneyRepo implements MoneyRepository {
  @override
  String? get userId => null;
  @override
  List<Transaction> getTransactions() => [];
  @override
  double getMonthlyBudget(String yearMonth) => 0.0;
  @override
  Future<void> saveMonthlyBudget(String yearMonth, double amount) async {}
  @override
  Future<void> saveTransaction(Transaction tx) async {}
  @override
  Future<void> deleteTransaction(String id) async {}
  @override
  Future<void> saveMonthlySummary(summary) async {}
  @override
  Future<bool> syncPending() async => true;
}

class MockSettingsRepo implements SettingsRepository {
  @override
  String? get userId => null;
  @override
  SettingsModel getSettings() => SettingsModel.defaultSettings();
  @override
  Future<void> saveSettings(SettingsModel settings) async {}
  @override
  Future<bool> syncPending() async => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestFeedbackRepository testRepo;
  late TestUserContextNotifier testUserNotifier;
  late MockSettingsRepo mockSettingsRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    testRepo = TestFeedbackRepository(activeUserId: 'user_alice');
    testUserNotifier = TestUserContextNotifier(
      UserContext(
        userId: 'user_alice',
        profile: UserProfile(
          id: 'user_alice',
          username: 'Alice',
          displayName: 'Alice',
          email: 'alice@test.com',
          createdAt: DateTime.now(),
        ),
        isInitializing: false,
      ),
    );
    mockSettingsRepo = MockSettingsRepo();
  });

  tearDown(() {
    testRepo.dispose();
  });

  GoRouter createTestRouter({String initialLocation = '/feedback/my-feedback'}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/feedback',
          builder: (context, state) {
            final category = state.uri.queryParameters['category'];
            if (category == FeedbackCategory.bugReport) return const BugReportScreen();
            if (category == FeedbackCategory.featureRequest) return const FeatureRequestScreen();
            if (category == FeedbackCategory.generalFeedback) return const GeneralFeedbackScreen();
            if (category == FeedbackCategory.appRating) return const RateArcScreen();
            return const GeneralFeedbackScreen();
          },
          routes: [
            GoRoute(path: 'bug', builder: (_, _) => const BugReportScreen()),
            GoRoute(path: 'feature', builder: (_, _) => const FeatureRequestScreen()),
            GoRoute(path: 'general', builder: (_, _) => const GeneralFeedbackScreen()),
            GoRoute(path: 'rate', builder: (_, _) => const RateArcScreen()),
          ],
        ),
        GoRoute(
          path: '/feedback/my-feedback',
          builder: (context, state) => const MyFeedbackScreen(),
        ),
      ],
    );
  }

  Widget createTestApp({
    required GoRouter router,
    Override? userContextOverride,
    Override? repoOverride,
  }) {
    return ProviderScope(
      overrides: [
        userContextProvider.overrideWith((ref) => testUserNotifier),
        feedbackRepositoryProvider.overrideWithValue(testRepo),
        taskRepositoryProvider.overrideWithValue(MockTaskRepo()),
        habitRepositoryProvider.overrideWithValue(MockHabitRepo()),
        moneyRepositoryProvider.overrideWithValue(MockMoneyRepo()),
        settingsRepositoryProvider.overrideWithValue(mockSettingsRepo),
        appSettingsProvider.overrideWith((ref) => SettingsNotifier(mockSettingsRepo)),
        ?userContextOverride,
        ?repoOverride,
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  group('PROJECT ARC — FEEDBACK HISTORY & NAVIGATION VERIFICATION', () {
    // 1. Accessibility from Settings
    testWidgets('Requirement 1: My Feedback is accessible from Settings Help & Feedback section', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = createTestRouter(initialLocation: '/settings');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      final myFeedbackTile = find.byKey(const Key('settings_my_feedback_tile'));
      expect(myFeedbackTile, findsOneWidget);

      expect(find.text('My Feedback'), findsOneWidget);
      expect(find.text('View your submitted feedback'), findsOneWidget);
      expect(find.byIcon(LucideIcons.inbox), findsOneWidget);

      // Tap tile and verify navigation to /feedback/my-feedback
      await tester.tap(myFeedbackTile);
      await tester.pumpAndSettle();

      expect(find.byType(MyFeedbackScreen), findsOneWidget);
    });

    // 2. Correct Route
    testWidgets('Requirement 2: Directly navigating to /feedback/my-feedback renders MyFeedbackScreen', (tester) async {
      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      expect(find.byType(MyFeedbackScreen), findsOneWidget);
      expect(find.text('My Feedback'), findsOneWidget);
    });

    // 3. Submissions appear in history
    testWidgets('Requirement 3: Submitting feedback creates an entry that appears in My Feedback', (tester) async {
      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      // Initially empty
      expect(find.text('No Feedback Yet'), findsOneWidget);

      // Submit feedback
      await testRepo.submitFeedback(
        category: FeedbackCategory.bugReport,
        module: 'habits',
        message: 'Habit checkbox fails to register on first tap',
      );
      await tester.pumpAndSettle();

      // Verify entry appears
      expect(find.text('No Feedback Yet'), findsNothing);
      expect(find.text('Habit checkbox fails to register on first tap'), findsOneWidget);
      expect(find.text('Report a Bug'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
    });

    // 4. Submissions persist across app restart / re-query
    testWidgets('Requirement 4: Submissions persist and reload upon re-querying stream', (tester) async {
      await testRepo.submitFeedback(
        category: FeedbackCategory.featureRequest,
        module: 'tasks',
        message: 'Add recurring tasks on alternating weekends',
      );

      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      expect(find.text('Add recurring tasks on alternating weekends'), findsOneWidget);
      expect(find.text('Suggest a Feature'), findsOneWidget);
    });

    // 5. All 4 categories appear with distinct category badges and metadata
    testWidgets('Requirement 5: All 4 categories (Bug, Feature, General, Rating) appear correctly', (tester) async {
      await testRepo.submitFeedback(
        category: FeedbackCategory.bugReport,
        module: 'tasks',
        message: 'Task priority tag crashes UI on reorder',
      );
      await testRepo.submitFeedback(
        category: FeedbackCategory.featureRequest,
        module: 'money',
        message: 'Export monthly budgets to CSV',
      );
      await testRepo.submitFeedback(
        category: FeedbackCategory.generalFeedback,
        module: 'settings',
        message: 'Arc has transformed my daily routines and habits.',
      );
      await testRepo.submitFeedback(
        category: FeedbackCategory.appRating,
        module: 'general',
        message: 'Brilliant app and smooth animations.',
        rating: 5,
      );

      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      expect(find.text('Report a Bug'), findsOneWidget);
      expect(find.text('Suggest a Feature'), findsOneWidget);
      expect(find.text('General Feedback'), findsOneWidget);
      expect(find.text('Rate Arc'), findsOneWidget);
      expect(find.text('5'), findsOneWidget); // Rating indicator
    });

    // 6. Status transitions (submitted -> emailed -> reviewed -> acknowledged)
    testWidgets('Requirement 6: Status transitions update in real-time stream', (tester) async {
      final feedback = await testRepo.submitFeedback(
        category: FeedbackCategory.generalFeedback,
        module: 'general',
        message: 'Love the minimalist interface!',
      );

      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      expect(find.text('Submitted'), findsOneWidget);

      // Transition to emailed / Dispatched
      await testRepo.updateFeedbackAdminStatus(
        feedbackId: feedback.feedbackId,
        status: FeedbackStatus.emailed,
      );
      await tester.pumpAndSettle();
      expect(find.text('Dispatched'), findsOneWidget);

      // Transition to reviewed / In Review
      await testRepo.updateFeedbackAdminStatus(
        feedbackId: feedback.feedbackId,
        status: FeedbackStatus.reviewed,
        reviewedAt: DateTime.now(),
      );
      await tester.pumpAndSettle();
      expect(find.text('In Review'), findsOneWidget);

      // Transition to acknowledged
      final ackDate = DateTime(2026, 10, 26, 14, 30);
      await testRepo.updateFeedbackAdminStatus(
        feedbackId: feedback.feedbackId,
        status: FeedbackStatus.acknowledged,
        acknowledgedAt: ackDate,
      );
      await tester.pumpAndSettle();
      expect(find.text('Acknowledged'), findsOneWidget);
      expect(find.textContaining('Acknowledged on Oct 26, 2026'), findsOneWidget);
    });

    // 7. User isolation
    testWidgets('Requirement 7: User isolation ensures User A only sees User A feedback', (tester) async {
      // Seed feedback for Alice
      testRepo.activeUserId = 'user_alice';
      await testRepo.submitFeedback(
        category: FeedbackCategory.bugReport,
        module: 'tasks',
        message: 'Alice private bug report',
      );

      // Seed feedback for Bob
      testRepo.activeUserId = 'user_bob';
      await testRepo.submitFeedback(
        category: FeedbackCategory.featureRequest,
        module: 'habits',
        message: 'Bob private feature suggestion',
      );

      // Active user in context is Alice
      testRepo.activeUserId = 'user_alice';
      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      expect(find.text('Alice private bug report'), findsOneWidget);
      expect(find.text('Bob private feature suggestion'), findsNothing);
    });

    // 8. Loading state during auth initialization
    testWidgets('Requirement 8: Shows loading spinner, NOT empty state, during auth initialization', (tester) async {
      testUserNotifier.setInitializing();

      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pump(); // Pump frame without settling

      // Verify loading indicator is present
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No Feedback Yet'), findsNothing);

      // Now complete auth initialization
      testUserNotifier.setUser('user_alice', 'Alice');
      await tester.pumpAndSettle();

      // Confirmed empty state only after auth finishes
      expect(find.text('No Feedback Yet'), findsOneWidget);
    });

    // 9. Query errors do not render as empty list
    testWidgets('Requirement 9: Stream errors display error UI with Retry button, never empty state', (tester) async {
      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      // Emit error
      testRepo.emitError(Exception('Firestore connection failure'));
      await tester.pumpAndSettle();

      expect(find.text('Unable to Load Feedback'), findsOneWidget);
      expect(find.text('Please check your network connection and try again.'), findsOneWidget);
      expect(find.byKey(const Key('my_feedback_retry_button')), findsOneWidget);
      expect(find.text('No Feedback Yet'), findsNothing);
    });

    // 10. AppBar back arrow navigates to Settings
    testWidgets('Requirement 10: Tapping AppBar back arrow returns to Settings when navigated from Settings', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = createTestRouter(initialLocation: '/settings');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      // Navigate to My Feedback
      final myFeedbackTile = find.byKey(const Key('settings_my_feedback_tile'));
      await tester.tap(myFeedbackTile);
      await tester.pumpAndSettle();

      expect(find.byType(MyFeedbackScreen), findsOneWidget);

      // Tap back button
      final backButton = find.byKey(const Key('my_feedback_back_button'));
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify returned to Settings
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(MyFeedbackScreen), findsNothing);
    });

    // 11. Android system back / PopScope navigates to Settings
    testWidgets('Requirement 11: Android system back returns to Settings without closing application', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = createTestRouter(initialLocation: '/settings');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      // Navigate to My Feedback
      final myFeedbackTile = find.byKey(const Key('settings_my_feedback_tile'));
      await tester.tap(myFeedbackTile);
      await tester.pumpAndSettle();

      expect(find.byType(MyFeedbackScreen), findsOneWidget);

      // Simulate Android hardware back button
      final didPop = await tester.binding.handlePopRoute();
      expect(didPop, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    // 12. Back navigation works from detail sheet
    testWidgets('Requirement 12: Back navigation from detail bottom sheet restores MyFeedbackScreen', (tester) async {
      await testRepo.submitFeedback(
        category: FeedbackCategory.bugReport,
        module: 'habits',
        message: 'Detailed problem description in sheet',
      );

      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      // Tap the card to open detail sheet
      await tester.tap(find.text('Detailed problem description in sheet'));
      await tester.pumpAndSettle();

      // Verify bottom sheet is displayed
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Ticket ID: fb_1'), findsOneWidget);

      // Tap back / pop sheet
      final didPop = await tester.binding.handlePopRoute();
      expect(didPop, isTrue);
      await tester.pumpAndSettle();

      // Bottom sheet dismissed, MyFeedbackScreen still active
      expect(find.text('Message'), findsNothing);
      expect(find.byType(MyFeedbackScreen), findsOneWidget);
    });

    // 13. Deep-link / no-stack navigation falls back to Settings
    testWidgets('Requirement 13: Direct deep-link navigation without prior stack falls back to Settings', (tester) async {
      // Open directly at /feedback/my-feedback with no previous history in stack
      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      expect(find.byType(MyFeedbackScreen), findsOneWidget);

      // Tap AppBar back arrow
      final backButton = find.byKey(const Key('my_feedback_back_button'));
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Fallback routed to /settings instead of crashing or closing app
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    // 14. Empty-state "Submit Feedback" and plus icon navigate to category selection
    testWidgets('Requirement 14: Empty state action and plus icon open category selection sheet', (tester) async {
      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      // 1. Test empty-state action button
      final submitButton = find.widgetWithText(ElevatedButton, 'Submit Feedback');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Category bottom sheet opened
      expect(find.text('Send Feedback'), findsOneWidget);
      expect(find.text('Report a Bug'), findsOneWidget);
      expect(find.text('Suggest a Feature'), findsOneWidget);
      expect(find.text('General Feedback'), findsOneWidget);
      expect(find.text('Rate Arc'), findsOneWidget);

      // Close bottom sheet
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Send Feedback'), findsNothing);

      // 2. Test top-right plus button
      final plusButton = find.byKey(const Key('my_feedback_add_button'));
      expect(plusButton, findsOneWidget);
      await tester.tap(plusButton);
      await tester.pumpAndSettle();

      expect(find.text('Send Feedback'), findsOneWidget);

      // Tap "Report a Bug" in category sheet and verify navigation
      await tester.tap(find.text('Report a Bug'));
      await tester.pumpAndSettle();

      expect(find.byType(BugReportScreen), findsOneWidget);
    });

    // 15. Account switching resets stream and avoids stale feedback
    testWidgets('Requirement 15: Switching accounts immediately resets stream without stale data', (tester) async {
      // Alice has 1 submission
      testRepo.activeUserId = 'user_alice';
      await testRepo.submitFeedback(
        category: FeedbackCategory.bugReport,
        module: 'tasks',
        message: 'Alice secret submission',
      );

      // Bob has 1 submission
      testRepo.activeUserId = 'user_bob';
      await testRepo.submitFeedback(
        category: FeedbackCategory.featureRequest,
        module: 'money',
        message: 'Bob secret submission',
      );

      testRepo.activeUserId = 'user_alice';
      final router = createTestRouter(initialLocation: '/feedback/my-feedback');
      await tester.pumpWidget(createTestApp(router: router));
      await tester.pumpAndSettle();

      expect(find.text('Alice secret submission'), findsOneWidget);
      expect(find.text('Bob secret submission'), findsNothing);

      // Switch active account to Bob
      testRepo.activeUserId = 'user_bob';
      testUserNotifier.setUser('user_bob', 'Bob');
      await tester.pumpAndSettle();

      // Stream immediately updates: Alice's feedback is gone, Bob's is shown
      expect(find.text('Alice secret submission'), findsNothing);
      expect(find.text('Bob secret submission'), findsOneWidget);
    });
  });
}
