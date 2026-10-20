class GreetingUtils {
  /// Returns time-of-day greeting:
  /// - Morning (5:00 - 11:59) -> "Good Morning"
  /// - Afternoon (12:00 - 16:59) -> "Good Afternoon"
  /// - Evening (17:00 - 20:59) -> "Good Evening"
  /// - Night (21:00 - 4:59) -> "Good Night"
  static String getGreeting(DateTime dateTime) {
    final hour = dateTime.hour;
    if (hour < 5 || hour >= 21) {
      return "Good Night";
    } else if (hour < 12) {
      return "Good Morning";
    } else if (hour < 17) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  /// Returns header title for TopBar.
  /// When title is 'Dashboard', computes dynamic greeting with username if available.
  /// If username is null or empty, falls back to neutral time-based greeting (e.g. "Good Morning").
  static String getGreetingTitle({
    required String title,
    required String? username,
    DateTime? now,
  }) {
    if (title != 'Dashboard') {
      return title;
    }

    final greeting = getGreeting(now ?? DateTime.now());
    if (username != null && username.trim().isNotEmpty) {
      return '$greeting, ${username.trim()}';
    }
    return greeting;
  }
}
