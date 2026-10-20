// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// - NO Firestore collections for notes
// - NO sync queues
// - NO realtime listeners
// - NO Firebase repositories
// - NO uploading PINs or metadata
// - NO attachment to ARC cloud sync
// All storage and security verifiers remain strictly local on the device.

class SecretNotesSecurityState {
  final bool isConfigured;
  final bool hasSeenIntro;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final String? salt;
  final String? pinHash;
  final int iterations;

  const SecretNotesSecurityState({
    this.isConfigured = false,
    this.hasSeenIntro = false,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.salt,
    this.pinHash,
    this.iterations = 10000,
  });

  bool get isLockedOut {
    if (lockedUntil == null) return false;
    return DateTime.now().isBefore(lockedUntil!);
  }

  int get lockoutRemainingSeconds {
    if (lockedUntil == null) return 0;
    final now = DateTime.now();
    if (now.isAfter(lockedUntil!)) return 0;
    return lockedUntil!.difference(now).inSeconds + 1;
  }

  SecretNotesSecurityState copyWith({
    bool? isConfigured,
    bool? hasSeenIntro,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
    String? salt,
    String? pinHash,
    int? iterations,
  }) {
    return SecretNotesSecurityState(
      isConfigured: isConfigured ?? this.isConfigured,
      hasSeenIntro: hasSeenIntro ?? this.hasSeenIntro,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
      salt: salt ?? this.salt,
      pinHash: pinHash ?? this.pinHash,
      iterations: iterations ?? this.iterations,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'is_configured': isConfigured,
      'has_seen_intro': hasSeenIntro,
      'failed_attempts': failedAttempts,
      'locked_until_ms': lockedUntil?.millisecondsSinceEpoch,
      'pin_salt': salt,
      'pin_hash': pinHash,
      'iterations': iterations,
    };
  }

  factory SecretNotesSecurityState.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const SecretNotesSecurityState();
    final lockedUntilMs = map['locked_until_ms'] as int?;
    return SecretNotesSecurityState(
      isConfigured: map['is_configured'] as bool? ?? false,
      hasSeenIntro: map['has_seen_intro'] as bool? ?? false,
      failedAttempts: map['failed_attempts'] as int? ?? 0,
      lockedUntil: lockedUntilMs != null ? DateTime.fromMillisecondsSinceEpoch(lockedUntilMs) : null,
      salt: map['pin_salt'] as String?,
      pinHash: map['pin_hash'] as String?,
      iterations: map['iterations'] as int? ?? 10000,
    );
  }
}
