import 'ids.dart';

/// Entidad de un cambio de sincronización (`SyncChange.entity`).
enum SyncEntity {
  note('note'),
  folder('folder');

  const SyncEntity(this.wire);

  final String wire;

  static SyncEntity fromWire(String value) => values.firstWhere(
    (e) => e.wire == value,
    orElse: () => throw ArgumentError('entidad desconocida: $value'),
  );
}

/// Operación de un cambio de sincronización (`SyncChange.op`).
enum SyncOp {
  upsert('upsert'),
  delete('delete');

  const SyncOp(this.wire);

  final String wire;
}

/// Una nota tal como la guarda el servidor: metadatos y dos textos cifrados.
class EncryptedNote {
  const EncryptedNote({
    required this.id,
    required this.folderId,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.revision,
    required this.lastEditedDeviceId,
    required this.wrappedKey,
    required this.payload,
  });

  final Id id;
  final Id? folderId;
  final IsoDate createdAt;
  final IsoDate updatedAt;
  final IsoDate? deletedAt;
  final int revision;
  final Id lastEditedDeviceId;
  final String wrappedKey;
  final String payload;
}

/// Una carpeta tal como la guarda el servidor.
class EncryptedFolder {
  const EncryptedFolder({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.wrappedKey,
    required this.payload,
  });

  final Id id;
  final IsoDate createdAt;
  final IsoDate updatedAt;
  final int revision;
  final String wrappedKey;
  final String payload;
}

/// Campos de una nota cifrada que viajan en un `upsert`.
class EncryptedNoteFields {
  const EncryptedNoteFields({
    required this.folderId,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.wrappedKey,
    required this.payload,
  });

  final Id? folderId;
  final IsoDate createdAt;
  final IsoDate updatedAt;
  final IsoDate? deletedAt;
  final String wrappedKey;
  final String payload;

  static EncryptedNoteFields fromNote(EncryptedNote n) => EncryptedNoteFields(
    folderId: n.folderId,
    createdAt: n.createdAt,
    updatedAt: n.updatedAt,
    deletedAt: n.deletedAt,
    wrappedKey: n.wrappedKey,
    payload: n.payload,
  );
}

/// Campos de una carpeta cifrada que viajan en un `upsert`.
class EncryptedFolderFields {
  const EncryptedFolderFields({
    required this.createdAt,
    required this.updatedAt,
    required this.wrappedKey,
    required this.payload,
  });

  final IsoDate createdAt;
  final IsoDate updatedAt;
  final String wrappedKey;
  final String payload;

  static EncryptedFolderFields fromFolder(EncryptedFolder f) =>
      EncryptedFolderFields(
        createdAt: f.createdAt,
        updatedAt: f.updatedAt,
        wrappedKey: f.wrappedKey,
        payload: f.payload,
      );
}

/// Un cambio que aún no se subió (fila de la cola).
class OutboxEntry {
  const OutboxEntry({
    required this.seq,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.baseRevision,
    required this.version,
    required this.changedAt,
    this.noteData,
    this.folderData,
  });

  final int seq;
  final SyncEntity entity;
  final Id entityId;
  final SyncOp op;
  final int baseRevision;
  final EncryptedNoteFields? noteData;
  final EncryptedFolderFields? folderData;
  final int version;
  final IsoDate changedAt;
}

/// Un cambio nuevo que se quiere apuntar a la cola (sin `seq` ni `version`: los pone el almacén).
class PendingChange {
  const PendingChange({
    required this.entity,
    required this.entityId,
    required this.op,
    required this.baseRevision,
    this.noteData,
    this.folderData,
  });

  final SyncEntity entity;
  final Id entityId;
  final SyncOp op;
  final int baseRevision;
  final EncryptedNoteFields? noteData;
  final EncryptedFolderFields? folderData;
}

/// Nota con edición local y remota a la vez, pendiente de que la persona elija.
class ConflictRow {
  const ConflictRow({
    required this.noteId,
    required this.remote,
    required this.remoteDeviceName,
    required this.detectedAt,
  });

  final Id noteId;
  final EncryptedNote remote;
  final String remoteDeviceName;
  final IsoDate detectedAt;
}

/// Un enlace público guardado en local (plan §6). La clave del enlace va cifrada con la maestra.
class ShareRow {
  const ShareRow({
    required this.noteId,
    required this.slug,
    required this.wrappedShareKey,
    required this.createdAt,
    required this.updatedAt,
  });

  final Id noteId;
  final String slug;
  final String wrappedShareKey;
  final IsoDate createdAt;
  final IsoDate updatedAt;
}

/// Un cambio del cliente que el servidor aceptó.
class AppliedChange {
  const AppliedChange({
    required this.entity,
    required this.id,
    required this.revision,
  });

  final SyncEntity entity;
  final Id id;
  final int revision;
}

/// Algo que cambió en el servidor desde el cursor. [deleted] es una lápida.
class RemoteChange {
  const RemoteChange({
    required this.entity,
    required this.id,
    required this.deleted,
    required this.revision,
    this.note,
    this.folder,
  });

  final SyncEntity entity;
  final Id id;
  final bool deleted;
  final int revision;
  final EncryptedNote? note;
  final EncryptedFolder? folder;
}

/// Una nota cuyo `baseRevision` no coincide. El servidor no la modifica.
class ConflictReport {
  const ConflictReport({
    required this.noteId,
    required this.remote,
    required this.remoteDeviceName,
  });

  final Id noteId;
  final EncryptedNote remote;
  final String remoteDeviceName;
}

/// Clave estable de una entrada de la cola (`entity:id`).
String outboxKey(SyncEntity entity, Id id) => '${entity.wire}:$id';
