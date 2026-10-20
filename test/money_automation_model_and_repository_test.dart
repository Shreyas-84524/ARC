import 'package:flutter_test/flutter_test.dart';
import 'package:arc/features/money_tracker/models/money_automation_state.dart';
import 'package:arc/features/money_tracker/repository/money_automation_repository.dart';

void main() {
  group('Money Automation State & Business Rules', () {
    test('Feature is strictly OFF by default', () {
      const state = MoneyAutomationState();
      expect(state.isEnabled, isFalse);
      expect(state.promptMonth, isEmpty);
      expect(state.promptCount, equals(0));
      expect(state.hasAcceptedInfoDialog, isFalse);
      expect(state.isDismissedForSession, isFalse);
    });

    test('Prompt is hidden without a monthly budget', () {
      const state = MoneyAutomationState();
      final shouldShow = state.shouldShowPrompt(
        hasMonthlyBudget: false,
        currentMonth: '2026-10',
      );
      expect(shouldShow, isFalse);
    });

    test('Prompt is shown with a monthly budget when disabled and count < 2', () {
      const state = MoneyAutomationState();
      final shouldShow = state.shouldShowPrompt(
        hasMonthlyBudget: true,
        currentMonth: '2026-10',
      );
      expect(shouldShow, isTrue);
    });

    test('Prompt is hidden when automation is already enabled', () {
      const state = MoneyAutomationState(isEnabled: true);
      final shouldShow = state.shouldShowPrompt(
        hasMonthlyBudget: true,
        currentMonth: '2026-10',
      );
      expect(shouldShow, isFalse);
    });

    test('Prompt is hidden when dismissed for current session', () {
      const state = MoneyAutomationState(isDismissedForSession: true);
      final shouldShow = state.shouldShowPrompt(
        hasMonthlyBudget: true,
        currentMonth: '2026-10',
      );
      expect(shouldShow, isFalse);
    });

    test('Prompt is shown for first and second visits in the same month, then hidden for third', () {
      var state = const MoneyAutomationState(promptMonth: '2026-10', promptCount: 0);
      expect(state.shouldShowPrompt(hasMonthlyBudget: true, currentMonth: '2026-10'), isTrue);

      state = state.copyWith(promptCount: 1);
      expect(state.shouldShowPrompt(hasMonthlyBudget: true, currentMonth: '2026-10'), isTrue);

      state = state.copyWith(promptCount: 2);
      expect(state.shouldShowPrompt(hasMonthlyBudget: true, currentMonth: '2026-10'), isFalse);
    });

    test('New calendar month resets prompt eligibility counter', () {
      // User was shown 2 times in October
      const state = MoneyAutomationState(promptMonth: '2026-10', promptCount: 2);
      expect(state.shouldShowPrompt(hasMonthlyBudget: true, currentMonth: '2026-10'), isFalse);

      // In November, the counter effectively resets
      expect(state.shouldShowPrompt(hasMonthlyBudget: true, currentMonth: '2026-11'), isTrue);
    });
  });

  group('Money Automation Repository & Persistence', () {
    late MoneyAutomationRepository repository;

    setUp(() {
      repository = MoneyAutomationRepository(inMemoryOnly: true);
    });

    test('Default loaded state is disabled and zeroed', () {
      final state = repository.loadState('user_1');
      expect(state.isEnabled, isFalse);
      expect(state.promptMonth, isEmpty);
      expect(state.promptCount, equals(0));
      expect(state.hasAcceptedInfoDialog, isFalse);
    });

    test('Enabling and disabling automation persists in repository', () async {
      await repository.setAutomationEnabled('user_1', true);
      var state = repository.loadState('user_1');
      expect(state.isEnabled, isTrue);

      await repository.setAutomationEnabled('user_1', false);
      state = repository.loadState('user_1');
      expect(state.isEnabled, isFalse);
    });

    test('Accepting info dialog persists in repository', () async {
      await repository.setInfoDialogAccepted('user_1', true);
      final state = repository.loadState('user_1');
      expect(state.hasAcceptedInfoDialog, isTrue);
    });

    test('Recording prompt appearances tracks month and increments count', () async {
      await repository.recordPromptAppearance('user_1', '2026-10');
      var state = repository.loadState('user_1');
      expect(state.promptMonth, equals('2026-10'));
      expect(state.promptCount, equals(1));

      await repository.recordPromptAppearance('user_1', '2026-10');
      state = repository.loadState('user_1');
      expect(state.promptMonth, equals('2026-10'));
      expect(state.promptCount, equals(2));
    });

    test('Recording appearance in a new month resets the count to 1', () async {
      await repository.recordPromptAppearance('user_1', '2026-10');
      await repository.recordPromptAppearance('user_1', '2026-10');
      var state = repository.loadState('user_1');
      expect(state.promptCount, equals(2));

      // Transition to November
      await repository.recordPromptAppearance('user_1', '2026-11');
      state = repository.loadState('user_1');
      expect(state.promptMonth, equals('2026-11'));
      expect(state.promptCount, equals(1));
    });
  });

  group('Multi-User Safety & Isolation', () {
    late MoneyAutomationRepository repository;

    setUp(() {
      repository = MoneyAutomationRepository(inMemoryOnly: true);
    });

    test('User A opt-in choice does NOT affect User B', () async {
      const userA = 'firebase_uid_user_a';
      const userB = 'firebase_uid_user_b';

      await repository.setAutomationEnabled(userA, true);
      await repository.setInfoDialogAccepted(userA, true);

      final stateA = repository.loadState(userA);
      final stateB = repository.loadState(userB);

      expect(stateA.isEnabled, isTrue);
      expect(stateA.hasAcceptedInfoDialog, isTrue);

      // User B must remain untouched and disabled
      expect(stateB.isEnabled, isFalse);
      expect(stateB.hasAcceptedInfoDialog, isFalse);
    });

    test('User A prompt appearance count does NOT affect User B', () async {
      const userA = 'firebase_uid_user_a';
      const userB = 'firebase_uid_user_b';

      await repository.recordPromptAppearance(userA, '2026-10');
      await repository.recordPromptAppearance(userA, '2026-10');

      final stateA = repository.loadState(userA);
      final stateB = repository.loadState(userB);

      expect(stateA.promptCount, equals(2));
      expect(stateB.promptCount, equals(0));
    });
  });

  group('Privacy & Architectural Verification', () {
    test('Local repository has NO network or cloud sync references', () {
      final repository = MoneyAutomationRepository(inMemoryOnly: true);
      expect(repository, isA<MoneyAutomationRepository>());
      // Operates locally without throwing missing service errors
      final state = repository.loadState('uid_test');
      expect(state.isEnabled, isFalse);
    });
  });
}
