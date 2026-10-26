import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:arc/core/notifications/notification_controller.dart';
import 'package:arc/core/notifications/notification_models.dart';
import 'package:arc/core/theme/app_theme.dart';

/// Shows the coordinator's expected/pending notification state.
/// This is not a delivery history because Flutter has no reliable,
/// cross-platform delivery receipt for local notifications.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(notificationControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Scheduled Reminders')),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(notificationControllerProvider.notifier)
            .refreshPermissionState(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HealthCard(health: health),
            const SizedBox(height: 16),
            if (health.desiredNotifications.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No reminders are currently expected.')),
              )
            else
              ...health.desiredNotifications.map(
                (spec) => _NotificationTile(spec: spec),
              ),
          ],
        ),
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  final NotificationHealth health;

  const _HealthCard({required this.health});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notification health',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Permission: ${health.permission.name}'),
            Text('Timezone: ${health.timezone}'),
            Text('Expected: ${health.desiredCount}  Pending: ${health.pendingCount}'),
            if (health.lastReason != null) Text('Last sync: ${health.lastReason}'),
            if (health.lastError != null)
              Text(health.lastError!,
                  style: const TextStyle(color: AppColors.danger)),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final ArcNotificationSpec spec;

  const _NotificationTile({required this.spec});

  @override
  Widget build(BuildContext context) {
    final icon = switch (spec.type) {
      ArcNotificationType.taskReminder => LucideIcons.clock,
      ArcNotificationType.taskDeadline => LucideIcons.checkSquare,
      ArcNotificationType.habitReminder => LucideIcons.zap,
      ArcNotificationType.habitPending => LucideIcons.zap,
      ArcNotificationType.habitEveningCheckIn => LucideIcons.bell,
      ArcNotificationType.moneyDaily => LucideIcons.wallet,
      ArcNotificationType.feedbackAcknowledged => LucideIcons.messageSquare,
    };
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(spec.title),
        subtitle: Text(
          '${spec.body}\n${spec.scheduledAt} (${spec.recurrence.name})',
        ),
        isThreeLine: true,
      ),
    );
  }
}
