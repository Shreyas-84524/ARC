import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:arc/features/secret_notes/models/secret_note.dart';
import 'package:arc/features/secret_notes/models/secret_note_attachment.dart';
import 'package:arc/features/secret_notes/repositories/secret_notes_local_repository.dart';
import 'package:arc/features/secret_notes/services/secret_notes_security_service.dart';
import 'package:arc/features/secret_notes/widgets/secret_note_card.dart';

void main() {
  test('labels and local media metadata survive note serialization', () {
    final now = DateTime(2026, 10, 28, 12);
    final note = SecretNote(
      id: 'note_1',
      title: 'Trip',
      labels: const ['Personal', 'Ideas'],
      attachments: [
        SecretNoteAttachment(
          id: 'image_1',
          type: SecretNoteAttachmentType.image,
          localPath: r'C:\private\photo.jpg',
          name: 'photo.jpg',
          createdAt: now,
        ),
        SecretNoteAttachment(
          id: 'audio_1',
          type: SecretNoteAttachmentType.audio,
          localPath: r'C:\private\voice.m4a',
          name: 'Voice note',
          durationMs: 4200,
          createdAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    final restored = SecretNote.fromMap(note.toMap());

    expect(restored.labels, ['Personal', 'Ideas']);
    expect(restored.attachments, note.attachments);
    expect(restored.isValid, isTrue);
  });

  test('a media-only note is valid', () {
    final now = DateTime.now();
    expect(
      SecretNote.isValidContent(
        title: '',
        description: '',
        attachments: [
          SecretNoteAttachment(
            id: 'audio',
            type: SecretNoteAttachmentType.audio,
            localPath: '/private/voice.m4a',
            name: 'Voice note',
            createdAt: now,
          ),
        ],
      ),
      isTrue,
    );
  });

  test(
    'removing the optional PIN preserves preferences and allows direct access',
    () async {
      final repository = SecretNotesLocalRepository(inMemoryOnly: true);
      final service = SecretNotesSecurityService(repository: repository);
      await repository.setIntroSeen(true);
      expect(await service.setupPin('1234'), isTrue);

      expect(await service.removePin('1234'), isNull);
      expect(await service.isSecretNotesConfigured(), isFalse);
      expect(await repository.hasSeenIntro(), isTrue);
    },
  );

  testWidgets('note card displays labels and attachment counts', (
    tester,
  ) async {
    final now = DateTime.now();
    final note = SecretNote(
      id: 'note_1',
      title: 'Reference',
      labels: const ['Work'],
      attachments: [
        SecretNoteAttachment(
          id: 'image',
          type: SecretNoteAttachmentType.image,
          localPath: '/private/photo.jpg',
          name: 'photo.jpg',
          createdAt: now,
        ),
        SecretNoteAttachment(
          id: 'audio',
          type: SecretNoteAttachmentType.audio,
          localPath: '/private/voice.m4a',
          name: 'Voice note',
          createdAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SecretNoteCard(note: note, onTap: () {}),
        ),
      ),
    );

    expect(find.text('Work'), findsOneWidget);
    expect(find.byIcon(Icons.image), findsNothing);
    expect(find.text('1'), findsNWidgets(2));
  });
}
