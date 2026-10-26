import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/providers/feedback_providers.dart';
import 'package:arc/features/feedback/repository/feedback_repository.dart';
import 'package:arc/features/feedback/screens/feedback_form_screen.dart';
import 'package:arc/features/feedback/screens/my_feedback_screen.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';

class MockFeedbackRepository implements IFeedbackRepository {
  final List<FeedbackModel> submissions = [];
  bool shouldThrowOnSubmit = false;

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
    if (shouldThrowOnSubmit) {
      throw StateError('Network unavailable');
    }
    final model = FeedbackModel(
      feedbackId: feedbackId ?? 'fb-test-mock-${submissions.length + 1}',
      userId: 'uid_tester',
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
  Future<FeedbackModel?> getFeedbackStatus(String feedbackId) async {
    try {
      return submissions.firstWhere((f) => f.feedbackId == feedbackId);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<FeedbackModel?> watchFeedbackStatus(String feedbackId) {
    try {
      return Stream.value(submissions.firstWhere((f) => f.feedbackId == feedbackId));
    } catch (_) {
      return Stream.value(null);
    }
  }

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

  Widget buildFormApp({String? initialCategory}) {
    return ProviderScope(
      overrides: [
        feedbackRepositoryProvider.overrideWithValue(mockRepo),
        userContextProvider.overrideWith((ref) {
          final notifier = UserContextNotifier();
          notifier.setActiveUser(
            userId: 'uid_tester',
            profile: UserProfile(
              id: 'uid_tester',
              username: 'Tester',
              displayName: 'Tester User',
              email: 'tester@arc.app',
              createdAt: DateTime.now(),
            ),
          );
          return notifier;
        }),
      ],
      child: MaterialApp(
        home: FeedbackFormScreen(initialCategory: initialCategory),
      ),
    );
  }

  Widget buildMyFeedbackApp(List<FeedbackModel> initialItems) {
    mockRepo.submissions.addAll(initialItems);

    return ProviderScope(
      overrides: [
        feedbackRepositoryProvider.overrideWithValue(mockRepo),
        currentUserFeedbackStreamProvider.overrideWith(
          (ref) => Stream.value(mockRepo.submissions),
        ),
      ],
      child: const MaterialApp(
        home: MyFeedbackScreen(),
      ),
    );
  }

  group('FeedbackFormScreen Tests', () {
    testWidgets('Renders all four category choice chips', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildFormApp(initialCategory: FeedbackCategory.bugReport));
      await tester.pumpAndSettle();

      expect(find.text('Report a Bug'), findsWidgets);
      expect(find.text('Suggest a Feature'), findsWidgets);
      expect(find.text('General Feedback'), findsWidgets);
      expect(find.text('Rate Arc'), findsWidgets);
    });

    testWidgets('Category selection switches description and rating requirements', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildFormApp(initialCategory: FeedbackCategory.bugReport));
      await tester.pumpAndSettle();

      // Initially Report a Bug
      expect(find.text('Encountered an unexpected glitch or error? Help us fix it with details.'), findsOneWidget);

      // Switch to Suggest a Feature
      final featureChip = find.widgetWithText(ChoiceChip, 'Suggest a Feature');
      await tester.ensureVisible(featureChip);
      await tester.tap(featureChip);
      await tester.pumpAndSettle();

      expect(find.text('Have an idea to make Arc more productive? Share your vision.'), findsOneWidget);

      // Switch to Rate Arc
      final rateChip = find.widgetWithText(ChoiceChip, 'Rate Arc');
      await tester.ensureVisible(rateChip);
      await tester.tap(rateChip);
      await tester.pumpAndSettle();

      expect(find.text('Rate Your Experience'), findsOneWidget);
      expect(find.text('Tap a star to rate (Required)'), findsOneWidget);
    });

    testWidgets('Validates message and blocks submit when empty', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildFormApp(initialCategory: FeedbackCategory.generalFeedback));
      await tester.pumpAndSettle();

      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Submit Feedback');
      await tester.ensureVisible(submitBtnFinder);
      expect(submitBtnFinder, findsOneWidget);

      // Button is disabled when text is empty
      final button = tester.widget<ElevatedButton>(submitBtnFinder);
      expect(button.onPressed, isNull);

      // Enter valid text
      await tester.enterText(find.byType(TextFormField).first, 'Arc has dramatically improved my daily habits!');
      await tester.pumpAndSettle();

      final activeBtn = tester.widget<ElevatedButton>(submitBtnFinder);
      expect(activeBtn.onPressed, isNotNull);
    });

    testWidgets('Submits feedback successfully and shows success confirmation', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildFormApp(initialCategory: FeedbackCategory.featureRequest));
      await tester.pumpAndSettle();

      // Enter message
      await tester.enterText(
        find.byType(TextFormField).first,
        'Please add tag filtering for tasks',
      );
      await tester.pumpAndSettle();

      // Tap submit
      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Submit Feedback');
      await tester.ensureVisible(submitBtnFinder);
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      // Verify repository submission
      expect(mockRepo.submissions.length, equals(1));
      expect(mockRepo.submissions.first.category, equals(FeedbackCategory.featureRequest));
      expect(mockRepo.submissions.first.message, equals('Please add tag filtering for tasks'));

      // Verify success dialog
      expect(find.text('Feedback Received'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('View My Feedback'), findsOneWidget);
    });

    testWidgets('Offline/error preserves draft and displays user-friendly snackbar', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      mockRepo.shouldThrowOnSubmit = true;

      await tester.pumpWidget(buildFormApp(initialCategory: FeedbackCategory.bugReport));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Database write failed while offline',
      );
      await tester.pumpAndSettle();

      final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Submit Feedback');
      await tester.ensureVisible(submitBtnFinder);
      await tester.tap(submitBtnFinder);
      await tester.pumpAndSettle();

      // Verify non-technical error notification shown
      expect(find.textContaining('draft'), findsOneWidget);
      expect(mockRepo.submissions, isEmpty);
    });
  });

  group('MyFeedbackScreen Tests', () {
    testWidgets('Displays EmptyStateWidget when no submissions exist', (tester) async {
      await tester.pumpWidget(buildMyFeedbackApp([]));
      await tester.pumpAndSettle();

      expect(find.text('No Feedback Yet'), findsOneWidget);
      expect(find.text('Submit Feedback'), findsOneWidget);
    });

    testWidgets('Displays list of user submissions with status chips and details modal', (tester) async {
      final now = DateTime(2026, 10, 25, 14, 0);
      final items = [
        FeedbackModel(
          feedbackId: 'fb-001',
          userId: 'uid_tester',
          category: FeedbackCategory.bugReport,
          module: 'task_manager',
          message: 'Notification alarm did not trigger at set time',
          appVersion: '1.0.0+1',
          createdAt: now,
          status: FeedbackStatus.submitted,
        ),
        FeedbackModel(
          feedbackId: 'fb-002',
          userId: 'uid_tester',
          category: FeedbackCategory.appRating,
          module: 'general',
          message: 'Absolutely love the UI design and dark mode',
          rating: 5,
          appVersion: '1.0.0+1',
          createdAt: now.subtract(const Duration(days: 1)),
          status: FeedbackStatus.acknowledged,
        ),
      ];

      await tester.pumpWidget(buildMyFeedbackApp(items));
      await tester.pumpAndSettle();

      expect(find.text('Report a Bug'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Rate Arc'), findsOneWidget);
      expect(find.text('Acknowledged'), findsOneWidget);

      // Tap on item to open detail sheet
      await tester.tap(find.text('Notification alarm did not trigger at set time'));
      await tester.pumpAndSettle();

      expect(find.text('Message'), findsOneWidget);
      expect(find.text('Ticket ID: fb-001'), findsOneWidget);
    });

    testWidgets('Displays acknowledgement date chip and detail entry when acknowledgedAt is present', (tester) async {
      final now = DateTime(2026, 10, 26, 10, 30);
      final ackDate = DateTime(2026, 10, 26, 11, 45);
      final items = [
        FeedbackModel(
          feedbackId: 'fb-ack-test',
          userId: 'uid_tester',
          category: FeedbackCategory.featureRequest,
          module: 'money_tracker',
          message: 'Add CSV export functionality to monthly transactions report',
          appVersion: '1.3.5',
          createdAt: now,
          status: FeedbackStatus.acknowledged,
          acknowledgedAt: ackDate,
        ),
      ];

      await tester.pumpWidget(buildMyFeedbackApp(items));
      await tester.pumpAndSettle();

      // Card badge verification
      expect(find.text('Acknowledged'), findsOneWidget);
      expect(find.textContaining('Acknowledged on Oct 26, 2026'), findsOneWidget);

      // Open detail modal sheet
      await tester.tap(find.text('Add CSV export functionality to monthly transactions report'));
      await tester.pumpAndSettle();

      expect(find.text('Acknowledged On'), findsOneWidget);
      expect(find.textContaining('11:45 AM'), findsOneWidget);
    });
  });
}
