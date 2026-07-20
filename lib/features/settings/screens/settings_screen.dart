import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/providers/global_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // We get theme state from Riverpod
    final isDarkModeActive = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Theme Settings Card
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.moon, color: AppColors.accent),
                  title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Switch(
                    value: isDarkModeActive,
                    activeColor: AppColors.accent,
                    onChanged: (value) {
                      ref.read(themeModeProvider.notifier).state =
                          value ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),

          // Notification Settings Card
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.bell, color: AppColors.info),
                  title: const Text('Local Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Toggle reminders for tasks, habits, and money'),
                  trailing: Switch(
                    value: true,
                    activeColor: AppColors.accent,
                    onChanged: (value) {},
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(LucideIcons.clock, color: AppColors.info),
                  title: const Text('Evening Habit Check-in', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Remind daily at 8:00 PM'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 16),
                  onTap: () {},
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(LucideIcons.dollarSign, color: AppColors.info),
                  title: const Text('Expense Tracker Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Remind daily at 10:00 PM'),
                  trailing: const Icon(LucideIcons.chevronRight, size: 16),
                  onTap: () {},
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Synchronization Card
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.cloudLightning, color: AppColors.success),
                  title: const Text('Cloud Firestore Synchronization', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Synchronized • 2 minutes ago'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Online',
                      style: TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(LucideIcons.database, color: AppColors.warning),
                  title: const Text('Local Database Cache (Hive)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('12 KB Cached data'),
                  trailing: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hive cache cleared (placeholder)')),
                      );
                    },
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // About / Legal Section
          Center(
            child: Column(
              children: [
                Text(
                  'Project Arc',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0 (Production-grade)',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
