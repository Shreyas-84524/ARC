import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:arc/core/notifications/notification_controller.dart';
import 'package:arc/core/notifications/notification_models.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/providers/global_providers.dart';
import 'package:arc/routes/app_router.dart';
import 'package:arc/features/feedback/providers/feedback_providers.dart';

/// The single bridge between reactive application state and the centralized
/// notification controller. Feature providers never schedule notifications.
class NotificationOrchestrator extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationOrchestrator({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<NotificationOrchestrator> createState() =>
      _NotificationOrchestratorState();
}

class _NotificationOrchestratorState
    extends ConsumerState<NotificationOrchestrator>
    with WidgetsBindingObserver {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(notificationControllerProvider.notifier).initialize();
      _queueReconciliation('startup');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(notificationControllerProvider.notifier).refreshPermissionState();
      _queueReconciliation('app_resumed');
    }
  }

  void _queueReconciliation(String reason) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final user = ref.read(userContextProvider);
      final isAuthenticated = user.isAuthenticated && user.userId != null;
      final snapshot = NotificationSnapshot(
        userId: isAuthenticated ? user.userId : null,
        settings: ref.read(appSettingsProvider),
        tasks: isAuthenticated ? ref.read(tasksProvider) : const [],
        habits: isAuthenticated ? ref.read(habitsProvider) : const [],
        habitEntries:
            isAuthenticated ? ref.read(habitEntriesProvider) : const [],
        transactions: isAuthenticated ? ref.read(moneyProvider) : const [],
        now: DateTime.now(),
      );
      ref
          .read(notificationControllerProvider.notifier)
          .reconcile(snapshot, reason: reason);
    });
  }

  void _tryHandleNavigation(
    UserContext user,
    NotificationHealth health,
  ) {
    final intent = health.navigationIntent;
    if (intent == null || !user.isAuthenticated || user.isAdmin) return;
    if (!intent.isValidDestination) {
      ref.read(notificationControllerProvider.notifier).clearNavigationIntent();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Re-verify auth state and navigation intent before performing the navigation
      final currentUser = ref.read(userContextProvider);
      final currentHealth = ref.read(notificationControllerProvider);
      if (!currentUser.isAuthenticated ||
          currentUser.isAdmin ||
          currentHealth.navigationIntent == null) {
        return;
      }
      ref.read(routerProvider).go(intent.destination);
      ref
          .read(notificationControllerProvider.notifier)
          .clearNavigationIntent();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(userContextProvider, (previous, next) {
      final wasSwitch = previous?.userId != null &&
          next.userId != null &&
          previous!.userId != next.userId;
      final wasLogout =
          (previous?.isAuthenticated == true) && !next.isAuthenticated;

      if (wasSwitch || wasLogout) {
        if (!next.isAuthenticated) {
          ref.read(notificationControllerProvider.notifier).handleLogout();
        }
        ref.read(notificationControllerProvider.notifier).clearNavigationIntent();
        ref.read(routerProvider).go('/');
        _queueReconciliation('user_changed');
      } else if (previous?.userId != next.userId) {
        // Cold start auth resolution or login from unauthenticated state:
        // Preserve pending navigation intent and reconcile schedules for new user
        _queueReconciliation('user_changed');
      }
      _tryHandleNavigation(next, ref.read(notificationControllerProvider));
    });
    ref.listen(appSettingsProvider, (_, _) => _queueReconciliation('settings_changed'));
    ref.listen(tasksProvider, (_, _) => _queueReconciliation('tasks_changed'));
    ref.listen(habitsProvider, (_, _) => _queueReconciliation('habits_changed'));
    ref.listen(
      habitEntriesProvider,
      (_, _) => _queueReconciliation('habit_entries_changed'),
    );
    ref.listen(moneyProvider, (_, _) => _queueReconciliation('money_changed'));
    ref.listen(currentUserFeedbackStreamProvider, (_, asyncValue) {
      final user = ref.read(userContextProvider);
      if (user.isAuthenticated && user.userId != null) {
        asyncValue.whenData((feedbackList) {
          ref.read(feedbackAcknowledgementServiceProvider).processFeedbackList(
            userId: user.userId!,
            feedbackList: feedbackList,
          );
        });
      }
    });
    ref.listen(notificationControllerProvider, (_, next) {
      _tryHandleNavigation(ref.read(userContextProvider), next);
    });

    return widget.child;
  }
}
