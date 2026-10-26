import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/core/utils/display_name_utils.dart';
import 'package:arc/core/utils/greeting_utils.dart';
import 'package:arc/features/user_management/models/user_profile.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/features/user_management/services/auth_service.dart';
import 'package:arc/features/user_management/repository/auth_repository.dart';
import 'package:arc/features/settings/widgets/edit_display_name_dialog.dart';
import 'package:arc/core/widgets/top_bar.dart';
import 'package:arc/features/task_manager/models/task_model.dart';
import 'package:arc/features/habit_tracker/models/habit_model.dart';
import 'package:arc/features/habit_tracker/models/habit_entry_model.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';

/// Mock AuthRepository for testing Hive caching, offline queueing, and Google precedence.
class MockAuthRepository implements AuthRepository {
  final Map<String, UserProfile> remoteDb = {};
  final Map<String, UserProfile> cachedHiveDb = {};
  bool simulateOffline = false;
  int remoteWriteCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<UserProfile?> getUserProfile(String uid) async {
    if (simulateOffline) {
      return getCachedProfileFromHive(uid);
    }
    if (remoteDb.containsKey(uid)) {
      final profile = remoteDb[uid]!;
      await saveProfileToHive(profile);
      return profile;
    }
    return getCachedProfileFromHive(uid);
  }

  @override
  Future<UserProfile> updateDisplayName({
    required String userId,
    required String newDisplayName,
  }) async {
    final validationError = DisplayNameUtils.validate(newDisplayName);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final normalized = DisplayNameUtils.normalize(newDisplayName);
    final now = DateTime.now();

    UserProfile? current = await getUserProfile(userId) ?? getCachedProfileFromHive(userId);
    final UserProfile updated;

    if (current != null) {
      updated = current.copyWith(
        displayName: normalized,
        displayNameSource: 'user_customized',
        displayNameUpdatedAt: now,
        updatedAt: now,
      );
    } else {
      updated = UserProfile(
        id: userId,
        username: normalized,
        displayName: normalized,
        displayNameSource: 'user_customized',
        displayNameUpdatedAt: now,
        authProvider: 'default',
        role: 'user',
        createdAt: now,
        updatedAt: now,
        lastLoginAt: now,
      );
    }

    // 1. Save to Hive
    await saveProfileToHive(updated);

    // 2. Persist to remote or queue
    if (simulateOffline) {
      try {
        final box = HiveService().getUserBox(HiveService.settingsBoxName, userId);
        box.put('profile_sync_pending', true);
      } catch (_) {}
    } else {
      remoteDb[userId] = updated;
      remoteWriteCount++;
      try {
        final box = HiveService().getUserBox(HiveService.settingsBoxName, userId);
        box.put('profile_sync_pending', false);
      } catch (_) {}
    }

    return updated;
  }

  @override
  Future<void> saveProfileToHive(UserProfile profile) async {
    cachedHiveDb[profile.id] = profile;
    try {
      final box = HiveService().getUserBox(HiveService.settingsBoxName, profile.id);
      box.put('cached_user_profile', profile.toMap());
    } catch (_) {}
  }

  @override
  UserProfile? getCachedProfileFromHive(String userId) {
    if (cachedHiveDb.containsKey(userId)) {
      return cachedHiveDb[userId];
    }
    try {
      final box = HiveService().getUserBox(HiveService.settingsBoxName, userId);
      final data = box.get('cached_user_profile');
      if (data is Map) {
        return UserProfile.fromMap(Map<String, dynamic>.from(data));
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<void> flushPendingProfileSync(String userId) async {
    if (simulateOffline) return;
    final box = HiveService().getUserBox(HiveService.settingsBoxName, userId);
    final isPending = box.get('profile_sync_pending', defaultValue: false) == true;
    if (!isPending) return;

    final cached = getCachedProfileFromHive(userId);
    if (cached != null) {
      remoteDb[userId] = cached;
      remoteWriteCount++;
      box.put('profile_sync_pending', false);
    }
  }

  /// Simulates Google Sign-In reconciliation logic
  Future<UserProfile> simulateGoogleSignInReconciliation({
    required String uid,
    required String? freshGoogleName,
    required String? email,
  }) async {
    final now = DateTime.now();
    UserProfile? existingProfile = await getUserProfile(uid);

    UserProfile profile;
    if (existingProfile == null) {
      final displayName = (freshGoogleName != null && freshGoogleName.isNotEmpty)
          ? freshGoogleName
          : 'Google User';

      profile = UserProfile(
        id: uid,
        username: displayName,
        displayName: displayName,
        displayNameSource: 'google',
        displayNameUpdatedAt: now,
        email: email,
        authProvider: 'google',
        role: 'user',
        createdAt: now,
        updatedAt: now,
        lastLoginAt: now,
      );
    } else {
      final isCustomized = existingProfile.displayNameSource == 'user_customized';
      String resolvedDisplayName;
      String resolvedSource;
      DateTime? resolvedUpdatedAt = existingProfile.displayNameUpdatedAt;

      if (isCustomized) {
        resolvedDisplayName = existingProfile.displayName;
        resolvedSource = 'user_customized';
      } else {
        if (freshGoogleName != null && freshGoogleName.trim().isNotEmpty) {
          resolvedDisplayName = freshGoogleName.trim();
          resolvedSource = 'google';
          resolvedUpdatedAt = now;
        } else {
          resolvedDisplayName = existingProfile.displayName;
          resolvedSource = existingProfile.displayNameSource;
        }
      }

      profile = existingProfile.copyWith(
        lastLoginAt: now,
        updatedAt: now,
        displayName: resolvedDisplayName,
        displayNameSource: resolvedSource,
        displayNameUpdatedAt: resolvedUpdatedAt,
        authProvider: 'google',
      );
    }

    await saveProfileToHive(profile);
    remoteDb[uid] = profile;
    return profile;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late MockAuthRepository mockAuthRepo;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('arc_username_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(HabitAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(HabitEntryAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(TransactionAdapter());

    await Hive.openBox<Task>(HiveService.tasksBoxName);
    await Hive.openBox(HiveService.tasksSyncQueueBoxName);
    await Hive.openBox<Habit>(HiveService.habitsBoxName);
    await Hive.openBox<HabitEntry>(HiveService.habitEntriesBoxName);
    await Hive.openBox(HiveService.habitsSyncQueueBoxName);
    await Hive.openBox<Transaction>(HiveService.moneyBoxName);
    await Hive.openBox(HiveService.moneySyncQueueBoxName);
    await Hive.openBox(HiveService.settingsBoxName);

    const hapticsChannel = MethodChannel('com.arc.arc/haptics');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(hapticsChannel, (call) async => true);

    HiveService().setInitializedForTesting(true);

    // Pre-open all test user boxes during setUpAll on the real event loop
    for (final uid in [
      'google_user_1',
      'google_user_2',
      'user_offline_test_1',
      'user_offline_test_2',
      'user_restart_test',
      'widget_user_1',
      'topbar_user',
    ]) {
      await HiveService().ensureUserBoxesOpened(uid);
    }
  });

  setUp(() {
    mockAuthRepo = MockAuthRepository();
  });

  group('1. DisplayNameUtils Validation & Formatting Tests', () {
    test('Whitespace normalization trims and collapses whitespace', () {
      expect(DisplayNameUtils.normalize('   Shreyas    Shigwan   '), equals('Shreyas Shigwan'));
      expect(DisplayNameUtils.normalize('Aman\t\nSharma'), equals('Aman Sharma'));
      expect(DisplayNameUtils.normalize('   Rohit   '), equals('Rohit'));
    });

    test('Validates legitimate names across scripts and punctuation', () {
      expect(DisplayNameUtils.validate('Shreyas Shigwan'), isNull);
      expect(DisplayNameUtils.validate('Aman-Sharma'), isNull);
      expect(DisplayNameUtils.validate("O'Connor"), isNull);
      expect(DisplayNameUtils.validate('Dr. John Smith'), isNull);
      expect(DisplayNameUtils.validate('श्रेयस शिगवण'), isNull); // Devanagari (Marathi/Hindi)
      expect(DisplayNameUtils.validate('अमन शर्मा'), isNull);
      expect(DisplayNameUtils.validate('রোহিত শর্মা'), isNull); // Bengali
      expect(DisplayNameUtils.validate('ரோஹித் சர்மா'), isNull); // Tamil
      expect(DisplayNameUtils.validate('అమన్ శర్మ'), isNull); // Telugu
      expect(DisplayNameUtils.validate('അമൻ ശർമ്മ'), isNull); // Malayalam
      expect(DisplayNameUtils.validate('અમન શર્મા'), isNull); // Gujarati
      expect(DisplayNameUtils.validate('ਅਮਨ ਸ਼ਰਮਾ'), isNull); // Gurmukhi
      expect(DisplayNameUtils.validate('ಅಮನ್ ಶರ್ಮ'), isNull); // Kannada
      expect(DisplayNameUtils.validate('Renée Dupont'), isNull); // Latin accented
      expect(DisplayNameUtils.validate('Müller'), isNull); // Umlaut
    });

    test('Rejects empty or whitespace-only inputs', () {
      expect(DisplayNameUtils.validate(''), equals('Display name cannot be empty.'));
      expect(DisplayNameUtils.validate('   '), equals('Display name cannot be empty.'));
      expect(DisplayNameUtils.validate(null), equals('Display name cannot be empty.'));
    });

    test('Rejects short names (< 2 chars) and long names (> 50 chars)', () {
      expect(DisplayNameUtils.validate('A'), contains('at least 2 characters'));
      final longName = 'A' * 51;
      expect(DisplayNameUtils.validate(longName), contains('cannot exceed 50 characters'));
      final exact50 = 'A' * 50;
      expect(DisplayNameUtils.validate(exact50), isNull);
    });

    test('Rejects emojis and pictorial symbols', () {
      expect(DisplayNameUtils.validate('Shreyas 😊'), contains('cannot contain emojis'));
      expect(DisplayNameUtils.validate('Aman 🚀'), contains('cannot contain emojis'));
      expect(DisplayNameUtils.validate('🔥 Rohit 🔥'), contains('cannot contain emojis'));
      expect(DisplayNameUtils.validate('User ⭐'), contains('cannot contain emojis'));
      expect(DisplayNameUtils.validate('🎉 100'), contains('cannot contain emojis'));
    });

    test('Rejects disallowed symbols, numbers, and markup', () {
      expect(DisplayNameUtils.validate('Shreyas123'), contains('can only contain letters'));
      expect(DisplayNameUtils.validate('User@Arc'), contains('can only contain letters'));
      expect(DisplayNameUtils.validate('<script>alert()</script>'), contains('can only contain letters'));
      expect(DisplayNameUtils.validate('Test #1'), contains('can only contain letters'));
      expect(DisplayNameUtils.validate('Aman & Rohit'), contains('can only contain letters'));
    });
  });

  group('2. First Name Extraction & Dashboard Greeting Tests', () {
    test('Extracts only the first name for dashboard greeting', () {
      expect(DisplayNameUtils.extractFirstName('Shreyas Shigwan'), equals('Shreyas'));
      expect(DisplayNameUtils.extractFirstName('Aman Sharma'), equals('Aman'));
      expect(DisplayNameUtils.extractFirstName('Sachi Patel'), equals('Sachi'));
      expect(DisplayNameUtils.extractFirstName('Rohit'), equals('Rohit'));
      expect(DisplayNameUtils.extractFirstName('  श्रेयस   शिगवण  '), equals('श्रेयस'));
      expect(DisplayNameUtils.extractFirstName('   '), equals('User'));
      expect(DisplayNameUtils.extractFirstName(null), equals('User'));
    });

    test('GreetingUtils uses only first name for greeting', () {
      final morning = DateTime(2026, 8, 24, 9, 0);
      final afternoon = DateTime(2026, 8, 24, 14, 0);

      expect(
        GreetingUtils.getGreetingTitle(title: 'Dashboard', username: 'Shreyas Shigwan', now: morning),
        equals('Good Morning, Shreyas'),
      );
      expect(
        GreetingUtils.getGreetingTitle(title: 'Dashboard', username: 'Aman Sharma', now: afternoon),
        equals('Good Afternoon, Aman'),
      );
      expect(
        GreetingUtils.getGreetingTitle(title: 'Dashboard', username: 'श्रेयस शिगवण', now: morning),
        equals('Good Morning, श्रेयस'),
      );
    });
  });

  group('3. UserProfile Model & Serialization Tests', () {
    test('Defaults displayNameSource to "default" and detects customized names', () {
      final defaultProfile = UserProfile(
        id: 'u1',
        username: 'Test',
        displayName: 'Test',
        createdAt: DateTime.now(),
      );
      expect(defaultProfile.displayNameSource, equals('default'));
      expect(defaultProfile.isCustomizedName, isFalse);

      final customProfile = defaultProfile.copyWith(
        displayName: 'Custom Name',
        displayNameSource: 'user_customized',
        displayNameUpdatedAt: DateTime.now(),
      );
      expect(customProfile.displayNameSource, equals('user_customized'));
      expect(customProfile.isCustomizedName, isTrue);
    });

    test('Round-trips accurately via toMap and fromMap', () {
      final now = DateTime.now();
      final original = UserProfile(
        id: 'u2',
        username: 'Shreyas',
        displayName: 'Shreyas S.',
        displayNameSource: 'user_customized',
        displayNameUpdatedAt: now,
        email: 'shreyas@example.com',
        authProvider: 'google',
        role: 'user',
        createdAt: now,
        updatedAt: now,
        lastLoginAt: now,
      );

      final map = original.toMap();
      expect(map['displayNameSource'], equals('user_customized'));
      expect(map['displayNameUpdatedAt'], isNotNull);

      final reconstructed = UserProfile.fromMap(map);
      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.displayName, equals('Shreyas S.'));
      expect(reconstructed.displayNameSource, equals('user_customized'));
      expect(reconstructed.isCustomizedName, isTrue);
    });
  });

  group('4. Google Profile Synchronization & Precedence Tests', () {
    test('Preserves user_customized name against Google Sign-In updates', () async {
      const uid = 'google_user_1';

      // 1. Initial Google sign in sets Google name
      await mockAuthRepo.simulateGoogleSignInReconciliation(
        uid: uid,
        freshGoogleName: 'Google Old Name',
        email: 'user1@gmail.com',
      );
      var profile = await mockAuthRepo.getUserProfile(uid);
      expect(profile?.displayName, equals('Google Old Name'));
      expect(profile?.displayNameSource, equals('google'));

      // 2. User explicitly customizes their name in Arc
      await mockAuthRepo.updateDisplayName(userId: uid, newDisplayName: 'Arc Chosen Name');
      profile = await mockAuthRepo.getUserProfile(uid);
      expect(profile?.displayName, equals('Arc Chosen Name'));
      expect(profile?.displayNameSource, equals('user_customized'));

      // 3. User logs in with Google again; Google has a different name
      await mockAuthRepo.simulateGoogleSignInReconciliation(
        uid: uid,
        freshGoogleName: 'Google Changed Name',
        email: 'user1@gmail.com',
      );
      profile = await mockAuthRepo.getUserProfile(uid);

      // Customized name MUST be preserved!
      expect(profile?.displayName, equals('Arc Chosen Name'));
      expect(profile?.displayNameSource, equals('user_customized'));
    });

    test('Refreshes stale Google name when user has not customized their name', () async {
      const uid = 'google_user_2';

      // 1. Initial Google sign in sets old Google name
      await mockAuthRepo.simulateGoogleSignInReconciliation(
        uid: uid,
        freshGoogleName: 'Stale Old Google Name',
        email: 'user2@gmail.com',
      );
      var profile = await mockAuthRepo.getUserProfile(uid);
      expect(profile?.displayName, equals('Stale Old Google Name'));
      expect(profile?.displayNameSource, equals('google'));

      // 2. User changes their name on Google and logs into Arc
      await mockAuthRepo.simulateGoogleSignInReconciliation(
        uid: uid,
        freshGoogleName: 'Fresh New Google Name',
        email: 'user2@gmail.com',
      );
      profile = await mockAuthRepo.getUserProfile(uid);

      // Stale name MUST be updated to the fresh Google name!
      expect(profile?.displayName, equals('Fresh New Google Name'));
      expect(profile?.displayNameSource, equals('google'));
    });
  });

  group('5. Hive-First Caching & Offline Synchronization Tests', () {
    test('Saves display name to isolated Hive box and marks sync complete when online', () async {
      const uid = 'user_offline_test_1';
      mockAuthRepo.simulateOffline = false;

      final updated = await mockAuthRepo.updateDisplayName(
        userId: uid,
        newDisplayName: 'Shreyas Online',
      );
      expect(updated.displayName, equals('Shreyas Online'));

      // Verify Hive cache
      final cached = mockAuthRepo.getCachedProfileFromHive(uid);
      expect(cached, isNotNull);
      expect(cached?.displayName, equals('Shreyas Online'));
      expect(cached?.displayNameSource, equals('user_customized'));

      // Verify pending sync flag is false
      final box = HiveService().getUserBox(HiveService.settingsBoxName, uid);
      expect(box.get('profile_sync_pending'), isFalse);
      expect(mockAuthRepo.remoteWriteCount, equals(1));
    });

    test('Queues pending sync when offline, then flushes successfully on reconnect', () async {
      const uid = 'user_offline_test_2';
      mockAuthRepo.simulateOffline = true;

      // 1. Offline update
      final updated = await mockAuthRepo.updateDisplayName(
        userId: uid,
        newDisplayName: 'Offline Name',
      );
      expect(updated.displayName, equals('Offline Name'));

      // Local Hive cache is immediately updated
      final cached = mockAuthRepo.getCachedProfileFromHive(uid);
      expect(cached?.displayName, equals('Offline Name'));

      // Pending flag is true
      final box = HiveService().getUserBox(HiveService.settingsBoxName, uid);
      expect(box.get('profile_sync_pending'), isTrue);
      expect(mockAuthRepo.remoteWriteCount, equals(0));

      // 2. Reconnect: simulate coming back online and flushing pending mutations
      mockAuthRepo.simulateOffline = false;
      await mockAuthRepo.flushPendingProfileSync(uid);

      expect(box.get('profile_sync_pending'), isFalse);
      expect(mockAuthRepo.remoteWriteCount, equals(1));
      expect(mockAuthRepo.remoteDb[uid]?.displayName, equals('Offline Name'));
    });

    test('App restart restoration: reads Hive cache without network delay', () async {
      const uid = 'user_restart_test';

      // Pre-populate Hive cache
      final profile = UserProfile(
        id: uid,
        username: 'RestartUser',
        displayName: 'Restart User Display',
        displayNameSource: 'user_customized',
        createdAt: DateTime.now(),
      );
      await mockAuthRepo.saveProfileToHive(profile);

      // Read directly from Hive as UserContextNotifier does on startup
      final cachedOnRestart = mockAuthRepo.getCachedProfileFromHive(uid);
      expect(cachedOnRestart, isNotNull);
      expect(cachedOnRestart?.displayName, equals('Restart User Display'));
      expect(cachedOnRestart?.isCustomizedName, isTrue);
    });
  });

  group('6. EditDisplayNameDialog Widget Tests', () {
    testWidgets('Renders current display name, counter, and handles validation', (tester) async {
      final testProfile = UserProfile(
        id: 'widget_user_1',
        username: 'Shreyas',
        displayName: 'Shreyas S.',
        displayNameSource: 'user_customized',
        createdAt: DateTime.now(),
      );

      final authService = AuthService(repository: mockAuthRepo);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => EditDisplayNameDialog(
                      currentProfile: testProfile,
                      authService: authService,
                    ),
                  ),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify title and input field with current name
      expect(find.text('Edit Display Name'), findsOneWidget);
      expect(find.text('Shreyas S.'), findsOneWidget);
      expect(find.text('10 / 50'), findsOneWidget);

      // Enter emoji and attempt save
      await tester.enterText(find.byType(TextFormField), 'Shreyas 😊');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify inline error
      expect(find.textContaining('cannot contain emojis'), findsOneWidget);

      // Enter valid Indian Unicode name and save
      await tester.enterText(find.byType(TextFormField), 'श्रेयस शिगवण');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 4));

      // Dialog dismisses on success
      expect(find.byType(EditDisplayNameDialog), findsNothing);

      // Verify Hive updated with normalized Unicode name
      final cached = mockAuthRepo.getCachedProfileFromHive('widget_user_1');
      expect(cached?.displayName, equals('श्रेयस शिगवण'));
      expect(cached?.displayNameSource, equals('user_customized'));
    });

    testWidgets('TopBar extracts and displays only first name from Riverpod userContext', (tester) async {
      final container = ProviderContainer();
      final notifier = container.read(userContextProvider.notifier);

      notifier.setActiveUser(
        userId: 'topbar_user',
        profile: UserProfile(
          id: 'topbar_user',
          username: 'Aman Sharma',
          displayName: 'Aman Sharma',
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              appBar: CustomTopBar(title: 'Dashboard'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // TopBar should show "Aman" and NOT the full surname "Aman Sharma"
      expect(find.textContaining('Aman'), findsOneWidget);
      expect(find.textContaining('Aman Sharma'), findsNothing);
    });
  });
}
