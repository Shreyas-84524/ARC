import 'package:shared_preferences/shared_preferences.dart';

/// App-level login rate limiter for Project Arc.
///
/// Limits unauthenticated Email + Password login attempts to 10 attempts
/// per 6-hour sliding window. Survives app restarts by persisting timestamps
/// and attempt counts to SharedPreferences.
class LoginRateLimiter {
  static const int maxAttempts = 10;
  static const Duration windowDuration = Duration(hours: 6);

  static const String keyWindowStart = 'arc_auth_throttle_window_start_ms';
  static const String keyAttempts = 'arc_auth_throttle_attempts';
  static const String keyLockedUntil = 'arc_auth_throttle_locked_until_ms';

  final SharedPreferences? _prefs;
  final DateTime Function() _clock;

  LoginRateLimiter({
    SharedPreferences? prefs,
    DateTime Function()? clock,
  })  : _prefs = prefs,
        _clock = clock ?? DateTime.now;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Checks if password login is currently throttled/locked.
  Future<bool> isLocked() async {
    final prefs = await _getPrefs();
    final now = _clock();

    final windowStartMs = prefs.getInt(keyWindowStart);
    if (windowStartMs == null) return false;

    final windowStart = DateTime.fromMillisecondsSinceEpoch(windowStartMs);

    // If 6 hours have passed since the window started, automatically reset
    if (now.difference(windowStart) >= windowDuration) {
      await reset();
      return false;
    }

    final lockedUntilMs = prefs.getInt(keyLockedUntil);
    if (lockedUntilMs != null) {
      final lockedUntil = DateTime.fromMillisecondsSinceEpoch(lockedUntilMs);
      if (now.isBefore(lockedUntil)) {
        return true;
      } else {
        await reset();
        return false;
      }
    }

    final attempts = prefs.getInt(keyAttempts) ?? 0;
    if (attempts >= maxAttempts) {
      final lockEnd = windowStart.add(windowDuration);
      if (now.isBefore(lockEnd)) {
        await prefs.setInt(keyLockedUntil, lockEnd.millisecondsSinceEpoch);
        return true;
      } else {
        await reset();
        return false;
      }
    }

    return false;
  }

  /// Returns the remaining duration of the lock window, or Duration.zero if not locked.
  Future<Duration> getRemainingLockDuration() async {
    final prefs = await _getPrefs();
    final now = _clock();

    final lockedUntilMs = prefs.getInt(keyLockedUntil);
    if (lockedUntilMs != null) {
      final lockedUntil = DateTime.fromMillisecondsSinceEpoch(lockedUntilMs);
      if (lockedUntil.isAfter(now)) {
        return lockedUntil.difference(now);
      }
    }

    final windowStartMs = prefs.getInt(keyWindowStart);
    if (windowStartMs != null) {
      final windowStart = DateTime.fromMillisecondsSinceEpoch(windowStartMs);
      final lockEnd = windowStart.add(windowDuration);
      if (lockEnd.isAfter(now)) {
        final attempts = prefs.getInt(keyAttempts) ?? 0;
        if (attempts >= maxAttempts) {
          return lockEnd.difference(now);
        }
      }
    }

    return Duration.zero;
  }

  /// Formats duration into a concise, human-readable string (e.g. "2h 14m", "45m", "1m").
  static String formatRemaining(Duration duration) {
    if (duration <= Duration.zero) return 'a few moments';
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '1m';
    }
  }

  /// Formats the official user-facing throttle message.
  static String getThrottledMessage(Duration remaining) {
    final formattedDuration = formatRemaining(remaining);
    return 'Too many login attempts. For security and reliability, ARC allows up to 10 password login attempts every 6 hours. Try again in $formattedDuration.';
  }

  /// Records an actual submitted password login attempt to Firebase.
  /// Returns the new attempt count.
  Future<int> recordAttempt() async {
    final prefs = await _getPrefs();
    final now = _clock();

    final windowStartMs = prefs.getInt(keyWindowStart);
    int attempts = prefs.getInt(keyAttempts) ?? 0;

    if (windowStartMs == null ||
        now.difference(DateTime.fromMillisecondsSinceEpoch(windowStartMs)) >= windowDuration) {
      // Start a fresh 6-hour window
      await prefs.setInt(keyWindowStart, now.millisecondsSinceEpoch);
      attempts = 1;
      await prefs.setInt(keyAttempts, attempts);
      await prefs.remove(keyLockedUntil);
    } else {
      attempts++;
      await prefs.setInt(keyAttempts, attempts);
      if (attempts >= maxAttempts) {
        final windowStart = DateTime.fromMillisecondsSinceEpoch(windowStartMs);
        final lockEnd = windowStart.add(windowDuration);
        await prefs.setInt(keyLockedUntil, lockEnd.millisecondsSinceEpoch);
      }
    }

    return attempts;
  }

  /// Resets the throttle state upon successful login or manual clear.
  Future<void> reset() async {
    final prefs = await _getPrefs();
    await prefs.remove(keyWindowStart);
    await prefs.remove(keyAttempts);
    await prefs.remove(keyLockedUntil);
  }

  /// Gets current attempt count in active window.
  Future<int> getAttempts() async {
    final prefs = await _getPrefs();
    final now = _clock();
    final windowStartMs = prefs.getInt(keyWindowStart);
    if (windowStartMs == null) return 0;
    if (now.difference(DateTime.fromMillisecondsSinceEpoch(windowStartMs)) >= windowDuration) {
      await reset();
      return 0;
    }
    return prefs.getInt(keyAttempts) ?? 0;
  }
}
