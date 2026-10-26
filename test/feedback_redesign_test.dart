import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/providers/feedback_providers.dart';
import 'package:arc/features/feedback/repository/feedback_repository.dart';
import 'package:arc/features/feedback/screens/feedback_form_screen.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';

class MockFeedbackRepository implements IFeedbackRepository {
  final List<FeedbackModel> submissions = [];
  bool shouldThrow = false;

  @override
  String? get currentUserId => 'test_user_uid';

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
    if (shouldThrow) {
      throw StateError('Simulated offline failure');
    }
    final model = FeedbackModel(
      feedbackId: feedbackId ?? 'mock-fb-${submissions.length + 1}',
      userId: 'test_user_uid',
      category: category,
      module: module,
      message: message,
      rating: rating,
      contactEmail: contactEmail,
      appVersion: appVersion ?? '1.3.5',
      createdAt: DateTime.now(),
      status: FeedbackStatus.submitted,
    );
    submissions.add(model);
    return model;
  }

  @override
  Future<List<FeedbackModel>> getCurrentUserFeedback({String? userId}) async => submissions;

  @override
  Stream<List<FeedbackModel>> watchCurrentUserFeedback({String? userId}) => Stream.value(submissions);

  @override
  Future<FeedbackModel?> getFeedbackStatus(String feedbackId) async =>
      submissions.firstWhere((f) => f.feedbackId == feedbackId);

  @override
  Stream<FeedbackModel?> watchFeedbackStatus(String feedbackId) =>
      Stream.value(submissions.firstWhere((f) => f.feedbackId == feedbackId));

  @override
  Future<List<FeedbackModel>> getFeedbackForAdmin({
    String? status,
    String? category,
    int limit = 50,
  }) async => submissions;

  @override
  Future<void> updateFeedbackAdminStatus({
    required String feedbackId,
    required String status,
    DateTime? reviewedAt,
    DateTime? acknowledgedAt,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFeedbackRepository mockRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepo = MockFeedbackRepository();
  });

  Widget createBugReportApp() {
    return ProviderScope(
      overrides: [
        feedbackRepositoryProvider.overrideWithValue(mockRepo),
        userContextProvider.overrideWith((ref) {
          final notifier = UserContextNotifier();
          notifier.setActiveUser(
            userId: 'test_user_uid',
            profile: UserProfile(
              id: 'test_user_uid',
              username: 'Tester',
              displayName: 'Test User',
              email: 'tester@arc.app',
              createdAt: DateTime.now(),
            ),
          );
          return notifier;
        }),
      ],
      child: const MaterialApp(
        home: BugReportScreen(),
      ),
    );
  }

  Widget createFeatureRequestApp() {
    return ProviderScope(
      overrides: [
        feedbackRepositoryProvider.overrideWithValue(mockRepo),
        userContextProvider.overrideWith((ref) {
          final notifier = UserContextNotifier();
          notifier.setActiveUser(
            userId: 'test_user_uid',
            profile: UserProfile(
              id: 'test_user_uid',
              username: 'Tester',
              displayName: 'Test User',
              email: 'tester@arc.app',
              createdAt: DateTime.now(),
            ),
          );
          return notifier;
        }),
      ],
      child: const MaterialApp(
        home: FeatureRequestScreen(),
      ),
    );
  }

  group('Feedback UI Redesign: Serialization Tests', () {
    test('BugReportPayload serializes into structured diagnostic sections', () {
      const payload = BugReportPayload(
        module: 'task_manager',
        title: 'Due date picker crashes on leap year',
        description: 'App freezes when selecting February 29th in date picker modal.',
        stepsToReproduce: '1. Open Tasks\n2. Tap New Task\n3. Select Feb 29 2028',
        expectedBehavior: 'Date picker should select the date gracefully.',
        actualBehavior: 'Uncaught NoSuchMethodError thrown and UI locks.',
        contactEmail: 'qa@arc.app',
      );

      final serialized = payload.toSerializedMessage();
      expect(serialized, contains('[ISSUE TITLE]'));
      expect(serialized, contains('Due date picker crashes on leap year'));
      expect(serialized, contains('[PROBLEM DESCRIPTION]'));
      expect(serialized, contains('App freezes when selecting February 29th'));
      expect(serialized, contains('[STEPS TO REPRODUCE]'));
      expect(serialized, contains('[EXPECTED BEHAVIOR]'));
      expect(serialized, contains('[ACTUAL BEHAVIOR]'));
      expect(serialized.length, lessThanOrEqualTo(5000));
      expect(payload.validate(), isNull);
    });

    test('BugReportPayload validates required fields', () {
      const emptyTitle = BugReportPayload(
        module: 'general',
        title: '',
        description: 'Valid description here',
        stepsToReproduce: 'Step 1',
        expectedBehavior: 'Expected',
        actualBehavior: 'Actual',
      );
      expect(emptyTitle.validate(), contains('title'));

      const shortDesc = BugReportPayload(
        module: 'general',
        title: 'Title',
        description: 'Short',
        stepsToReproduce: 'Step 1',
        expectedBehavior: 'Expected',
        actualBehavior: 'Actual',
      );
      expect(shortDesc.validate(), contains('at least 10 characters'));
    });

    test('FeatureRequestPayload serializes into creative idea vision block', () {
      const payload = FeatureRequestPayload(
        module: 'habit_tracker',
        title: 'Streak Freeze Power-Up',
        description: 'Allow users to bank 1 rest day per month to preserve habits.',
        benefit: 'Reduces user discouragement after unavoidable illnesses or travels.',
        contactEmail: 'creator@arc.app',
      );

      final serialized = payload.toSerializedMessage();
      expect(serialized, contains('[FEATURE TITLE]'));
      expect(serialized, contains('Streak Freeze Power-Up'));
      expect(serialized, contains('[IDEA DESCRIPTION]'));
      expect(serialized, contains('Allow users to bank 1 rest day'));
      expect(serialized, contains('[VALUE & BENEFIT]'));
      expect(serialized, contains('Reduces user discouragement'));
      expect(serialized.length, lessThanOrEqualTo(5000));
      expect(payload.validate(), isNull);
    });

    test('FeatureRequestPayload validates required fields', () {
      const emptyTitle = FeatureRequestPayload(
        module: 'general',
        title: '',
        description: 'Valid description here',
      );
      expect(emptyTitle.validate(), contains('title'));

      const shortDesc = FeatureRequestPayload(
        module: 'general',
        title: 'Valid Idea Title',
        description: 'Too short',
      );
      expect(shortDesc.validate(), contains('at least 10 characters'));
    });
  });

  group('Feedback UI Redesign: BugReportScreen UI & Flow Tests', () {
    testWidgets('Renders professional diagnostic layout with all required sections', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createBugReportApp());
      await tester.pumpAndSettle();

      // Verify diagnostic banner & headers
      expect(find.text('Report a Bug'), findsOneWidget);
      expect(find.text('DIAGNOSTIC PROTOCOL'), findsOneWidget);
      expect(find.text('Structured Technical Defect Report'), findsOneWidget);

      // Verify numbered technical sections
      expect(find.text('01'), findsOneWidget);
      expect(find.text('Affected Component'), findsOneWidget);
      expect(find.text('02'), findsOneWidget);
      expect(find.text('Issue Summary'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      expect(find.text('Problem Description'), findsOneWidget);
      expect(find.text('04'), findsOneWidget);
      expect(find.text('Steps to Reproduce'), findsOneWidget);
      expect(find.text('05'), findsOneWidget);
      expect(find.text('Diagnostic Contrast'), findsOneWidget);
      expect(find.text('Expected Behavior'), findsOneWidget);
      expect(find.text('Actual Behavior'), findsOneWidget);
      expect(find.text('06'), findsOneWidget);
      expect(find.text('Follow-up Contact (Optional)'), findsOneWidget);

      // Verify Submit Button
      expect(find.text('Submit Bug Report'), findsOneWidget);
    });

    testWidgets('Validates required fields and submits bug report to repository', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createBugReportApp());
      await tester.pumpAndSettle();

      // Tap submit with empty form -> blocked
      await tester.tap(find.text('Submit Bug Report'));
      await tester.pumpAndSettle();

      expect(mockRepo.submissions, isEmpty);
      expect(find.text('Please provide a short issue title.'), findsWidgets);

      // Fill in all required fields
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Pomodoro timer stops on backgrounding');
      await tester.enterText(textFields.at(1), 'Timer audio stops immediately when user switches to another application.');
      await tester.enterText(textFields.at(2), '1. Start timer\n2. Press Home button\n3. Wait 1 minute');
      await tester.enterText(textFields.at(3), 'Timer should tick in background and chime upon completion.');
      await tester.enterText(textFields.at(4), 'Timer pauses completely until app is resumed.');
      await tester.pumpAndSettle();

      // Tap submit again -> success
      await tester.tap(find.text('Submit Bug Report'));
      await tester.pumpAndSettle();

      expect(mockRepo.submissions.length, 1);
      final submitted = mockRepo.submissions.first;
      expect(submitted.category, FeedbackCategory.bugReport);
      expect(submitted.message, contains('[ISSUE TITLE]'));
      expect(submitted.message, contains('Pomodoro timer stops on backgrounding'));
      expect(submitted.message, contains('[STEPS TO REPRODUCE]'));
      expect(submitted.message, contains('[EXPECTED BEHAVIOR]'));
      expect(submitted.message, contains('[ACTUAL BEHAVIOR]'));

      // Confirmation dialog displayed
      expect(find.text('Bug Report Submitted'), findsOneWidget);
    });

    testWidgets('Draft autosave preserves all diagnostic fields and restores them on load', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final draftService = FeedbackDraftService();

      // Save a structured draft directly
      const payload = BugReportPayload(
        module: 'habit_tracker',
        title: 'Habit checkmark lag',
        description: 'Tapping complete takes 3 seconds to update the streak.',
        stepsToReproduce: '1. Tap habit circle\n2. Wait for animation',
        expectedBehavior: 'Instant haptic response and visual checkmark.',
        actualBehavior: 'Delayed reaction and UI hiccup.',
        contactEmail: 'beta@arc.app',
      );

      await draftService.saveDraft(
        category: FeedbackCategory.bugReport,
        module: payload.module,
        message: payload.toSerializedMessage(),
        contactEmail: payload.contactEmail,
        extraFields: payload.toDraftMap(),
      );

      // Launch screen -> draft automatically restored
      await tester.pumpWidget(createBugReportApp());
      await tester.pumpAndSettle();

      expect(find.text('Habit checkmark lag'), findsOneWidget);
      expect(find.text('Tapping complete takes 3 seconds to update the streak.'), findsOneWidget);
      expect(find.text('Instant haptic response and visual checkmark.'), findsOneWidget);
      expect(find.text('Delayed reaction and UI hiccup.'), findsOneWidget);
      expect(find.text('Restored your previously saved bug report draft.'), findsOneWidget);
    });
  });

  group('Feedback UI Redesign: FeatureRequestScreen UI & Flow Tests', () {
    testWidgets('Renders welcoming creative ideation layout with all required sections', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createFeatureRequestApp());
      await tester.pumpAndSettle();

      // Verify creative hero banner
      expect(find.text('Suggest a Feature'), findsOneWidget);
      expect(find.text('FEATURE LAB'), findsOneWidget);
      expect(find.text('Have a great idea for Arc?'), findsOneWidget);

      // Verify creative ideation sections
      expect(find.text('Idea Title'), findsOneWidget);
      expect(find.text('Where does this belong?'), findsOneWidget);
      expect(find.text('Tell Us About Your Idea'), findsOneWidget);
      expect(find.text('Why is this valuable? (Optional)'), findsOneWidget);
      expect(find.text('Stay in the Loop (Optional)'), findsOneWidget);

      // Verify module filter chips
      expect(find.text('Task Manager'), findsWidgets);
      expect(find.text('Habit Tracker'), findsWidgets);
      expect(find.text('Secret Notes'), findsWidgets);

      // Verify Submit Button
      expect(find.text('Submit Suggestion'), findsOneWidget);
    });

    testWidgets('Validates required fields and submits feature suggestion to repository', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createFeatureRequestApp());
      await tester.pumpAndSettle();

      // Tap submit with empty form -> blocked
      await tester.tap(find.text('Submit Suggestion'));
      await tester.pumpAndSettle();

      expect(mockRepo.submissions, isEmpty);
      expect(find.text('Please give your idea a title.'), findsWidgets);

      // Fill in fields
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Voice Memo to Task Conversion');
      await tester.enterText(textFields.at(1), 'Add a microphone button to record audio that automatically transcribes into a task with due dates.');
      await tester.enterText(textFields.at(2), 'Allows hands-free capture while walking or commuting without typing.');
      await tester.pumpAndSettle();

      // Select 'Task Manager' module chip
      await tester.tap(find.widgetWithText(FilterChip, 'Task Manager'));
      await tester.pumpAndSettle();

      // Tap submit -> success
      await tester.tap(find.text('Submit Suggestion'));
      await tester.pumpAndSettle();

      expect(mockRepo.submissions.length, 1);
      final submitted = mockRepo.submissions.first;
      expect(submitted.category, FeedbackCategory.featureRequest);
      expect(submitted.module, 'task_manager');
      expect(submitted.message, contains('[FEATURE TITLE]'));
      expect(submitted.message, contains('Voice Memo to Task Conversion'));
      expect(submitted.message, contains('[VALUE & BENEFIT]'));

      // Confirmation dialog displayed
      expect(find.text('Idea Received!'), findsOneWidget);
    });

    testWidgets('Draft autosave preserves creative ideation fields and restores them on load', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final draftService = FeedbackDraftService();

      const payload = FeatureRequestPayload(
        module: 'money_tracker',
        title: 'Automated Receipt Scanning with OCR',
        description: 'Snap a picture of a store receipt and extract total price.',
        benefit: 'Reduces manual expense logging friction.',
      );

      await draftService.saveDraft(
        category: FeedbackCategory.featureRequest,
        module: payload.module,
        message: payload.toSerializedMessage(),
        extraFields: payload.toDraftMap(),
      );

      // Launch screen -> draft automatically restored
      await tester.pumpWidget(createFeatureRequestApp());
      await tester.pumpAndSettle();

      expect(find.text('Automated Receipt Scanning with OCR'), findsOneWidget);
      expect(find.text('Snap a picture of a store receipt and extract total price.'), findsOneWidget);
      expect(find.text('Reduces manual expense logging friction.'), findsOneWidget);
      expect(find.text('Restored your previously saved feature suggestion.'), findsOneWidget);
    });
  });

  group('Feedback UI Redesign: GoRouter Integration & Visual Distinction', () {
    testWidgets('Routing to /feedback with category switches between dedicated screens', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Bug report route
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/feedback?category=bug_report',
              routes: [
                GoRoute(
                  path: '/feedback',
                  builder: (context, state) {
                    final cat = state.uri.queryParameters['category'];
                    if (cat == FeedbackCategory.bugReport) {
                      return const BugReportScreen();
                    } else if (cat == FeedbackCategory.featureRequest) {
                      return const FeatureRequestScreen();
                    }
                    return FeedbackFormScreen(initialCategory: cat);
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified BugReportScreen is rendered
      expect(find.byType(BugReportScreen), findsOneWidget);
      expect(find.text('DIAGNOSTIC PROTOCOL'), findsOneWidget);
      expect(find.byType(FeatureRequestScreen), findsNothing);
      expect(find.byType(FeedbackFormScreen), findsNothing);
    });

    testWidgets('Routing to /feedback?category=feature_request renders FeatureRequestScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/feedback?category=feature_request',
              routes: [
                GoRoute(
                  path: '/feedback',
                  builder: (context, state) {
                    final cat = state.uri.queryParameters['category'];
                    if (cat == FeedbackCategory.bugReport) {
                      return const BugReportScreen();
                    } else if (cat == FeedbackCategory.featureRequest) {
                      return const FeatureRequestScreen();
                    }
                    return FeedbackFormScreen(initialCategory: cat);
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified FeatureRequestScreen is rendered
      expect(find.byType(FeatureRequestScreen), findsOneWidget);
      expect(find.text('FEATURE LAB'), findsOneWidget);
      expect(find.byType(BugReportScreen), findsNothing);
      expect(find.byType(FeedbackFormScreen), findsNothing);
    });

    testWidgets('Routing to /feedback?category=general_feedback renders original FeedbackFormScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/feedback?category=general_feedback',
              routes: [
                GoRoute(
                  path: '/feedback',
                  builder: (context, state) {
                    final cat = state.uri.queryParameters['category'];
                    if (cat == FeedbackCategory.bugReport) {
                      return const BugReportScreen();
                    } else if (cat == FeedbackCategory.featureRequest) {
                      return const FeatureRequestScreen();
                    }
                    return FeedbackFormScreen(initialCategory: cat);
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified original FeedbackFormScreen is rendered for general feedback
      expect(find.byType(FeedbackFormScreen), findsOneWidget);
      expect(find.byType(BugReportScreen), findsNothing);
      expect(find.byType(FeatureRequestScreen), findsNothing);
    });
  });
}
