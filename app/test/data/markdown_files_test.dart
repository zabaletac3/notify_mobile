import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:axonote_app/data/markdown_files.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_test/flutter_test.dart';

Note note(String id, String title, String content) => Note(
  id: id,
  folderId: null,
  title: title,
  content: content,
  tags: const [],
  pinned: false,
  createdAt: '2026-10-15T09:00:00.000Z',
  updatedAt: '2026-10-15T09:00:00.000Z',
  deletedAt: null,
  revision: 0,
  syncStatus: NoteSyncStatus.synced,
  lastEditedDeviceId: 'd',
);

void main() {
  test('el .zip lleva un .md por nota con el formato de exportación', () {
    final bytes = buildNotesZip([
      note('1', 'Reunión', 'Temas:\n\n- uno'),
      note('2', 'Otra', 'cuerpo'),
    ]);
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(
      archive.files.map((f) => f.name),
      containsAll(['Reunión.md', 'Otra.md']),
    );
    final first = archive.files.firstWhere((f) => f.name == 'Reunión.md');
    expect(
      utf8.decode(first.content as List<int>),
      '# Reunión\n\nTemas:\n\n- uno\n',
    );
  });

  test(
    'nombres repetidos se desambiguan y los caracteres inválidos se limpian',
    () {
      final bytes = buildNotesZip([
        note('1', 'Nota', 'a'),
        note('2', 'Nota', 'b'),
        note('3', 'a/b', 'c'),
        note('4', '', 'd'),
      ]);
      final names = ZipDecoder()
          .decodeBytes(bytes)
          .files
          .map((f) => f.name)
          .toList();
      expect(
        names,
        containsAll(['Nota.md', 'Nota (2).md', 'a-b.md', 'nota.md']),
      );
      expect(names.toSet().length, names.length);
    },
  );
}
