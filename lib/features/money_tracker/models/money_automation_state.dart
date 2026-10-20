import 'package:arc/features/money_tracker/models/money_automation_listener_status.dart';

class MoneyAutomationState {
  final bool isEnabled;
  final String promptMonth;
  final int promptCount;
  final bool hasAcceptedInfoDialog;
  final bool isDismissedForSession;
  final bool isPromptActiveThisVisit;
  final MoneyAutomationListenerStatus listenerStatus;

  const MoneyAutomationState({
    this.isEnabled = false,
    this.promptMonth = '',
    this.promptCount = 0,
    this.hasAcceptedInfoDialog = false,
    this.isDismissedForSession = false,
    this.isPromptActiveThisVisit = false,
    this.listenerStatus = MoneyAutomationListenerStatus.disabled,
  });

  /// Evaluates whether the automatic spending prompt should be presented to the user.
  ///
  /// Rules:
  /// 1. Must have a configured monthly budget for the current month.
  /// 2. Automation must currently be disabled.
  /// 3. Must not have been dismissed in the current session.
  /// 4. Maximum 2 appearances per calendar month.
  bool shouldShowPrompt({
    required bool hasMonthlyBudget,
    required String currentMonth,
  }) {
    if (!hasMonthlyBudget) return false;
    if (isEnabled) return false;
    if (isDismissedForSession) return false;

    if (isPromptActiveThisVisit) return true;

    final effectiveCount = (promptMonth == currentMonth) ? promptCount : 0;
    return effectiveCount < 2;
  }

  MoneyAutomationState copyWith({
    bool? isEnabled,
    String? promptMonth,
    int? promptCount,
    bool? hasAcceptedInfoDialog,
    bool? isDismissedForSession,
    bool? isPromptActiveThisVisit,
    MoneyAutomationListenerStatus? listenerStatus,
  }) {
    return MoneyAutomationState(
      isEnabled: isEnabled ?? this.isEnabled,
      promptMonth: promptMonth ?? this.promptMonth,
      promptCount: promptCount ?? this.promptCount,
      hasAcceptedInfoDialog: hasAcceptedInfoDialog ?? this.hasAcceptedInfoDialog,
      isDismissedForSession: isDismissedForSession ?? this.isDismissedForSession,
      isPromptActiveThisVisit:
          isPromptActiveThisVisit ?? this.isPromptActiveThisVisit,
      listenerStatus: listenerStatus ?? this.listenerStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoneyAutomationState &&
          runtimeType == other.runtimeType &&
          isEnabled == other.isEnabled &&
          promptMonth == other.promptMonth &&
          promptCount == other.promptCount &&
          hasAcceptedInfoDialog == other.hasAcceptedInfoDialog &&
          isDismissedForSession == other.isDismissedForSession &&
          isPromptActiveThisVisit == other.isPromptActiveThisVisit &&
          listenerStatus == other.listenerStatus;

  @override
  int get hashCode => Object.hash(
        isEnabled,
        promptMonth,
        promptCount,
        hasAcceptedInfoDialog,
        isDismissedForSession,
        isPromptActiveThisVisit,
        listenerStatus,
      );
}
