// Prueba la función que descifra una página de cambios remotos en un isolate de trabajo
// (`remote_decrypt_worker.dart`, plan §4.4/§12): que el propio isolate funcione de punta a punta
// (arrancarlo, pasarle los datos, recibir el resultado) y que su resultado sea exactamente el
// mismo que produciría `LocalCodec` en línea, con la misma clave.
import 'dart:typed_data';

import 'package:axonote_app/data/local/local_codec.dart'
    show unreadableFolderRow, unreadableNoteRow;
import 'package:axonote_app/data/local/remote_decrypt_worker.dart';
import 'package:axonote_app/data/local/rows.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_harness.dart';

void main() {
  late LocalHarness h;
  setUp(() => h = LocalHarness());
  tearDown(() => h.close());

  Uint8List masterKeyBytes() => Uint8List.fromList(h.vault.requireKey().bytes);

  Future<RemoteChange> noteChange(String title, String content) async {
    final note = await h.local.notes.create(
      NoteDraft(title: title, content: content),
    );
    final row = (await h.local.deps.notes.byId(note.id))!;
    final sealed = await h.local.deps.codec.sealNoteForUpload(row);
    final enc = EncryptedNote(
      id: row.id,
      folderId: row.folderId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      revision: row.revision + 1,
      lastEditedDeviceId: 'd_other',
      wrappedKey: sealed.wrappedKey,
      payload: sealed.payload,
    );
    return RemoteChange(
      entity: SyncEntity.note,
      id: enc.id,
      deleted: false,
      revision: enc.revision,
      note: enc,
    );
  }

  Future<RemoteChange> folderChange(String name) async {
    final folder = await h.local.folders.create(name);
    final row = (await h.local.deps.folders.byId(folder.id))!;
    final sealed = await h.local.deps.codec.sealFolderForUpload(row);
    final enc = EncryptedFolder(
      id: row.id,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      revision: row.revision + 1,
      wrappedKey: sealed.wrappedKey,
      payload: sealed.payload,
    );
    return RemoteChange(
      entity: SyncEntity.folder,
      id: enc.id,
      deleted: false,
      revision: enc.revision,
      folder: enc,
    );
  }

  /// Compara los campos de dos filas (no hay `==` generado para `NoteRow`/`FolderRow`).
  void expectSameNoteRow(NoteRow a, NoteRow b) {
    expect(a.id, b.id);
    expect(a.title, b.title);
    expect(a.content, b.content);
    expect(a.preview, b.preview);
    expect(a.tagsJson, b.tagsJson);
    expect(a.pinned, b.pinned);
    expect(a.revision, b.revision);
    expect(a.syncStatus, b.syncStatus);
    expect(a.wrappedKey, b.wrappedKey);
    expect(a.unreadable, b.unreadable);
    expect(a.rawPayload, b.rawPayload);
  }

  void expectSameFolderRow(FolderRow a, FolderRow b) {
    expect(a.id, b.id);
    expect(a.name, b.name);
    expect(a.revision, b.revision);
    expect(a.wrappedKey, b.wrappedKey);
    expect(a.unreadable, b.unreadable);
    expect(a.rawPayload, b.rawPayload);
  }

  test(
    'descifra notas y carpetas igual que LocalCodec en línea, con la misma clave',
    () async {
      final noteCh = await noteChange('Idea', 'contenido de prueba');
      final folderCh = await folderChange('Proyectos');

      final batch = await decryptRemoteChangesInWorker(
        userId: h.vault.userId,
        masterKeyBytes: masterKeyBytes(),
        changes: [noteCh, folderCh],
      );

      expect(batch.noteRows, hasLength(1));
      expect(batch.folderRows, hasLength(1));

      final inlineNote = await h.local.deps.codec.noteRowFromRemote(
        noteCh.note!,
        NoteSyncStatus.synced,
      );
      expectSameNoteRow(batch.noteRows[noteCh.id]!, inlineNote);
      expect(batch.noteRows[noteCh.id]!.title, 'Idea');
      expect(batch.noteRows[noteCh.id]!.content, 'contenido de prueba');
      expect(batch.noteRows[noteCh.id]!.unreadable, isFalse);

      final inlineFolder = await h.local.deps.codec.folderRowFromRemote(
        folderCh.folder!,
      );
      expectSameFolderRow(batch.folderRows[folderCh.id]!, inlineFolder);
      expect(batch.folderRows[folderCh.id]!.name, 'Proyectos');
      expect(batch.folderRows[folderCh.id]!.unreadable, isFalse);
    },
  );

  test(
    'un payload que no se puede abrir con esa clave/AAD se guarda ilegible, igual que en línea',
    () async {
      final noteCh = await noteChange('Idea', 'contenido');
      final folderCh = await folderChange('Proyectos');
      // Un userId distinto cambia el AAD (plan §6: liga el cifrado a la cuenta): la misma clave
      // ya no abre el payload, así que cae al mismo camino que un dato alterado o de otra cuenta.
      const otherUserId = 'otro-usuario';

      final batch = await decryptRemoteChangesInWorker(
        userId: otherUserId,
        masterKeyBytes: masterKeyBytes(),
        changes: [noteCh, folderCh],
      );

      final inlineNote = unreadableNoteRow(noteCh.note!, NoteSyncStatus.synced);
      expectSameNoteRow(batch.noteRows[noteCh.id]!, inlineNote);
      expect(batch.noteRows[noteCh.id]!.unreadable, isTrue);
      expect(batch.noteRows[noteCh.id]!.title, 'Nota ilegible');

      final inlineFolder = unreadableFolderRow(folderCh.folder!);
      expectSameFolderRow(batch.folderRows[folderCh.id]!, inlineFolder);
      expect(batch.folderRows[folderCh.id]!.unreadable, isTrue);
      expect(batch.folderRows[folderCh.id]!.name, 'Carpeta ilegible');
    },
  );

  test('un lote mayor que el umbral se descifra entero', () async {
    final changes = <RemoteChange>[
      for (var i = 0; i < remoteDecryptIsolateThreshold + 5; i++)
        await noteChange('Nota $i', 'contenido $i'),
    ];

    final batch = await decryptRemoteChangesInWorker(
      userId: h.vault.userId,
      masterKeyBytes: masterKeyBytes(),
      changes: changes,
    );

    expect(batch.noteRows, hasLength(changes.length));
    for (final ch in changes) {
      expect(batch.noteRows[ch.id]!.unreadable, isFalse);
    }
  });
}
