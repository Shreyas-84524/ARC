import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/providers/feedback_providers.dart';
import 'package:arc/features/feedback/repository/feedback_repository.dart';

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
  }) async {
    final index = submissions.indexWhere((e) => e.feedbackId == feedbackId);
    if (index != -1) {
      submissions[index] = submissions[index].copyWith(
        status: status,
        reviewedAt: reviewedAt,
        acknowledgedAt: acknowledgedAt,
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFeedbackRepository mockRepo;

  setUp(() {
    mockRepo = MockFeedbackRepository();
    SharedPreferences.setMockInitialValues({});
  });

  group('Feedback UI Redesign Phase 2: Serialization Tests', () {
    test('GeneralFeedbackPayload serializes into conversational block without prompt', () {
      const payload = GeneralFeedbackPayload(
        module: 'general',
        message: 'Arc is working wonderfully for my daily habit tracking.',
      );

      final serialized = payload.toSerializedMessage();
      expect(serialized, contains('[FEEDBACK]'));
      expect(serialized, contains('Arc is working wonderfully for my daily habit tracking.'));
      expect(serialized, isNot(contains('[TOPIC')));
    });

    test('GeneralFeedbackPayload serializes with selected inspiration topic', () {
      const payload = GeneralFeedbackPayload(
        module: 'habit_tracker',
        message: 'The animations when finishing a streak feel super satisfying.',
        selectedPrompt: 'What do you enjoy about Arc?',
      );

      final serialized = payload.toSerializedMessage();
      expect(serialized, contains('[TOPIC: What do you enjoy about Arc?]'));
      expect(serialized, contains('[FEEDBACK]'));
      expect(serialized, contains('The animations when finishing a streak feel super satisfying.'));
    });

    test('GeneralFeedbackPayload validates required message length', () {
      const emptyPayload = GeneralFeedbackPayload(
        module: 'general',
        message: '',
      );
      expect(emptyPayload.validate(), isNotNull);

      const shortPayload = GeneralFeedbackPayload(
        module: 'general',
        message: 'hi',
      );
      expect(shortPayload.validate(), isNotNull);

      const validPayload = GeneralFeedbackPayload(
        module: 'general',
        message: 'This is a genuine piece of feedback.',
      );
      expect(validPayload.validate(), isNull);
    });

    test('RateArcPayload serializes rating with written review', () {
      const payload = RateArcPayload(
        rating: 5,
        writtenReview: 'Arc is by far my favorite productivity app!',
      );

      final serialized = payload.toSerializedMessage();
      expect(serialized, contains('[APP RATING]'));
      expect(serialized, contains('5 / 5 Stars (Loved it — Arc is indispensable!)'));
      expect(serialized, contains('[WRITTEN REVIEW]'));
      expect(serialized, contains('Arc is by far my favorite productivity app!'));
    });

    test('RateArcPayload generates meaningful serialized summary when review is omitted', () {
      const payload = RateArcPayload(
        rating: 4,
        writtenReview: null,
      );

      final serialized = payload.toSerializedMessage();
      expect(serialized, contains('[APP RATING]'));
      expect(serialized, contains('4 / 5 Stars (Great — Very satisfied)'));
      expect(serialized, contains('[WRITTEN REVIEW]'));
      expect(serialized, contains('(No written review provided)'));
      // Verifies string is non-empty for Firestore and repository validation
      expect(serialized.trim().isNotEmpty, isTrue);
    });

    test('RateArcPayload validates mandatory star rating', () {
      const unrated = RateArcPayload(rating: 0);
      expect(unrated.validate(), isNotNull);

      const invalidHigh = RateArcPayload(rating: 6);
      expect(invalidHigh.validate(), isNotNull);

      const validRating = RateArcPayload(rating: 5);
      expect(validRating.validate(), isNull);
    });
  });

  group('Feedback UI Redesign Phase 2: GeneralFeedbackScreen UI Tests', () {
    testWidgets('Renders conversational layout with hero header and inspiration prompts', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: GeneralFeedbackScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified conversational hero header
      expect(find.text("We're All Ears"), findsOneWidget);
      expect(find.text('Direct, thoughtful conversations with the builders'), findsOneWidget);

      // Verified inspiration prompts
      expect(find.text('INSPIRATION PROMPTS (OPTIONAL)'), findsOneWidget);
      expect(find.text('What do you enjoy about Arc?'), findsOneWidget);
      expect(find.text('What could we improve?'), findsOneWidget);
      expect(find.text('Is anything making the app difficult to use?'), findsOneWidget);

      // Verified writing canvas and submit button
      expect(find.byType(TextFormField), findsWidgets);
      expect(find.text('Submit Feedback'), findsOneWidget);
    });

    testWidgets('Tapping prompt toggles active topic and populates topic chip', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: GeneralFeedbackScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on an inspiration prompt
      await tester.tap(find.text('What could we improve?'));
      await tester.pumpAndSettle();

      // Verified topic banner appears
      expect(find.text('Topic: What could we improve?'), findsOneWidget);

      // Tap again to clear
      await tester.tap(find.byIcon(LucideIcons.x));
      await tester.pumpAndSettle();

      // Topic banner disappears
      expect(find.text('Topic: What could we improve?'), findsNothing);
    });

    testWidgets('Validates message and submits general feedback to repository', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: GeneralFeedbackScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Submit while empty - should show validation error
      await tester.tap(find.text('Submit Feedback'));
      await tester.pumpAndSettle();

      expect(mockRepo.submissions.length, 0);
      expect(find.text('Please enter your thoughts before submitting.'), findsOneWidget);

      // Enter valid conversational message
      final textField = find.byType(TextFormField).first;
      await tester.enterText(textField, 'I really love the clean typography and quick gesture flow.');
      await tester.pumpAndSettle();

      // Tap Submit Feedback
      await tester.tap(find.text('Submit Feedback'));
      await tester.pumpAndSettle();

      // Verified submission to repository
      expect(mockRepo.submissions.length, 1);
      final submitted = mockRepo.submissions.first;
      expect(submitted.category, FeedbackCategory.generalFeedback);
      expect(submitted.message, contains('[FEEDBACK]'));
      expect(submitted.message, contains('I really love the clean typography and quick gesture flow.'));

      // Verified success dialog appears
      expect(find.text('Thank You!'), findsOneWidget);
      expect(find.text('View Status'), findsOneWidget);
    });

    testWidgets('Draft autosave preserves conversational message and restores on load', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final draftService = FeedbackDraftService();
      await draftService.saveDraft(
        category: FeedbackCategory.generalFeedback,
        module: 'general',
        message: 'Autosaved thought from earlier session',
        extraFields: {
          'message': 'Autosaved thought from earlier session',
          'selectedPrompt': 'What do you enjoy about Arc?',
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
            feedbackDraftServiceProvider.overrideWithValue(draftService),
          ],
          child: const MaterialApp(
            home: GeneralFeedbackScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify restored draft message and selected prompt
      expect(find.text('Autosaved thought from earlier session'), findsOneWidget);
      expect(find.text('Topic: What do you enjoy about Arc?'), findsOneWidget);
      expect(find.text('Restored your unsaved feedback draft'), findsOneWidget);
    });
  });

  group('Feedback UI Redesign Phase 2: RateArcScreen UI Tests', () {
    testWidgets('Renders rating-first layout with hero banner and 5 interactive stars', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: RateArcScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verified rating hero
      expect(find.text('Your Opinion Matters'), findsOneWidget);
      expect(find.text('How well is Arc helping you achieve daily momentum and focus?'), findsOneWidget);

      // Verified 5 stars exist
      expect(find.byIcon(LucideIcons.star), findsWidgets);
      expect(find.text('Tap a star to rate'), findsOneWidget);

      // Verified written review section (optional)
      expect(find.text('WRITTEN REVIEW (OPTIONAL)'), findsOneWidget);
      expect(find.text('Tap a Star to Rate'), findsOneWidget);
    });

    testWidgets('Selecting star updates score pill, reaction card, and button label', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: RateArcScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 5th star
      final stars = find.byIcon(LucideIcons.star);
      await tester.tap(stars.at(5)); // Note: first icon is in hero header, followed by 5 rating stars
      await tester.pumpAndSettle();

      // Verified score pill and button updated
      expect(find.text('★ 5.0 / 5.0'), findsOneWidget);
      expect(find.text('Loved it — Arc is indispensable!'), findsOneWidget);
      expect(find.text('Submit 5-Star Rating'), findsOneWidget);
    });

    testWidgets('Submits rating without written review successfully', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: RateArcScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 5th star
      final stars = find.byIcon(LucideIcons.star);
      await tester.tap(stars.at(5));
      await tester.pumpAndSettle();

      // Tap Submit Rating (review left empty)
      await tester.tap(find.text('Submit 5-Star Rating'));
      await tester.pumpAndSettle();

      // Verified repository received the rating
      expect(mockRepo.submissions.length, 1);
      final submitted = mockRepo.submissions.first;
      expect(submitted.category, FeedbackCategory.appRating);
      expect(submitted.rating, 5);
      expect(submitted.message, contains('[APP RATING]'));
      expect(submitted.message, contains('(No written review provided)'));

      // Verified celebration dialog
      expect(find.text('Rating Submitted!'), findsOneWidget);
      expect(find.text('View Status'), findsOneWidget);
    });

    testWidgets('Submits rating with written review when provided', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: RateArcScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 4th star
      final stars = find.byIcon(LucideIcons.star);
      await tester.tap(stars.at(4));
      await tester.pumpAndSettle();

      // Enter written review
      final reviewField = find.byType(TextFormField).first;
      await tester.enterText(reviewField, 'Fantastic daily driver. Would love more widgets!');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Submit 4-Star Rating'));
      await tester.pumpAndSettle();

      expect(mockRepo.submissions.length, 1);
      final submitted = mockRepo.submissions.first;
      expect(submitted.category, FeedbackCategory.appRating);
      expect(submitted.rating, 4);
      expect(submitted.message, contains('Fantastic daily driver. Would love more widgets!'));
    });

    testWidgets('Draft autosave preserves rating and review text and restores on load', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final draftService = FeedbackDraftService();
      await draftService.saveDraft(
        category: FeedbackCategory.appRating,
        module: 'general',
        message: 'Draft review',
        rating: 5,
        extraFields: {
          'rating': 5,
          'writtenReview': 'Saved review text in draft',
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
            feedbackDraftServiceProvider.overrideWithValue(draftService),
          ],
          child: const MaterialApp(
            home: RateArcScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify restored rating and review
      expect(find.text('★ 5.0 / 5.0'), findsOneWidget);
      expect(find.text('Saved review text in draft'), findsOneWidget);
      expect(find.text('Restored your unsaved rating draft'), findsOneWidget);
    });
  });

  group('Feedback UI Redesign Phase 2: All 4 Interfaces Navigation & Distinction', () {
    testWidgets('Routing to all 4 categories renders the respective dedicated screen', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/feedback?category=bug_report',
        routes: [
          GoRoute(
            path: '/feedback',
            builder: (context, state) {
              final category = state.uri.queryParameters['category'];
              if (category == FeedbackCategory.bugReport) {
                return const BugReportScreen();
              } else if (category == FeedbackCategory.featureRequest) {
                return const FeatureRequestScreen();
              } else if (category == FeedbackCategory.generalFeedback) {
                return const GeneralFeedbackScreen();
              } else if (category == FeedbackCategory.appRating || category == 'rate_arc') {
                return const RateArcScreen();
              }
              return const GeneralFeedbackScreen();
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            feedbackRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Bug Report Screen
      expect(find.byType(BugReportScreen), findsOneWidget);
      expect(find.text('DIAGNOSTIC PROTOCOL'), findsOneWidget);

      // 2. Feature Request Screen
      router.go('/feedback?category=feature_request');
      await tester.pumpAndSettle();
      expect(find.byType(FeatureRequestScreen), findsOneWidget);
      expect(find.text('FEATURE LAB'), findsOneWidget);

      // 3. General Feedback Screen
      router.go('/feedback?category=general_feedback');
      await tester.pumpAndSettle();
      expect(find.byType(GeneralFeedbackScreen), findsOneWidget);
      expect(find.text("We're All Ears"), findsOneWidget);

      // 4. Rate Arc Screen
      router.go('/feedback?category=app_rating');
      await tester.pumpAndSettle();
      expect(find.byType(RateArcScreen), findsOneWidget);
      expect(find.text('Your Opinion Matters'), findsOneWidget);
    });
  });
}
