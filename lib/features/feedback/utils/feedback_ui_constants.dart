import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';

/// Presentation metadata for feedback categories.
class FeedbackCategoryInfo {
  final String category;
  final String title;
  final String description;
  final IconData icon;
  final Color darkColor;
  final Color lightColor;

  const FeedbackCategoryInfo({
    required this.category,
    required this.title,
    required this.description,
    required this.icon,
    required this.darkColor,
    required this.lightColor,
  });

  Color getColor(bool isDark) => isDark ? darkColor : lightColor;

  static const List<FeedbackCategoryInfo> categories = [
    FeedbackCategoryInfo(
      category: FeedbackCategory.bugReport,
      title: 'Report a Bug',
      description: 'Encountered an unexpected glitch or error? Help us fix it with details.',
      icon: LucideIcons.bug,
      darkColor: AppColors.danger,
      lightColor: Color(0xFFDC2626),
    ),
    FeedbackCategoryInfo(
      category: FeedbackCategory.featureRequest,
      title: 'Suggest a Feature',
      description: 'Have an idea to make Arc more productive? Share your vision.',
      icon: LucideIcons.sparkles,
      darkColor: AppColors.accent,
      lightColor: AppColors.darkAccent,
    ),
    FeedbackCategoryInfo(
      category: FeedbackCategory.generalFeedback,
      title: 'General Feedback',
      description: 'Share your overall thoughts, workflow experience, or questions.',
      icon: LucideIcons.messageSquare,
      darkColor: AppColors.info,
      lightColor: Color(0xFF2563EB),
    ),
    FeedbackCategoryInfo(
      category: FeedbackCategory.appRating,
      title: 'Rate Arc',
      description: 'How is your experience with Arc? Leave a score and review.',
      icon: LucideIcons.star,
      darkColor: Color(0xFFFFC857),
      lightColor: Color(0xFFD97706),
    ),
  ];

  static FeedbackCategoryInfo forCategory(String category) {
    return categories.firstWhere(
      (c) => c.category == category,
      orElse: () => categories[2], // default to general
    );
  }
}

/// Supported app modules with icons and human-readable names.
class FeedbackModuleInfo {
  final String key;
  final String label;
  final IconData icon;

  const FeedbackModuleInfo({
    required this.key,
    required this.label,
    required this.icon,
  });

  static const List<FeedbackModuleInfo> modules = [
    FeedbackModuleInfo(key: 'task_manager', label: 'Task Manager', icon: LucideIcons.checkSquare),
    FeedbackModuleInfo(key: 'habit_tracker', label: 'Habit Tracker', icon: LucideIcons.repeat),
    FeedbackModuleInfo(key: 'money_tracker', label: 'Money Tracker', icon: LucideIcons.dollarSign),
    FeedbackModuleInfo(key: 'secret_notes', label: 'Secret Notes', icon: LucideIcons.lock),
    FeedbackModuleInfo(key: 'dashboard', label: 'Dashboard', icon: LucideIcons.layoutDashboard),
    FeedbackModuleInfo(key: 'notifications', label: 'Notifications', icon: LucideIcons.bell),
    FeedbackModuleInfo(key: 'settings', label: 'Settings & Sync', icon: LucideIcons.settings),
    FeedbackModuleInfo(key: 'general', label: 'General / Other', icon: LucideIcons.globe),
  ];

  static FeedbackModuleInfo forModule(String moduleKey) {
    return modules.firstWhere(
      (m) => m.key == moduleKey,
      orElse: () => modules.last,
    );
  }
}
