import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/secret_notes/models/secret_note.dart';
import 'package:arc/features/secret_notes/models/secret_checklist_item.dart';
import 'package:arc/features/secret_notes/models/secret_notes_security_state.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_local_repository.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_data_repository.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_dashboard_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_note_editor_screen.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/routes/app_router.dart';

Widget createTestApp({
  required Widget child,
  List<Override> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Secret Notes Phase 3 - Checklist Model & Validation', () {
    test('SecretChecklistItem serialization and deserialization roundtrip', () {
      final now = DateTime(2026, 10, 13, 15, 0);
      final item = SecretChecklistItem(
        id: 'item_101',
        text: 'Encrypted flash drive',
        isCompleted: true,
        createdAt: now,
        order: 2,
      );

      final map = item.toMap();
      expect(map['id'], equals('item_101'));
      expect(map['text'], equals('Encrypted flash drive'));
      expect(map['isCompleted'], isTrue);
      expect(map['createdAt'], equals(now.toIso8601String()));
      expect(map['order'], equals(2));

      final deserialized = SecretChecklistItem.fromMap(map);
      expect(deserialized, equals(item));
    });

    test('generateId produces unique non-empty identifiers for checklist items', () {
      final id1 = SecretChecklistItem.generateId();
      final id2 = SecretChecklistItem.generateId();

      expect(id1.isNotEmpty, isTrue);
      expect(id2.isNotEmpty, isTrue);
      expect(id1.startsWith('item_'), isTrue);
      expect(id1, isNot(equals(id2)));
    });

    test('Validation rule: checklist-only note is valid', () {
      final item = SecretChecklistItem(
        id: '1',
        text: 'Passport',
        createdAt: DateTime.now(),
      );
      final note = SecretNote(
        id: 'chk_note',
        title: '',
        description: '',
        checklist: [item],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(note.isValid, isTrue);
      expect(
        SecretNote.isValidContent(
          title: '',
          description: '',
          checklist: [item],
        ),
        isTrue,
      );
    });

    test('Validation rule: empty checklist-only note is invalid', () {
      final emptyItem = SecretChecklistItem(
        id: '2',
        text: '   ',
        createdAt: DateTime.now(),
      );
      final note = SecretNote(
        id: 'empty_chk',
        title: ' ',
        description: '',
        checklist: [emptyItem],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(note.isValid, isFalse);
    });

    test('Validation rule: mixed note (title + description + checklist) is valid', () {
      final item = SecretChecklistItem(
        id: '3',
        text: 'Lock the safe',
        createdAt: DateTime.now(),
      );
      final note = SecretNote(
        id: 'mixed_note',
        title: 'Security Routine',
        description: 'End of week checklist',
        checklist: [item],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(note.isValid, isTrue);
    });

    test('SecretNote with checklist serializes and deserializes cleanly', () {
      final now = DateTime(2026, 10, 13, 16, 0);
      final item = SecretChecklistItem(
        id: 'chk_1',
        text: 'Backup keys',
        isCompleted: false,
        createdAt: now,
        order: 0,
      );
      final note = SecretNote(
        id: 'n_chk',
        title: 'Vault',
        description: 'Instructions',
        checklist: [item],
        createdAt: now,
        updatedAt: now,
      );

      final map = note.toMap();
      expect(map['checklist'], isA<List>());
      expect((map['checklist'] as List).length, equals(1));

      final restored = SecretNote.fromMap(map);
      expect(restored, equals(note));
      expect(restored.checklist.first.text, equals('Backup keys'));
    });
  });

  group('Secret Notes Phase 3 - Backward Compatibility & Migration', () {
    test('Phase 2 note without checklist field loads cleanly with empty checklist', () {
      // Legacy Phase 2 record without 'checklist' key
      final legacyMap = {
        'id': 'legacy_note_1',
        'title': 'Old Note',
        'description': 'Created in Phase 2',
        'color': 'teal',
        'createdAt': '2026-10-10T10:00:00.000',
        'updatedAt': '2026-10-10T10:00:00.000',
      };

      final note = SecretNote.fromMap(legacyMap);
      expect(note.id, equals('legacy_note_1'));
      expect(note.title, equals('Old Note'));
      expect(note.checklist, isEmpty);
      expect(note.isValid, isTrue);
    });

    test('Malformed checklist records are skipped gracefully without crashing', () {
      final corruptMap = {
        'id': 'corrupt_note',
        'title': 'Resilient Note',
        'description': 'Safe',
        'color': 'default',
        'checklist': [
          'not a map',
          {'id': 'valid_item', 'text': 'Valid item', 'isCompleted': true},
          null,
        ],
        'createdAt': '2026-10-10T10:00:00.000',
        'updatedAt': '2026-10-10T10:00:00.000',
      };

      final note = SecretNote.fromMap(corruptMap);
      expect(note.checklist.length, equals(1));
      expect(note.checklist.first.id, equals('valid_item'));
      expect(note.checklist.first.isCompleted, isTrue);
    });
  });

  group('Secret Notes Phase 3 - Dashboard Card Checklist Preview', () {
    late SecretNotesLocalRepository securityRepo;
    late SecretNotesSecurityService securityService;
    late SecretNotesDataRepository dataRepo;

    setUp(() async {
      securityRepo = SecretNotesLocalRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: securityRepo);
      await securityService.setupPin('123456');
      await securityService.markIntroSeen();
      dataRepo = SecretNotesDataRepository(inMemoryOnly: true);
    });

    testWidgets('Renders checklist preview with up to 2 items and truncated indicator', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final now = DateTime.now();
      await dataRepo.saveNote(
        SecretNote(
          id: 'card_chk',
          title: 'Shopping List',
          description: '',
          color: 'amber',
          checklist: [
            SecretChecklistItem(
              id: 'c1',
              text: 'Apples',
              isCompleted: false,
              createdAt: now,
              order: 0,
            ),
            SecretChecklistItem(
              id: 'c2',
              text: 'Oranges',
              isCompleted: true,
              createdAt: now,
              order: 1,
            ),
            SecretChecklistItem(
              id: 'c3',
              text: 'Bananas',
              isCompleted: false,
              createdAt: now,
              order: 2,
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNotesDashboardScreen(),
          overrides: [
            secretNotesLocalRepositoryProvider.overrideWithValue(securityRepo),
            secretNotesSecurityServiceProvider.overrideWithValue(securityService),
            secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shopping List'), findsOneWidget);
      expect(find.text('Apples'), findsOneWidget);
      expect(find.text('Oranges'), findsOneWidget);
      // Third item is truncated from preview
      expect(find.text('Bananas'), findsNothing);
      expect(find.text('+1 more items'), findsOneWidget);
    });
  });

  group('Secret Notes Phase 3 - Editor Checklist Lifecycle & UX', () {
    late SecretNotesDataRepository dataRepo;

    setUp(() {
      dataRepo = SecretNotesDataRepository(inMemoryOnly: true);
    });

    testWidgets('Adds checklist items, edits text, toggles completion, and removes empty on save', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNoteEditorScreen(),
          overrides: [
            secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Enter title
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Travel Packing');

      // Tap checklist action in AppBar
      await tester.tap(find.byTooltip('Add Checklist'));
      await tester.pumpAndSettle();

      // Should show checklist section with 1 empty item
      expect(find.text('Checklist'), findsOneWidget);

      // Find checklist item TextField (now the 3rd TextField: title, description, item 1)
      final allFields = find.byType(TextField);
      expect(allFields, findsNWidgets(3));
      await tester.enterText(allFields.at(2), 'Passport');

      // Tap "Add item" button to append second item
      await tester.tap(find.text('Add item'));
      await tester.pumpAndSettle();

      final updatedFields = find.byType(TextField);
      expect(updatedFields, findsNWidgets(4));
      await tester.enterText(updatedFields.at(3), 'Travel Insurance');

      // Toggle completion on the second item (square icon)
      final squareIcons = find.byIcon(LucideIcons.square);
      await tester.tap(squareIcons.last);
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final notes = await dataRepo.getNotes();
      expect(notes.length, equals(1));
      expect(notes.first.title, equals('Travel Packing'));
      expect(notes.first.checklist.length, equals(2));
      expect(notes.first.checklist[0].text, equals('Passport'));
      expect(notes.first.checklist[0].isCompleted, isFalse);
      expect(notes.first.checklist[1].text, equals('Travel Insurance'));
      expect(notes.first.checklist[1].isCompleted, isTrue);
    });

    testWidgets('Checklist item can be removed via X button', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final now = DateTime.now();
      final note = SecretNote(
        id: 'remove_item_note',
        title: 'Tasks',
        checklist: [
          SecretChecklistItem(
            id: 'i1',
            text: 'Keep me',
            createdAt: now,
          ),
          SecretChecklistItem(
            id: 'i2',
            text: 'Delete me',
            createdAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      await dataRepo.saveNote(note);

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNoteEditorScreen(noteId: 'remove_item_note'),
          overrides: [
            secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keep me'), findsOneWidget);
      expect(find.text('Delete me'), findsOneWidget);

      // Tap delete (X) icon on the second item
      final deleteIcons = find.byIcon(LucideIcons.x);
      await tester.tap(deleteIcons.last);
      await tester.pumpAndSettle();

      expect(find.text('Delete me'), findsNothing);

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final notes = await dataRepo.getNotes();
      expect(notes.first.checklist.length, equals(1));
      expect(notes.first.checklist.first.text, equals('Keep me'));
    });

    testWidgets('Unsaved changes dialog prompts on back press when modified', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNoteEditorScreen(),
          overrides: [
            secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Enter title (creates unsaved change)
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Draft Title');

      // Tap back button
      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);

      // Tap Keep Editing
      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Draft Title'), findsOneWidget);

      // Tap back button again and confirm Discard
      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      // Note was not saved
      expect((await dataRepo.getNotes()).isEmpty, isTrue);
    });
  });

  group('Secret Notes Phase 3 - Route Isolation & Security', () {
    test('Direct route access to /secret-notes/new is guarded against locked sessions', () {
      const user = UserContext(
        userId: 'phase3_user',
        isInitializing: false,
      );

      final localRepo = SecretNotesLocalRepository(inMemoryOnly: true);
      final securityService = SecretNotesSecurityService(repository: localRepo);

      final container = ProviderContainer(
        overrides: [
          userContextProvider.overrideWith((ref) => UserContextNotifierTestHelper(user)),
          secretNotesLocalRepositoryProvider.overrideWithValue(localRepo),
          secretNotesSecurityServiceProvider.overrideWithValue(securityService),
        ],
      );

      // Configure PIN
      localRepo.saveSecurityState(
        const SecretNotesSecurityState(
          isConfigured: true,
          salt: '112233',
          pinHash: '445566',
        ),
      );

      // Session is locked
      final routerNotifier = container.read(routerNotifierProvider);
      final redirect = routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/secret-notes/new'));
      expect(redirect, equals('/secret-notes/unlock'));
    });
  });
}

class UserContextNotifierTestHelper extends UserContextNotifier {
  UserContextNotifierTestHelper(UserContext initialState) : super() {
    state = initialState;
  }
}

class FakeGoRouterState extends Fake implements GoRouterState {
  final String _path;
  FakeGoRouterState(this._path);

  @override
  Uri get uri => Uri.parse(_path);

  @override
  String get matchedLocation => _path;
}

class FakeBuildContext extends Fake implements BuildContext {}
