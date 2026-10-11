import 'package:axonote_app/data/local/rows.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_harness.dart';

NoteRow _noteRow({required bool unreadable, String? rawPayload}) => NoteRow(
  id: 'n',
  folderId: null,
  title: 'Nota ilegible',
  content: '',
  preview: '',
  tagsJson: '[]',
  pinned: false,
  createdAt: '2026-10-07T12:00:00.000Z',
  updatedAt: '2026-10-07T12:00:00.000Z',
  deletedAt: null,
  revision: 1,
  syncStatus: NoteSyncStatus.synced,
  lastEditedDeviceId: 'd',
  wrappedKey: 'a1.AAAAAAAAAAAAAAAA.AAAAAAAAAAAAAAAAAAAAAAAAAAAA',
  unreadable: unreadable,
  rawPayload: rawPayload,
);

FolderRow _folderRow({required bool unreadable, String? rawPayload}) =>
    FolderRow(
      id: 'f',
      name: 'Carpeta ilegible',
      createdAt: '2026-10-07T12:00:00.000Z',
      updatedAt: '2026-10-07T12:00:00.000Z',
      revision: 1,
      wrappedKey: 'a1.AAAAAAAAAAAAAAAA.AAAAAAAAAAAAAAAAAAAAAAAAAAAA',
      unreadable: unreadable,
      rawPayload: rawPayload,
    );

void main() {
  late LocalHarness h;
  setUp(() => h = LocalHarness());
  tearDown(() => h.close());

  test(
    'una fila ilegible con raw_payload se sube con su texto cifrado original',
    () async {
      const raw = 'a1.AAAAAAAAAAAAAAAA.BBBBBBBBBBBBBBBBBBBBBBBBBBBB';
      final note = await h.local.deps.codec.sealNoteForUpload(
        _noteRow(unreadable: true, rawPayload: raw),
      );
      expect(note.payload, raw);
      final folder = await h.local.deps.codec.sealFolderForUpload(
        _folderRow(unreadable: true, rawPayload: raw),
      );
      expect(folder.payload, raw);
    },
  );

  test(
    'una fila ilegible sin raw_payload es un estado inconsistente',
    () async {
      await expectLater(
        h.local.deps.codec.sealNoteForUpload(_noteRow(unreadable: true)),
        throwsStateError,
      );
      await expectLater(
        h.local.deps.codec.sealFolderForUpload(_folderRow(unreadable: true)),
        throwsStateError,
      );
      await expectLater(
        h.local.deps.codec.sealNoteForUpload(
          _noteRow(unreadable: true, rawPayload: ''),
        ),
        throwsStateError,
      );
    },
  );
}
