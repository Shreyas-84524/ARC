import 'package:flutter/foundation.dart';

@immutable
class SettingsModel {
  final String userDisplayName;
  final bool isDarkMode;
  final bool masterNotificationsEnabled;
  final bool taskRemindersEnabled;
  final bool habitRemindersEnabled;
  final bool moneyRemindersEnabled;
  final String eveningCheckinTime;
  final String expenseReminderTime;
  final String remTime;
  final DateTime? lastSyncTime;

  const SettingsModel({
    required this.userDisplayName,
    required this.isDarkMode,
    this.masterNotificationsEnabled = true,
    required this.taskRemindersEnabled,
    required this.habitRemindersEnabled,
    required this.moneyRemindersEnabled,
    required this.eveningCheckinTime,
    required this.expenseReminderTime,
    this.remTime = '21:00',
    this.lastSyncTime,
  });

  factory SettingsModel.defaultSettings() {
    return const SettingsModel(
      userDisplayName: 'User',
      isDarkMode: true,
      masterNotificationsEnabled: true,
      taskRemindersEnabled: true,
      habitRemindersEnabled: true,
      moneyRemindersEnabled: true,
      eveningCheckinTime: '20:00',
      expenseReminderTime: '22:00',
      remTime: '21:00',
      lastSyncTime: null,
    );
  }

  SettingsModel copyWith({
    String? userDisplayName,
    bool? isDarkMode,
    bool? masterNotificationsEnabled,
    bool? taskRemindersEnabled,
    bool? habitRemindersEnabled,
    bool? moneyRemindersEnabled,
    String? eveningCheckinTime,
    String? expenseReminderTime,
    String? remTime,
    DateTime? lastSyncTime,
  }) {
    return SettingsModel(
      userDisplayName: userDisplayName ?? this.userDisplayName,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      masterNotificationsEnabled:
          masterNotificationsEnabled ?? this.masterNotificationsEnabled,
      taskRemindersEnabled: taskRemindersEnabled ?? this.taskRemindersEnabled,
      habitRemindersEnabled: habitRemindersEnabled ?? this.habitRemindersEnabled,
      moneyRemindersEnabled: moneyRemindersEnabled ?? this.moneyRemindersEnabled,
      eveningCheckinTime: eveningCheckinTime ?? this.eveningCheckinTime,
      expenseReminderTime: expenseReminderTime ?? this.expenseReminderTime,
      remTime: remTime ?? this.remTime,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userDisplayName': userDisplayName,
      'isDarkMode': isDarkMode,
      'masterNotificationsEnabled': masterNotificationsEnabled,
      'taskRemindersEnabled': taskRemindersEnabled,
      'habitRemindersEnabled': habitRemindersEnabled,
      'moneyRemindersEnabled': moneyRemindersEnabled,
      'eveningCheckinTime': eveningCheckinTime,
      'expenseReminderTime': expenseReminderTime,
      'rem_time': remTime,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
    };
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      userDisplayName: map['userDisplayName'] ?? 'User',
      isDarkMode: map['isDarkMode'] ?? true,
      masterNotificationsEnabled: map['masterNotificationsEnabled'] ?? true,
      taskRemindersEnabled: map['taskRemindersEnabled'] ?? true,
      habitRemindersEnabled: map['habitRemindersEnabled'] ?? true,
      moneyRemindersEnabled: map['moneyRemindersEnabled'] ?? true,
      eveningCheckinTime: map['eveningCheckinTime'] ?? '20:00',
      expenseReminderTime: map['expenseReminderTime'] ?? '22:00',
      remTime: map['rem_time'] ?? map['eveningCheckinTime'] ?? '21:00',
      lastSyncTime: map['lastSyncTime'] != null
          ? DateTime.parse(map['lastSyncTime'])
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SettingsModel &&
        other.userDisplayName == userDisplayName &&
        other.isDarkMode == isDarkMode &&
        other.masterNotificationsEnabled == masterNotificationsEnabled &&
        other.taskRemindersEnabled == taskRemindersEnabled &&
        other.habitRemindersEnabled == habitRemindersEnabled &&
        other.moneyRemindersEnabled == moneyRemindersEnabled &&
        other.eveningCheckinTime == eveningCheckinTime &&
        other.expenseReminderTime == expenseReminderTime &&
        other.remTime == remTime &&
        other.lastSyncTime == lastSyncTime;
  }

  @override
  int get hashCode {
    return Object.hash(
      userDisplayName,
      isDarkMode,
      masterNotificationsEnabled,
      taskRemindersEnabled,
      habitRemindersEnabled,
      moneyRemindersEnabled,
      eveningCheckinTime,
      expenseReminderTime,
      remTime,
      lastSyncTime,
    );
  }
}
