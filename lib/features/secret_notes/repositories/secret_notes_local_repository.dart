import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/secret_notes/models/secret_notes_security_state.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// - NO Firestore collections for notes
// - NO sync queues
// - NO realtime listeners
// - NO Firebase repositories
// - NO uploading PINs or metadata
// - NO attachment to ARC cloud sync
// All storage and security verifiers remain strictly local on the device.

class SecretNotesLocalRepository {
  static const String securityBoxName = 'secret_notes_security';
  static const String preferencesBoxName = 'secret_notes_preferences';
  static const String dataBoxName = 'secret_notes_data'; // Reserved for Phase 2/3 note storage

  Box<dynamic>? _securityBox;
  Box<dynamic>? _preferencesBox;

  // In-memory fallback if Hive is running in an environment without persistent boxes
  final Map<String, dynamic> _fallbackSecurityStore = {};
  final Map<String, dynamic> _fallbackPreferencesStore = {};

  final bool inMemoryOnly;
  bool _isInitialized = false;

  SecretNotesLocalRepository({
    Box<dynamic>? securityBox,
    Box<dynamic>? preferencesBox,
    this.inMemoryOnly = false,
  })  : _securityBox = securityBox,
        _preferencesBox = preferencesBox {
    if (inMemoryOnly || (securityBox != null && preferencesBox != null)) {
      _isInitialized = true;
    }
  }

  Future<void> init() async {
    if (_isInitialized) return;
    if (inMemoryOnly) {
      _isInitialized = true;
      return;
    }

    try {
      final isHiveReady = HiveService().isInitialized || Hive.isBoxOpen(securityBoxName);
      if (!isHiveReady) {
        _isInitialized = true;
        return;
      }

      if (_securityBox == null) {
        if (Hive.isBoxOpen(securityBoxName)) {
          _securityBox = Hive.box(securityBoxName);
        } else {
          _securityBox = await Hive.openBox(securityBoxName);
        }
      }

      if (_preferencesBox == null) {
        if (Hive.isBoxOpen(preferencesBoxName)) {
          _preferencesBox = Hive.box(preferencesBoxName);
        } else {
          _preferencesBox = await Hive.openBox(preferencesBoxName);
        }
      }

      _isInitialized = true;
      debugPrint('Secret Notes: local storage namespaces successfully initialized.');
    } catch (e) {
      debugPrint('Secret Notes: storage initialization warning, operating with local memory fallback: $e');
      _isInitialized = true;
    }
  }

  bool isConfiguredSync() {
    try {
      if (inMemoryOnly) {
        return _fallbackSecurityStore['is_configured'] == true &&
            _fallbackSecurityStore['pin_salt'] != null &&
            _fallbackSecurityStore['pin_hash'] != null;
      }
      final box = (_securityBox != null && _securityBox!.isOpen)
          ? _securityBox!
          : (Hive.isBoxOpen(securityBoxName) ? Hive.box(securityBoxName) : null);
      if (box != null && box.isOpen) {
        final isConfigured = box.get('is_configured', defaultValue: false);
        final salt = box.get('pin_salt');
        final hash = box.get('pin_hash');
        return isConfigured == true && salt != null && hash != null;
      }
      return _fallbackSecurityStore['is_configured'] == true &&
          _fallbackSecurityStore['pin_salt'] != null &&
          _fallbackSecurityStore['pin_hash'] != null;
    } catch (_) {
      return false;
    }
  }

  Future<SecretNotesSecurityState> loadSecurityState() async {
    try {
      if (!inMemoryOnly && _securityBox != null && _securityBox!.isOpen) {
        final rawMap = _securityBox!.toMap();
        final introSeen = await hasSeenIntro();
        return SecretNotesSecurityState.fromMap(rawMap).copyWith(hasSeenIntro: introSeen);
      } else {
        final introSeen = await hasSeenIntro();
        return SecretNotesSecurityState.fromMap(_fallbackSecurityStore).copyWith(hasSeenIntro: introSeen);
      }
    } catch (e) {
      debugPrint('Secret Notes: corrupted local security data detected, resetting gracefully: $e');
      return const SecretNotesSecurityState();
    }
  }

  Future<void> saveSecurityState(SecretNotesSecurityState state) async {
    try {
      final map = state.toMap();
      if (!inMemoryOnly && _securityBox != null && _securityBox!.isOpen) {
        await _securityBox!.putAll(map);
      } else {
        _fallbackSecurityStore.addAll(map);
      }
    } catch (e) {
      debugPrint('Secret Notes: failed to save security state locally: $e');
      _fallbackSecurityStore.addAll(state.toMap());
    }
  }

  Future<bool> hasSeenIntro() async {
    try {
      if (!inMemoryOnly && _preferencesBox != null && _preferencesBox!.isOpen) {
        return _preferencesBox!.get('secret_notes_intro_seen', defaultValue: false) as bool;
      }
      return _fallbackPreferencesStore['secret_notes_intro_seen'] as bool? ?? false;
    } catch (e) {
      debugPrint('Secret Notes: error reading intro seen preference: $e');
      return false;
    }
  }

  Future<void> setIntroSeen(bool value) async {
    try {
      if (!inMemoryOnly && _preferencesBox != null && _preferencesBox!.isOpen) {
        await _preferencesBox!.put('secret_notes_intro_seen', value);
      } else {
        _fallbackPreferencesStore['secret_notes_intro_seen'] = value;
      }
    } catch (e) {
      debugPrint('Secret Notes: failed to persist intro seen preference: $e');
      _fallbackPreferencesStore['secret_notes_intro_seen'] = value;
    }
  }

  Future<bool> isBiometricEnabled() async {
    try {
      if (!inMemoryOnly && _preferencesBox != null && _preferencesBox!.isOpen) {
        return _preferencesBox!.get('biometric_unlock_enabled', defaultValue: false) as bool;
      }
      return _fallbackPreferencesStore['biometric_unlock_enabled'] as bool? ?? false;
    } catch (e) {
      debugPrint('Secret Notes: error reading biometric preference: $e');
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool value) async {
    try {
      if (!inMemoryOnly && _preferencesBox != null && _preferencesBox!.isOpen) {
        await _preferencesBox!.put('biometric_unlock_enabled', value);
      } else {
        _fallbackPreferencesStore['biometric_unlock_enabled'] = value;
      }
    } catch (e) {
      debugPrint('Secret Notes: failed to persist biometric preference: $e');
      _fallbackPreferencesStore['biometric_unlock_enabled'] = value;
    }
  }

  Future<void> clearAll() async {
    try {
      if (_securityBox != null && _securityBox!.isOpen) {
        await _securityBox!.clear();
      }
      if (_preferencesBox != null && _preferencesBox!.isOpen) {
        await _preferencesBox!.clear();
      }
    } catch (_) {}
    _fallbackSecurityStore.clear();
    _fallbackPreferencesStore.clear();
  }
}
