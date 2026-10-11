import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';

import '../crypto/vault.dart';
import 'failures.dart';
import 'rows.dart';

/// Convierte entre lo que guarda la base local (contenido en claro, dentro de una base cifrada) y
/// el formato cifrado del servidor. Equivale a `local-codec.ts` de la web, adaptado a que aquí la
/// base guarda el contenido descifrado (§6, D3).
///
/// Al **escribir** una fila local solo hace falta la clave del elemento (`wrapped_key`, A5). Al
/// **subir** (fase 7) se cifra el contenido desde la fila actual. Al **bajar** un cambio remoto se
/// descifra su `payload`. Una fila que no se puede descifrar se guarda con `unreadable = 1` y su
/// `payload` original en `raw_payload` (A6).
class LocalCodec {
  LocalCodec(this._vault);

  final Vault _vault;

  /// Fila local de una nota. Si [note] es ilegible, conserva los metadatos de [previous] y su
  /// texto cifrado (no se vuelve a cifrar). Si no, reutiliza la clave de [previous]/[wrappedKey] o
  /// genera una nueva.
  Future<NoteRow> noteRow(
    Note note, {
    NoteRow? previous,
    String? wrappedKey,
  }) async {
    if (note.unreadable) {
      final base = previous;
      if (base == null) failDecrypt();
      return base.copyWith(
        folderId: note.folderId,
        clearFolderId: note.folderId == null,
        updatedAt: note.updatedAt,
        deletedAt: note.deletedAt,
        clearDeletedAt: note.deletedAt == null,
        syncStatus: note.syncStatus,
        lastEditedDeviceId: note.lastEditedDeviceId,
      );
    }
    final key =
        wrappedKey ?? previous?.wrappedKey ?? await _newNoteKey(note.id);
    return NoteRow(
      id: note.id,
      folderId: note.folderId,
      title: note.title,
      content: note.content,
      preview: derivePreview(note.content),
      tagsJson: tagsToJson(note.tags),
      pinned: note.pinned,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt,
      deletedAt: note.deletedAt,
      revision: note.revision,
      syncStatus: note.syncStatus,
      lastEditedDeviceId: note.lastEditedDeviceId,
      wrappedKey: key,
      unreadable: false,
      rawPayload: null,
    );
  }

  /// Fila local de una carpeta.
  Future<FolderRow> folderRow(
    Folder folder,
    int revision, {
    FolderRow? previous,
    String? wrappedKey,
  }) async {
    if (previous != null && previous.unreadable) {
      return previous.copyWith(updatedAt: folder.updatedAt);
    }
    final key =
        wrappedKey ?? previous?.wrappedKey ?? await _newFolderKey(folder.id);
    return FolderRow(
      id: folder.id,
      name: folder.name,
      createdAt: folder.createdAt,
      updatedAt: folder.updatedAt,
      revision: revision,
      wrappedKey: key,
      unreadable: false,
      rawPayload: null,
    );
  }

  /// Fila local a partir de una nota remota cifrada. Si no se puede descifrar, la devuelve
  /// marcada como ilegible.
  Future<NoteRow> noteRowFromRemote(
    EncryptedNote enc,
    NoteSyncStatus status,
  ) async {
    try {
      final note = await openNote(enc, status);
      return await noteRow(note, wrappedKey: enc.wrappedKey);
    } on _Unreadable {
      return unreadableNoteRow(enc, status);
    } on crypto.DecryptError {
      return unreadableNoteRow(enc, status);
    } on crypto.CryptoFormatError {
      return unreadableNoteRow(enc, status);
    }
  }

  /// Fila local a partir de una carpeta remota cifrada (o ilegible).
  Future<FolderRow> folderRowFromRemote(EncryptedFolder enc) async {
    try {
      final folder = await openFolder(enc);
      return await folderRow(folder, enc.revision, wrappedKey: enc.wrappedKey);
    } on _Unreadable {
      return unreadableFolderRow(enc);
    } on crypto.DecryptError {
      return unreadableFolderRow(enc);
    } on crypto.CryptoFormatError {
      return unreadableFolderRow(enc);
    }
  }

  /// Descifra una nota remota. Lanza `_Unreadable` si el texto no se puede abrir.
  Future<Note> openNote(EncryptedNote enc, NoteSyncStatus status) async {
    final key = await _itemKey(ItemEntity.note, enc.id, enc.wrappedKey);
    final crypto.NotePayload payload;
    try {
      payload = await crypto.openNotePayload(
        key,
        enc.payload,
        _vault.dataAad(ItemEntity.note, enc.id),
      );
    } on crypto.DecryptError {
      throw const _Unreadable();
    } on crypto.CryptoFormatError {
      throw const _Unreadable();
    }
    return Note(
      id: enc.id,
      folderId: enc.folderId,
      title: payload.title,
      content: payload.content,
      tags: List<String>.of(payload.tags),
      pinned: payload.pinned,
      createdAt: enc.createdAt,
      updatedAt: enc.updatedAt,
      deletedAt: enc.deletedAt,
      revision: enc.revision,
      syncStatus: status,
      lastEditedDeviceId: enc.lastEditedDeviceId,
    );
  }

  /// Descifra una carpeta remota. Lanza `_Unreadable` si el texto no se puede abrir.
  Future<Folder> openFolder(EncryptedFolder enc) async {
    final key = await _itemKey(ItemEntity.folder, enc.id, enc.wrappedKey);
    final crypto.FolderPayload payload;
    try {
      payload = await crypto.openFolderPayload(
        key,
        enc.payload,
        _vault.dataAad(ItemEntity.folder, enc.id),
      );
    } on crypto.DecryptError {
      throw const _Unreadable();
    } on crypto.CryptoFormatError {
      throw const _Unreadable();
    }
    return Folder(
      id: enc.id,
      name: payload.name,
      createdAt: enc.createdAt,
      updatedAt: enc.updatedAt,
    );
  }

  /// Cifra una nota desde su fila actual, para subirla. Si es ilegible, devuelve su texto cifrado
  /// original (no se vuelve a subir contenido, A6).
  Future<({String wrappedKey, String payload})> sealNoteForUpload(
    NoteRow row,
  ) async {
    if (row.unreadable) {
      return (wrappedKey: row.wrappedKey, payload: row.rawPayload ?? '');
    }
    final key = await _itemKey(ItemEntity.note, row.id, row.wrappedKey);
    final payload = await crypto.sealNotePayload(
      key,
      crypto.NotePayload(
        title: row.title,
        content: row.content,
        tags: row.tags,
        pinned: row.pinned,
      ),
      _vault.dataAad(ItemEntity.note, row.id),
    );
    return (wrappedKey: row.wrappedKey, payload: payload);
  }

  /// Cifra una carpeta desde su fila actual, para subirla.
  Future<({String wrappedKey, String payload})> sealFolderForUpload(
    FolderRow row,
  ) async {
    if (row.unreadable) {
      return (wrappedKey: row.wrappedKey, payload: row.rawPayload ?? '');
    }
    final key = await _itemKey(ItemEntity.folder, row.id, row.wrappedKey);
    final payload = await crypto.sealFolderPayload(
      key,
      crypto.FolderPayload(name: row.name),
      _vault.dataAad(ItemEntity.folder, row.id),
    );
    return (wrappedKey: row.wrappedKey, payload: payload);
  }

  /// Fila «Nota ilegible» (marcador sin contenido).
  NoteRow unreadableNoteRow(EncryptedNote enc, NoteSyncStatus status) =>
      NoteRow(
        id: enc.id,
        folderId: enc.folderId,
        title: 'Nota ilegible',
        content: '',
        preview: '',
        tagsJson: tagsToJson(const []),
        pinned: false,
        createdAt: enc.createdAt,
        updatedAt: enc.updatedAt,
        deletedAt: enc.deletedAt,
        revision: enc.revision,
        syncStatus: status,
        lastEditedDeviceId: enc.lastEditedDeviceId,
        wrappedKey: enc.wrappedKey,
        unreadable: true,
        rawPayload: enc.payload,
      );

  /// Fila «Carpeta ilegible».
  FolderRow unreadableFolderRow(EncryptedFolder enc) => FolderRow(
    id: enc.id,
    name: 'Carpeta ilegible',
    createdAt: enc.createdAt,
    updatedAt: enc.updatedAt,
    revision: enc.revision,
    wrappedKey: enc.wrappedKey,
    unreadable: true,
    rawPayload: enc.payload,
  );

  Future<String> _newNoteKey(String id) async {
    try {
      return (await _vault.newItemKey(ItemEntity.note, id)).wrapped;
    } on VaultLockedError {
      failLocked();
    }
  }

  Future<String> _newFolderKey(String id) async {
    try {
      return (await _vault.newItemKey(ItemEntity.folder, id)).wrapped;
    } on VaultLockedError {
      failLocked();
    }
  }

  Future<crypto.SecretKeyBytes> _itemKey(
    ItemEntity entity,
    String id,
    String wrapped,
  ) async {
    try {
      return await _vault.itemKey(entity, id, wrapped);
    } on VaultLockedError {
      failLocked();
    }
  }
}

/// Marca interna: el texto no se pudo abrir (dato alterado o clave que no corresponde).
class _Unreadable implements Exception {
  const _Unreadable();
}
