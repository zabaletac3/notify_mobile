import 'dart:convert';
import 'dart:math';

import 'package:axonote_domain/axonote_domain.dart';

import 'local_deps.dart';
import 'rows.dart';

/// Genera una cantidad grande de notas de prueba en la base local, para las pruebas de rendimiento
/// (fase 6: 2 000 y 10 000 notas) y las mediciones del ZTE. No cifra claves reales ni toca la cola:
/// solo llena `notes`, `note_tags` y `folders` para medir consultas y búsquedas.
class TestDataGenerator {
  TestDataGenerator(this._deps);

  final LocalDeps _deps;

  static const List<String> _words = [
    'lorem',
    'ipsum',
    'dolor',
    'sit',
    'amet',
    'consectetur',
    'adipiscing',
    'elit',
    'tempor',
    'incididunt',
    'labore',
    'magna',
    'aliqua',
    'veniam',
    'nostrud',
  ];

  static const List<String> _tags = [
    'trabajo',
    'personal',
    'ideas',
    'estudio',
    'recetas',
  ];

  Future<void> generate({int notes = 2000, int folders = 8}) async {
    final random = Random(42);
    final base = _deps.now().toUtc();
    await _deps.db.transaction(() async {
      final folderIds = <String>[];
      for (var i = 0; i < folders; i++) {
        final id = newId(base.millisecondsSinceEpoch - 100000 + i);
        folderIds.add(id);
        final iso = isoFromDateTime(
          base.subtract(Duration(minutes: 100000 - i)),
        );
        await _deps.folders.upsert(
          FolderRow(
            id: id,
            name: 'Carpeta ${i + 1}',
            createdAt: iso,
            updatedAt: iso,
            revision: 1,
            wrappedKey: _fakeSealed(i),
            unreadable: false,
            rawPayload: null,
          ),
        );
      }

      final rows = <NoteRow>[];
      for (var i = 0; i < notes; i++) {
        final id = newId(base.millisecondsSinceEpoch - i);
        final created = isoFromDateTime(base.subtract(Duration(minutes: i)));
        final deleted = i % 100 == 0 && i != 0 ? created : null;
        final pinned = i % 50 == 0;
        final buffer = StringBuffer('Nota ${i.toString().padLeft(6, '0')} ');
        final wordCount = 20 + random.nextInt(60);
        for (var w = 0; w < wordCount; w++) {
          buffer.write('${_words[random.nextInt(_words.length)]} ');
        }
        final content = buffer.toString().trimRight();
        final noteTags = <String>[
          _tags[i % _tags.length],
          if (i % 7 == 0) _tags[(i + 2) % _tags.length],
        ];
        final folderId = i % 3 == 0 ? null : folderIds[i % folderIds.length];
        rows.add(
          NoteRow(
            id: id,
            folderId: folderId,
            title: 'Nota ${i.toString().padLeft(6, '0')}',
            content: content,
            preview: derivePreview(content),
            tagsJson: tagsToJson(noteTags),
            pinned: pinned,
            createdAt: created,
            updatedAt: created,
            deletedAt: deleted,
            revision: 1,
            syncStatus: NoteSyncStatus.synced,
            lastEditedDeviceId: 'seed',
            wrappedKey: _fakeSealed(i),
            unreadable: false,
            rawPayload: null,
          ),
        );
      }
      await _deps.notes.upsertAll(rows);
    });
  }

  String _fakeSealed(int seed) {
    final a = base64Url
        .encode(List<int>.generate(12, (i) => (seed + i) % 256))
        .replaceAll('=', '');
    final b = base64Url
        .encode(List<int>.generate(44, (i) => (seed * 7 + i) % 256))
        .replaceAll('=', '');
    return 'a1.$a.$b';
  }
}
