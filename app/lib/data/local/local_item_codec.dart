import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';

import 'failures.dart';
import 'local_deps.dart';

/// Adaptador `ItemCodec` sobre `LocalCodec`: cifra un elemento de la cola **desde su fila
/// actual** (A4, plan §7). El motor (`axonote_sync`) solo pide el [Id]; esta clase es la única
/// que sabe leer la fila de drift y pedirle a `LocalCodec` que la cifre.
class LocalItemCodec implements ItemCodec {
  LocalItemCodec(this._d);

  final LocalDeps _d;

  @override
  Future<EncryptedNoteFields> sealNote(Id id) => _d.lock.run(() async {
    final row = await _d.notes.byId(id);
    if (row == null) failNotFound('note');
    final sealed = await _d.codec.sealNoteForUpload(row);
    return EncryptedNoteFields(
      folderId: row.folderId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
      wrappedKey: sealed.wrappedKey,
      payload: sealed.payload,
    );
  });

  @override
  Future<EncryptedFolderFields> sealFolder(Id id) => _d.lock.run(() async {
    final row = await _d.folders.byId(id);
    if (row == null) failNotFound('folder');
    final sealed = await _d.codec.sealFolderForUpload(row);
    return EncryptedFolderFields(
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      wrappedKey: sealed.wrappedKey,
      payload: sealed.payload,
    );
  });
}
