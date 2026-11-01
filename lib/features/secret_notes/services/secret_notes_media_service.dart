import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:arc/features/secret_notes/models/secret_note_attachment.dart';

/// Stores Secret Notes media only in the app's private documents directory.
class SecretNotesMediaService {
  static const MethodChannel _channel = MethodChannel(
    'com.arc.arc/secret_notes_media',
  );

  final ImagePicker _picker;

  SecretNotesMediaService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  Future<Directory> _noteDirectory(String noteId) async {
    final documents = await getApplicationDocumentsDirectory();
    final safeId = noteId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final directory = Directory(
      '${documents.path}${Platform.pathSeparator}secret_notes_media'
      '${Platform.pathSeparator}$safeId',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<void> clearAllMedia() async {
    try {
      final documents = await getApplicationDocumentsDirectory().timeout(
        const Duration(seconds: 2),
      );
      final directory = Directory(
        '${documents.path}${Platform.pathSeparator}secret_notes_media',
      );
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (error) {
      debugPrint('Secret Notes: unable to clear local media: $error');
    }
  }

  Future<SecretNoteAttachment?> pickImage(String noteId) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2200,
    );
    if (picked == null) return null;

    final directory = await _noteDirectory(noteId);
    final extension = picked.name.contains('.')
        ? picked.name.substring(picked.name.lastIndexOf('.'))
        : '.jpg';
    final id = SecretNoteAttachment.generateId();
    final destination = File(
      '${directory.path}${Platform.pathSeparator}$id$extension',
    );
    await File(picked.path).copy(destination.path);
    return SecretNoteAttachment(
      id: id,
      type: SecretNoteAttachmentType.image,
      localPath: destination.path,
      name: picked.name,
      createdAt: DateTime.now(),
    );
  }

  Future<String> startRecording(String noteId) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Voice recording is currently available on Android.',
      );
    }
    final directory = await _noteDirectory(noteId);
    final id = SecretNoteAttachment.generateId();
    final path = '${directory.path}${Platform.pathSeparator}$id.m4a';
    final started = await _channel.invokeMethod<bool>('startRecording', {
      'path': path,
    });
    if (started != true) {
      throw StateError('Microphone permission was not granted.');
    }
    return path;
  }

  Future<SecretNoteAttachment?> stopRecording(String path) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'stopRecording',
    );
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) return null;
    return SecretNoteAttachment(
      id: SecretNoteAttachment.generateId(),
      type: SecretNoteAttachmentType.audio,
      localPath: path,
      name: 'Voice note',
      durationMs: (result?['durationMs'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.now(),
    );
  }

  Future<void> playAudio(String path) async {
    await _channel.invokeMethod<void>('playAudio', {'path': path});
  }

  Future<void> pauseAudio() => _channel.invokeMethod<void>('pauseAudio');

  Future<void> stopAudio() => _channel.invokeMethod<void>('stopAudio');

  Future<void> deleteAttachment(SecretNoteAttachment attachment) async {
    try {
      final file = File(attachment.localPath);
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('Secret Notes: unable to remove attachment: $error');
    }
  }
}
