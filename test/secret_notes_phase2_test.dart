import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/features/secret_notes/models/secret_note.dart';
import 'package:arc/features/secret_notes/models/secret_note_color.dart';
import 'package:arc/features/secret_notes/models/secret_notes_security_state.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_local_repository.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_data_repository.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_dashboard_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_note_editor_screen.dart';
import 'package:arc/features/secret_notes/widgets/secret_note_card.dart';
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

  group('Secret Notes Phase 2 - Note Model & Validation', () {
    test('SecretNote serialization and deserialization roundtrip', () {
      final now = DateTime(2026, 10, 13, 14, 30);
      final note = SecretNote(
        id: 'note_123',
        title: 'Secret Plans',
        description: 'Deeply private details.',
        color: 'amber',
        createdAt: now,
        updatedAt: now,
      );

      final map = note.toMap();
      expect(map['id'], equals('note_123'));
      expect(map['title'], equals('Secret Plans'));
      expect(map['description'], equals('Deeply private details.'));
      expect(map['color'], equals('amber'));
      expect(map['createdAt'], equals(now.toIso8601String()));
      expect(map['updatedAt'], equals(now.toIso8601String()));

      final deserialized = SecretNote.fromMap(map);
      expect(deserialized, equals(note));
    });

    test('generateId creates unique non-empty identifiers', () {
      final id1 = SecretNote.generateId();
      final id2 = SecretNote.generateId();

      expect(id1.isNotEmpty, isTrue);
      expect(id2.isNotEmpty, isTrue);
      expect(id1.startsWith('note_'), isTrue);
      expect(id1, isNot(equals(id2)));
    });

    test('Validation rule: title only accepted', () {
      expect(SecretNote.isValidContent(title: 'My Title', description: ''), isTrue);
      final note = SecretNote(
        id: '1',
        title: 'Title',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(note.isValid, isTrue);
    });

    test('Validation rule: description only accepted', () {
      expect(SecretNote.isValidContent(title: '', description: 'My Description'), isTrue);
      final note = SecretNote(
        id: '2',
        description: 'Only body content',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(note.isValid, isTrue);
    });

    test('Validation rule: title and description accepted', () {
      expect(SecretNote.isValidContent(title: 'Title', description: 'Body'), isTrue);
    });

    test('Validation rule: both empty or whitespace-only rejected', () {
      expect(SecretNote.isValidContent(title: '', description: ''), isFalse);
      expect(SecretNote.isValidContent(title: '   ', description: '  \n\t '), isFalse);
      final emptyNote = SecretNote(
        id: '3',
        title: '   ',
        description: ' ',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(emptyNote.isValid, isFalse);
    });

    test('copyWith updates fields while preserving unedited attributes', () {
      final t1 = DateTime(2026, 1, 1);
      final t2 = DateTime(2026, 1, 2);
      final note = SecretNote(
        id: 'orig_id',
        title: 'Original',
        description: 'Original body',
        color: 'sky',
        createdAt: t1,
        updatedAt: t1,
      );

      final updated = note.copyWith(
        title: 'Updated Title',
        updatedAt: t2,
      );

      expect(updated.id, equals('orig_id'));
      expect(updated.title, equals('Updated Title'));
      expect(updated.description, equals('Original body'));
      expect(updated.color, equals('sky'));
      expect(updated.createdAt, equals(t1));
      expect(updated.updatedAt, equals(t2));
    });
  });

  group('Secret Notes Phase 2 - Color Palette System', () {
    test('Palette provides at least 8 distinct colors and handles fallbacks', () {
      expect(SecretNoteColors.palette.length, greaterThanOrEqualTo(8));

      final defaultColor = SecretNoteColors.getById(null);
      expect(defaultColor.id, equals('default'));

      final fallbackColor = SecretNoteColors.getById('non_existent_color_id');
      expect(fallbackColor.id, equals('default'));

      final amber = SecretNoteColors.getById('amber');
      expect(amber.id, equals('amber'));
      expect(amber.backgroundColor(false), isNotNull);
      expect(amber.backgroundColor(true), isNotNull);
      expect(amber.borderColor(false), isNotNull);
      expect(amber.borderColor(true), isNotNull);
    });
  });

  group('Secret Notes Phase 2 - Data Repository Tests', () {
    late SecretNotesDataRepository repo;

    setUp(() {
      repo = SecretNotesDataRepository(inMemoryOnly: true);
    });

    test('saveNote, getNotes, and getNoteById function correctly', () async {
      final t = DateTime.now();
      final note1 = SecretNote(
        id: 'note_1',
        title: 'First Note',
        description: 'Content 1',
        createdAt: t,
        updatedAt: t,
      );

      await repo.saveNote(note1);

      final retrieved = await repo.getNoteById('note_1');
      expect(retrieved, isNotNull);
      expect(retrieved?.title, equals('First Note'));

      final notes = await repo.getNotes();
      expect(notes.length, equals(1));
      expect(notes.first.id, equals('note_1'));
    });

    test('Notes are ordered by updatedAt descending', () async {
      final t1 = DateTime(2026, 10, 10, 10, 0);
      final t2 = DateTime(2026, 10, 11, 10, 0);
      final t3 = DateTime(2026, 10, 12, 10, 0);

      final noteOld = SecretNote(
        id: 'n_old',
        title: 'Old Note',
        createdAt: t1,
        updatedAt: t1,
      );
      final noteMid = SecretNote(
        id: 'n_mid',
        title: 'Mid Note',
        createdAt: t2,
        updatedAt: t2,
      );
      final noteNew = SecretNote(
        id: 'n_new',
        title: 'Newest Note',
        createdAt: t1,
        updatedAt: t3,
      );

      // Save in arbitrary order
      await repo.saveNote(noteMid);
      await repo.saveNote(noteOld);
      await repo.saveNote(noteNew);

      final list = await repo.getNotes();
      expect(list.length, equals(3));
      expect(list[0].id, equals('n_new')); // t3
      expect(list[1].id, equals('n_mid')); // t2
      expect(list[2].id, equals('n_old')); // t1
    });

    test('updateNote preserves ID and updates content without duplication', () async {
      final t1 = DateTime(2026, 10, 10);
      final note = SecretNote(
        id: 'n_1',
        title: 'Initial Title',
        description: 'Initial Body',
        createdAt: t1,
        updatedAt: t1,
      );
      await repo.saveNote(note);

      final t2 = DateTime(2026, 10, 11);
      final updatedNote = note.copyWith(
        title: 'Edited Title',
        updatedAt: t2,
      );
      await repo.saveNote(updatedNote);

      final list = await repo.getNotes();
      expect(list.length, equals(1));
      expect(list.first.title, equals('Edited Title'));
      expect(list.first.updatedAt, equals(t2));
    });

    test('deleteNote permanently removes note from store', () async {
      final note = SecretNote(
        id: 'to_delete',
        title: 'Delete me',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repo.saveNote(note);

      expect((await repo.getNotes()).length, equals(1));

      await repo.deleteNote('to_delete');

      expect((await repo.getNotes()).isEmpty, isTrue);
      expect(await repo.getNoteById('to_delete'), isNull);
    });
  });

  group('Secret Notes Phase 2 - Dashboard Widget Tests', () {
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

    testWidgets('Displays clean empty state when no notes exist', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

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

      expect(find.text('No secret notes yet'), findsOneWidget);
      expect(find.text('Create your first private note.'), findsOneWidget);
      expect(find.text('Add Note'), findsWidgets);
    });

    testWidgets('Displays note cards with title, 2-line preview, and color', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final now = DateTime.now();
      await dataRepo.saveNote(
        SecretNote(
          id: 'note_card_1',
          title: 'Mission Briefing',
          description: 'Line 1\nLine 2\nLine 3 hidden in preview',
          color: 'emerald',
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

      expect(find.text('Mission Briefing'), findsOneWidget);
      expect(find.textContaining('Line 1'), findsOneWidget);
      expect(find.byType(SecretNoteCard), findsOneWidget);
    });

    testWidgets('Title-only note displays title without blank placeholders', (tester) async {
      await dataRepo.saveNote(
        SecretNote(
          id: 'title_only',
          title: 'Only Title Here',
          description: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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

      expect(find.text('Only Title Here'), findsOneWidget);
    });

    testWidgets('Description-only note displays description as prominent visible text', (tester) async {
      await dataRepo.saveNote(
        SecretNote(
          id: 'desc_only',
          title: '',
          description: 'Body only note content without title',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
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

      expect(find.text('Body only note content without title'), findsOneWidget);
    });
  });

  group('Secret Notes Phase 2 - Editor Widget Tests', () {
    late SecretNotesLocalRepository securityRepo;
    late SecretNotesSecurityService securityService;
    late SecretNotesDataRepository dataRepo;

    setUp(() async {
      securityRepo = SecretNotesLocalRepository(inMemoryOnly: true);
      securityService = SecretNotesSecurityService(repository: securityRepo);
      await securityService.setupPin('123456');
      dataRepo = SecretNotesDataRepository(inMemoryOnly: true);
    });

    testWidgets('Rejects saving note when both title and description are empty', (tester) async {
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

      // Tap Save button with empty fields
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Note cannot be empty'), findsOneWidget);
      expect((await dataRepo.getNotes()).isEmpty, isTrue);
    });

    testWidgets('Creates new note with title, description, and chosen color', (tester) async {
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

      // Fill title
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Classified Entry');
      await tester.enterText(textFields.last, 'Restricted information payload');

      // Tap Save
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final notes = await dataRepo.getNotes();
      expect(notes.length, equals(1));
      expect(notes.first.title, equals('Classified Entry'));
      expect(notes.first.description, equals('Restricted information payload'));
    });

    testWidgets('Edits existing note and preserves original ID and createdAt', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final originalCreated = DateTime(2026, 5, 1, 10, 0);
      final note = SecretNote(
        id: 'fixed_note_id',
        title: 'Original Title',
        description: 'Original Body',
        color: 'sky',
        createdAt: originalCreated,
        updatedAt: originalCreated,
      );
      await dataRepo.saveNote(note);

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNoteEditorScreen(noteId: 'fixed_note_id'),
          overrides: [
            secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Secret Note'), findsOneWidget);
      expect(find.text('Original Title'), findsOneWidget);

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.first, 'Updated Title');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final notes = await dataRepo.getNotes();
      expect(notes.length, equals(1));
      expect(notes.first.id, equals('fixed_note_id'));
      expect(notes.first.title, equals('Updated Title'));
      expect(notes.first.createdAt, equals(originalCreated));
      expect(notes.first.updatedAt.isAfter(originalCreated), isTrue);
    });

    testWidgets('Delete confirmation dialog confirms and removes note', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
      });

      final note = SecretNote(
        id: 'del_id',
        title: 'To be destroyed',
        description: 'Self-destruct',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await dataRepo.saveNote(note);

      await tester.pumpWidget(
        createTestApp(
          child: const SecretNoteEditorScreen(noteId: 'del_id'),
          overrides: [
            secretNotesDataRepositoryProvider.overrideWithValue(dataRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap trash icon
      await tester.tap(find.byIcon(LucideIcons.trash2));
      await tester.pumpAndSettle();

      expect(find.text('Delete this secret note?'), findsOneWidget);

      // Confirm Delete
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect((await dataRepo.getNotes()).isEmpty, isTrue);
    });
  });

  group('Secret Notes Phase 2 - Route Security & Privacy', () {
    test('Locked user cannot access note editor route directly', () {
      const user = UserContext(
        userId: 'test_user_1',
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
          salt: 'aabbcc',
          pinHash: 'ddeeff',
        ),
      );

      // Session is LOCKED by default
      expect(container.read(secretNotesSessionProvider), isFalse);

      final routerNotifier = container.read(routerNotifierProvider);

      // Navigating directly to /secret-notes/new should be blocked and redirected to /secret-notes/unlock
      final redirectNew = routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/secret-notes/new'));
      expect(redirectNew, equals('/secret-notes/unlock'));

      // Navigating directly to /secret-notes/:id should also be blocked
      final redirectId = routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/secret-notes/note_123'));
      expect(redirectId, equals('/secret-notes/unlock'));

      // Unlock session
      container.read(secretNotesSessionProvider.notifier).unlock();

      final redirectUnlockedNew = routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/secret-notes/new'));
      expect(redirectUnlockedNew, isNull);

      final redirectUnlockedId = routerNotifier.redirect(FakeBuildContext(), FakeGoRouterState('/secret-notes/note_123'));
      expect(redirectUnlockedId, isNull);
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
