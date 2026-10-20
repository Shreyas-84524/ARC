import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:arc/features/money_tracker/models/money_automation_listener_status.dart';
import 'package:arc/features/money_tracker/models/money_automation_raw_event.dart';
import 'package:arc/features/money_tracker/models/money_automation_state.dart';
import 'package:arc/features/money_tracker/models/parsed_money_transaction.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/repository/money_automation_repository.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/features/money_tracker/services/money_automation_listener_service.dart';
import 'package:arc/features/money_tracker/services/money_automation_platform_bridge.dart';
import 'package:arc/features/money_tracker/services/money_deduplication_service.dart';
import 'package:arc/features/money_tracker/services/money_transaction_parser.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/providers/global_providers.dart';

final moneyAutomationRepositoryProvider = Provider<MoneyAutomationRepository>((ref) {
  return MoneyAutomationRepository();
});

final moneyAutomationPlatformBridgeProvider = Provider<MoneyAutomationPlatformBridge>((ref) {
  return MethodChannelMoneyAutomationBridge();
});

final moneyAutomationListenerServiceProvider = Provider<MoneyAutomationListenerService>((ref) {
  final bridge = ref.watch(moneyAutomationPlatformBridgeProvider);
  final service = MoneyAutomationListenerService(bridge: bridge);
  ref.onDispose(() => service.dispose());
  return service;
});

final moneyTransactionParserProvider = Provider<MoneyTransactionParser>((ref) {
  return MoneyTransactionParser();
});

final moneyDeduplicationServiceProvider = Provider<MoneyDeduplicationService>((ref) {
  return MoneyDeduplicationService();
});

final moneyAutomationProvider =
    StateNotifierProvider<MoneyAutomationNotifier, MoneyAutomationState>((ref) {
  final repo = ref.watch(moneyAutomationRepositoryProvider);
  final listenerService = ref.watch(moneyAutomationListenerServiceProvider);
  final parser = ref.watch(moneyTransactionParserProvider);
  final deduplicationService = ref.watch(moneyDeduplicationServiceProvider);
  MoneyRepository? moneyRepo;
  try {
    moneyRepo = ref.watch(moneyRepositoryProvider);
  } catch (_) {
    moneyRepo = null;
  }
  final userContext = ref.watch(userContextProvider);
  final userId = userContext.userId;
  return MoneyAutomationNotifier(
    repo,
    userId,
    listenerService: listenerService,
    parser: parser,
    deduplicationService: deduplicationService,
    moneyRepository: moneyRepo,
    onTransactionCreated: (tx) {
      try {
        ref.read(moneyProvider.notifier).refresh();
      } catch (_) {}
    },
  );
});

class MoneyAutomationNotifier extends StateNotifier<MoneyAutomationState> with WidgetsBindingObserver {
  final MoneyAutomationRepository _repository;
  final String? _userId;
  final MoneyAutomationListenerService _listenerService;
  final MoneyTransactionParser _parser;
  final MoneyDeduplicationService _deduplicationService;
  final MoneyRepository? _moneyRepository;
  final void Function(Transaction tx)? _onTransactionCreated;

  final StreamController<MoneyAutomationRawEvent> _eventController =
      StreamController<MoneyAutomationRawEvent>.broadcast();
  final StreamController<ParsedMoneyTransaction> _acceptedCandidateController =
      StreamController<ParsedMoneyTransaction>.broadcast();

  bool _hasRecordedThisVisit = false;

  MoneyAutomationNotifier(
    this._repository,
    this._userId, {
    MoneyAutomationListenerService? listenerService,
    MoneyTransactionParser? parser,
    MoneyDeduplicationService? deduplicationService,
    MoneyRepository? moneyRepository,
    void Function(Transaction tx)? onTransactionCreated,
  })  : _listenerService = listenerService ?? MoneyAutomationListenerService(),
        _parser = parser ?? MoneyTransactionParser(),
        _deduplicationService = deduplicationService ?? MoneyDeduplicationService(),
        _moneyRepository = moneyRepository,
        _onTransactionCreated = onTransactionCreated,
        super(const MoneyAutomationState()) {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
    _deduplicationService.initForUser(_userId);
    _loadState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && this.state.isEnabled) {
      checkListenerHealth();
    }
  }

  /// In-memory stream of raw events captured during active sessions.
  Stream<MoneyAutomationRawEvent> get eventStream => _eventController.stream;

  /// Internal candidate stream of parsed, high-confidence confirmed debit transactions.
  Stream<ParsedMoneyTransaction> get acceptedCandidateStream =>
      _acceptedCandidateController.stream;

  void _loadState() {
    final loaded = _repository.loadState(_userId);
    state = loaded;

    // Startup behavior: If automation is ON, verify permission and resume listener.
    // If automation is OFF, ensure listener is stopped and marked disabled.
    if (loaded.isEnabled) {
      checkListenerHealth();
    } else {
      _listenerService.stopListening();
      state = state.copyWith(listenerStatus: MoneyAutomationListenerStatus.disabled);
    }
  }

  /// Checks the local Android permission and listener health.
  /// Detects external permission revocations from system settings.
  Future<void> checkListenerHealth() async {
    if (!state.isEnabled || _userId == null) {
      await _listenerService.stopListening();
      if (state.listenerStatus != MoneyAutomationListenerStatus.disabled) {
        state = state.copyWith(listenerStatus: MoneyAutomationListenerStatus.disabled);
      }
      return;
    }

    final status = await _listenerService.checkHealth(isEnabled: state.isEnabled);
    if (status == MoneyAutomationListenerStatus.ready) {
      await _listenerService.startListening(onEvent: _onRawEventReceived);
    }
    state = state.copyWith(listenerStatus: status);
  }

  void _onRawEventReceived(MoneyAutomationRawEvent event) {
    // Multi-user safety & Opt-In enforcement:
    // Drop incoming events if the user logged out or disabled tracking.
    if (_userId == null || _userId.isEmpty || !state.isEnabled) {
      return;
    }
    _eventController.add(event);
    _processIncomingRawEvent(event);
  }

  Future<void> _processIncomingRawEvent(MoneyAutomationRawEvent event) async {
    try {
      final parsed = _parser.parse(event);
      if (parsed.isConfirmedDebit) {
        // Re-check enabled state before processing
        if (!state.isEnabled || _userId == null || _userId.isEmpty) {
          return;
        }

        // 1. Check duplicate
        if (_deduplicationService.isDuplicate(parsed.fingerprint, referenceId: parsed.referenceId)) {
          final shortFp = parsed.fingerprint.length > 8 ? '${parsed.fingerprint.substring(0, 8)}...' : parsed.fingerprint;
          debugPrint('[MoneyAutomation] Duplicate transaction rejected (fp: $shortFp)');
          return;
        }

        // 2. Prepare Transaction
        final description = _formatDescription(parsed);
        final tx = Transaction(
          id: const Uuid().v4(),
          amount: parsed.amount,
          type: 'Expense',
          category: 'Uncategorized',
          date: parsed.transactionDateTime,
          time: DateFormat('HH:mm').format(parsed.transactionDateTime),
          notes: description,
          createdAt: DateTime.now(),
          source: 'sms_auto',
          automationFingerprint: parsed.fingerprint,
        );

        // 3. Attempt Money Manager save
        if (_moneyRepository != null) {
          await _moneyRepository.saveTransaction(tx);
        }

        // 4. ONLY AFTER successful creation, finalize the fingerprint as processed
        await _deduplicationService.recordProcessed(parsed.fingerprint, referenceId: parsed.referenceId);
        _acceptedCandidateController.add(parsed);
        _onTransactionCreated?.call(tx);
        debugPrint('[MoneyAutomation] Auto-created expense: ₹${parsed.amount} (${parsed.fingerprint.substring(0, 8)}...)');
      } else {
        debugPrint('[MoneyAutomation] Event classified as ${parsed.classification.name}, rejected from auto-entry');
      }
    } catch (e) {
      debugPrint('[MoneyAutomation] Safe parsing / auto-creation failure caught: $e');
    }
  }

  String _formatDescription(ParsedMoneyTransaction parsed) {
    final rawDesc = parsed.merchantOrDescription?.trim();
    if (rawDesc != null && rawDesc.isNotEmpty) {
      if (rawDesc.toLowerCase().contains('atm')) {
        return 'ATM withdrawal';
      }
      if (rawDesc.toLowerCase().startsWith('paid to ')) {
        return rawDesc;
      }
      return 'Paid to $rawDesc';
    }
    return 'Automatic expense';
  }

  /// Records an actual appearance of the prompt during the current visit.
  Future<void> markPromptShown(String currentMonth) async {
    if (_hasRecordedThisVisit) return;
    _hasRecordedThisVisit = true;

    await _repository.recordPromptAppearance(_userId, currentMonth);

    final storedMonth = state.promptMonth;
    final storedCount = state.promptCount;
    final int newCount = (storedMonth == currentMonth) ? storedCount + 1 : 1;

    state = state.copyWith(
      promptMonth: currentMonth,
      promptCount: newCount,
      isPromptActiveThisVisit: true,
    );
  }

  /// Tapping "No" on the prompt keeps automation disabled and dismisses
  /// the prompt for the remainder of this session/visit.
  void dismissPromptForSession() {
    state = state.copyWith(
      isEnabled: false,
      isDismissedForSession: true,
      isPromptActiveThisVisit: false,
    );
  }

  /// Explicit opt-in flow: requests permission, starts listener on grant,
  /// and updates status to ready (or permissionRequired if denied).
  Future<bool> enableAutomation() async {
    await _repository.setInfoDialogAccepted(_userId, true);

    if (!_listenerService.bridge.isPlatformSupported) {
      await _repository.setAutomationEnabled(_userId, true);
      state = state.copyWith(
        isEnabled: true,
        hasAcceptedInfoDialog: true,
        isPromptActiveThisVisit: false,
        listenerStatus: MoneyAutomationListenerStatus.unavailable,
      );
      return false;
    }

    final permResult = await _listenerService.bridge.requestPermission();
    if (permResult == 'granted') {
      await _repository.setAutomationEnabled(_userId, true);
      await _listenerService.startListening(onEvent: _onRawEventReceived);
      state = state.copyWith(
        isEnabled: true,
        hasAcceptedInfoDialog: true,
        isPromptActiveThisVisit: false,
        listenerStatus: MoneyAutomationListenerStatus.ready,
      );
      return true;
    } else {
      await _repository.setAutomationEnabled(_userId, true);
      state = state.copyWith(
        isEnabled: true,
        hasAcceptedInfoDialog: true,
        isPromptActiveThisVisit: false,
        listenerStatus: MoneyAutomationListenerStatus.permissionRequired,
      );
      return false;
    }
  }

  /// Toggling OFF reverts automation to disabled and immediately stops listener.
  Future<void> disableAutomation() async {
    await _repository.setAutomationEnabled(_userId, false);
    await _listenerService.stopListening();
    state = state.copyWith(
      isEnabled: false,
      listenerStatus: MoneyAutomationListenerStatus.disabled,
    );
  }

  /// Direct toggle control.
  Future<void> setAutomation(bool enabled) async {
    if (enabled) {
      await enableAutomation();
    } else {
      await disableAutomation();
    }
  }

  /// Re-triggers permission request when in [permissionRequired] state.
  Future<void> requestPermissionAgain() async {
    final result = await _listenerService.bridge.requestPermission();
    if (result == 'granted') {
      await _listenerService.startListening(onEvent: _onRawEventReceived);
      state = state.copyWith(listenerStatus: MoneyAutomationListenerStatus.ready);
    } else if (result == 'permanentlyDenied') {
      await _listenerService.bridge.openAppSettings();
    } else {
      state = state.copyWith(listenerStatus: MoneyAutomationListenerStatus.permissionRequired);
    }
  }

  /// Resets session-specific dismissal and appearance flags for a new screen visit.
  void resetVisitState() {
    _hasRecordedThisVisit = false;
    state = state.copyWith(
      isDismissedForSession: false,
      isPromptActiveThisVisit: false,
    );
  }

  /// Handles user logout: immediately stops listener processing, resets state, and clears cache.
  Future<void> onLogout() async {
    await _listenerService.stopListening();
    _deduplicationService.clear();
    state = const MoneyAutomationState(listenerStatus: MoneyAutomationListenerStatus.disabled);
  }

  @override
  void dispose() {
    if (!mounted) return;
    try {
      WidgetsBinding.instance.removeObserver(this);
    } catch (_) {}
    _listenerService.stopListening();
    _eventController.close();
    _acceptedCandidateController.close();
    super.dispose();
  }
}
