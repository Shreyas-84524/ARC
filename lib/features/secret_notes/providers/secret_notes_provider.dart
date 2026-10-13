import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/features/secret_notes/models/secret_note.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_local_repository.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_data_repository.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';
import 'package:arc/features/secret_notes/services/secret_notes_biometric_service.dart';
import 'package:arc/features/secret_notes/services/secret_notes_window_privacy_service.dart';

// LOCAL-ONLY ARCHITECTURE RULE:
// Secret Notes must NEVER sync with Firebase, Firestore, or any cloud service.
// All providers and session notifiers operate strictly within local memory and local storage.

final secretNotesWindowPrivacyServiceProvider =
    Provider<SecretNotesWindowPrivacyService>((ref) {
  return SecretNotesWindowPrivacyService();
});

final secretNotesLocalRepositoryProvider =
    Provider<SecretNotesLocalRepository>((ref) {
  return SecretNotesLocalRepository();
});

final secretNotesDataRepositoryProvider =
    Provider<SecretNotesDataRepository>((ref) {
  return SecretNotesDataRepository();
});

final secretNotesBiometricServiceProvider =
    Provider<SecretNotesBiometricService>((ref) {
  return SecretNotesBiometricService();
});

final secretNotesSecurityServiceProvider =
    Provider<SecretNotesSecurityService>((ref) {
  final repo = ref.watch(secretNotesLocalRepositoryProvider);
  return SecretNotesSecurityService(repository: repo);
});

/// Reactive notifier for biometric unlock toggle preference.
class SecretNotesBiometricEnabledNotifier extends StateNotifier<bool> {
  final SecretNotesSecurityService _securityService;

  SecretNotesBiometricEnabledNotifier(this._securityService) : super(false) {
    loadPreference();
  }

  Future<void> loadPreference() async {
    final enabled = await _securityService.isBiometricEnabled();
    state = enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    await _securityService.setBiometricEnabled(enabled);
    state = enabled;
  }
}

final secretNotesBiometricEnabledProvider =
    StateNotifierProvider<SecretNotesBiometricEnabledNotifier, bool>((ref) {
  final service = ref.watch(secretNotesSecurityServiceProvider);
  return SecretNotesBiometricEnabledNotifier(service);
});

/// In-memory session state for whether Secret Notes is unlocked.
/// Starts as `false` on every app process launch.
class SecretNotesSessionNotifier extends StateNotifier<bool> {
  SecretNotesSessionNotifier() : super(false);

  void unlock() {
    state = true;
  }

  void lock() {
    state = false;
  }
}

final secretNotesSessionProvider =
    StateNotifierProvider<SecretNotesSessionNotifier, bool>((ref) {
  return SecretNotesSessionNotifier();
});

/// Reactive notifier for whether Secret Notes is configured on this device.
class SecretNotesConfiguredNotifier extends StateNotifier<AsyncValue<bool>> {
  final SecretNotesSecurityService _service;

  SecretNotesConfiguredNotifier(this._service) : super(const AsyncValue.loading()) {
    checkConfiguration();
  }

  Future<void> checkConfiguration() async {
    try {
      final configured = await _service.isSecretNotesConfigured();
      state = AsyncValue.data(configured);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void setConfigured(bool value) {
    state = AsyncValue.data(value);
  }
}

final secretNotesConfiguredProvider =
    StateNotifierProvider<SecretNotesConfiguredNotifier, AsyncValue<bool>>((ref) {
  final service = ref.watch(secretNotesSecurityServiceProvider);
  return SecretNotesConfiguredNotifier(service);
});

/// Reactive state notifier managing the list of secret notes.
class SecretNotesListNotifier
    extends StateNotifier<AsyncValue<List<SecretNote>>> {
  final SecretNotesDataRepository _repository;

  SecretNotesListNotifier(this._repository)
      : super(const AsyncValue.loading()) {
    loadNotes();
  }

  Future<void> loadNotes() async {
    try {
      final notes = await _repository.getNotes();
      state = AsyncValue.data(notes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveNote(SecretNote note) async {
    await _repository.saveNote(note);
    await loadNotes();
  }

  Future<void> deleteNote(String id) async {
    await _repository.deleteNote(id);
    await loadNotes();
  }
}

final secretNotesListProvider =
    StateNotifierProvider<SecretNotesListNotifier, AsyncValue<List<SecretNote>>>(
        (ref) {
  final repository = ref.watch(secretNotesDataRepositoryProvider);
  return SecretNotesListNotifier(repository);
});
