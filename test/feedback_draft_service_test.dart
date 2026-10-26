import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/services/feedback_draft_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FeedbackDraftService draftService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    draftService = FeedbackDraftService();
  });

  group('FeedbackDraftService Tests', () {
    test('Saves, loads, and verifies draft presence', () async {
      expect(await draftService.hasDraft(FeedbackCategory.bugReport), isFalse);

      await draftService.saveDraft(
        category: FeedbackCategory.bugReport,
        module: 'task_manager',
        message: 'Unfinished bug report about sync crash',
        rating: 3,
        contactEmail: 'tester@arc.app',
      );

      expect(await draftService.hasDraft(FeedbackCategory.bugReport), isTrue);

      final draft = await draftService.loadDraft(FeedbackCategory.bugReport);
      expect(draft, isNotNull);
      expect(draft!['category'], equals(FeedbackCategory.bugReport));
      expect(draft['module'], equals('task_manager'));
      expect(draft['message'], equals('Unfinished bug report about sync crash'));
      expect(draft['rating'], equals(3));
      expect(draft['contactEmail'], equals('tester@arc.app'));
    });

    test('Clears draft upon successful submission', () async {
      await draftService.saveDraft(
        category: FeedbackCategory.featureRequest,
        module: 'habit_tracker',
        message: 'Weekly habit review graphs',
      );

      expect(await draftService.hasDraft(FeedbackCategory.featureRequest), isTrue);

      await draftService.clearDraft(FeedbackCategory.featureRequest);

      expect(await draftService.hasDraft(FeedbackCategory.featureRequest), isFalse);
      expect(await draftService.loadDraft(FeedbackCategory.featureRequest), isNull);
    });

    test('Does not save completely empty drafts and clears previous empty entries', () async {
      await draftService.saveDraft(
        category: FeedbackCategory.generalFeedback,
        module: 'general',
        message: 'Some text',
      );
      expect(await draftService.hasDraft(FeedbackCategory.generalFeedback), isTrue);

      // Save blank
      await draftService.saveDraft(
        category: FeedbackCategory.generalFeedback,
        module: 'general',
        message: '   ',
        rating: null,
        contactEmail: null,
      );

      expect(await draftService.hasDraft(FeedbackCategory.generalFeedback), isFalse);
    });

    test('Drafts are isolated per category', () async {
      await draftService.saveDraft(
        category: FeedbackCategory.bugReport,
        module: 'tasks',
        message: 'Bug draft',
      );
      await draftService.saveDraft(
        category: FeedbackCategory.featureRequest,
        module: 'habits',
        message: 'Feature draft',
      );

      final bugDraft = await draftService.loadDraft(FeedbackCategory.bugReport);
      final featureDraft = await draftService.loadDraft(FeedbackCategory.featureRequest);

      expect(bugDraft!['message'], equals('Bug draft'));
      expect(featureDraft!['message'], equals('Feature draft'));

      await draftService.clearDraft(FeedbackCategory.bugReport);
      expect(await draftService.hasDraft(FeedbackCategory.bugReport), isFalse);
      expect(await draftService.hasDraft(FeedbackCategory.featureRequest), isTrue);
    });
  });
}
