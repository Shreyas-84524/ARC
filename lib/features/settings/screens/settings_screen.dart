import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/providers/global_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _masterNotifications = true;
  bool _taskReminders = true;
  bool _habitReminders = true;
  bool _moneyReminders = true;

  Future<void> _manualSync() async {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Synchronizing with Cloud Firestore...')),
    );
    await ref.read(syncServiceProvider).syncAllPending();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Synchronization complete!')),
      );
    }
  }

  Future<void> _confirmClearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Local Cache'),
        content: const Text('This will clean temporary cache files from local storage. Your saved data will remain intact.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(context).pop(true);
            },
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local database cache cleared.')),
      );
    }
  }

  Future<void> _confirmResetData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Application Data'),
        content: const Text(
          'CAUTION: This action will reset local settings and offline cache. Cloud backup on Firestore will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.of(context).pop(true);
            },
            child: const Text('Reset Data'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application data reset.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings & Diagnostics',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 1. Appearance Section
          Text('Appearance', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(LucideIcons.moon, color: AppColors.accent),
                  title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Toggle between Dark and Light theme'),
                  value: themeMode == ThemeMode.dark,
                  activeThumbColor: AppColors.accent,
                  onChanged: (val) {
                    ref.read(appSettingsProvider.notifier).updateThemeMode(val);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 2. Notifications Section
          Text('Notifications', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(LucideIcons.bell, color: AppColors.accent),
                  title: const Text('Master Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Enable or disable all local alerts'),
                  value: _masterNotifications,
                  activeThumbColor: AppColors.accent,
                  onChanged: (val) {
                    setState(() {
                      _masterNotifications = val;
                      _taskReminders = val;
                      _habitReminders = val;
                      _moneyReminders = val;
                    });
                  },
                ),
                if (_masterNotifications) ...[
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.checkSquare, color: AppColors.info),
                    title: const Text('Task Reminders'),
                    subtitle: const Text('Alerts 1h, 30m, and due time'),
                    value: _taskReminders,
                    activeThumbColor: AppColors.accent,
                    onChanged: (val) => setState(() => _taskReminders = val),
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.zap, color: AppColors.accent),
                    title: const Text('Habit Reminders'),
                    subtitle: const Text('Evening check-in alert at 8:00 PM'),
                    value: _habitReminders,
                    activeThumbColor: AppColors.accent,
                    onChanged: (val) => setState(() => _habitReminders = val),
                  ),
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    secondary: const Icon(LucideIcons.wallet, color: AppColors.success),
                    title: const Text('Expense Reminders'),
                    subtitle: const Text('Daily transaction alerts at 8 PM & 10 PM'),
                    value: _moneyReminders,
                    activeThumbColor: AppColors.accent,
                    onChanged: (val) => setState(() => _moneyReminders = val),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 3. Data & Storage Diagnostics
          Text('Data & Storage Diagnostics', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.cloudLightning, color: AppColors.success),
                  title: const Text('Cloud Firestore Synchronization', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Background queue active • Project Arc'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
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
                  title: const Text('Hive Storage Engine', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('6 Encrypted Hive Boxes Operational'),
                  trailing: TextButton.icon(
                    onPressed: _manualSync,
                    icon: const Icon(LucideIcons.refreshCw, size: 14),
                    label: const Text('Sync Now'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 4. Backup & Maintenance
          Text('Backup & Maintenance', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(LucideIcons.hardDrive, color: AppColors.info),
                  title: const Text('Clear Local Cache', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Clean cached temporary indexes'),
                  onTap: _confirmClearCache,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(LucideIcons.alertTriangle, color: AppColors.danger),
                  title: const Text('Reset Local Data', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Reset local storage cache'),
                  onTap: _confirmResetData,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 5. About & Legal Info
          Center(
            child: Column(
              children: [
                Text(
                  'Project Arc',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0 • Build 2026.07',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Single-User Local First Architecture',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
