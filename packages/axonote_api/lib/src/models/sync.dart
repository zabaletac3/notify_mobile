import '../json.dart';
import 'common.dart';

/// Una nota tal como la guarda el servidor: metadatos y dos textos cifrados.
class EncryptedNoteDto {
  const EncryptedNoteDto({
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

  factory EncryptedNoteDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return EncryptedNoteDto(
      id: r.child('id').asString(),
      folderId: r.child('folderId').asNullableString(),
      createdAt: r.child('createdAt').asDateTime(),
      updatedAt: r.child('updatedAt').asDateTime(),
      deletedAt: r.child('deletedAt').asNullableDateTime(),
      revision: r.child('revision').asInt(),
      lastEditedDeviceId: r.child('lastEditedDeviceId').asString(),
      wrappedKey: r.child('wrappedKey').asString(),
      payload: r.child('payload').asString(),
    );
  }

  final String id;
  final String? folderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String lastEditedDeviceId;
  final Sealed wrappedKey;
  final Sealed payload;
}

/// Página de notas cifradas (`GET /notes`).
class EncryptedNotePageDto {
  const EncryptedNotePageDto({required this.items, required this.nextCursor});

  factory EncryptedNotePageDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return EncryptedNotePageDto(
      items: [
        for (final item in r.child('items').asList())
          EncryptedNoteDto.fromJson(item.asMap()),
      ],
      nextCursor: r.child('nextCursor').asNullableString(),
    );
  }

  final List<EncryptedNoteDto> items;
  final String? nextCursor;
}

/// Una carpeta tal como la guarda el servidor.
class EncryptedFolderDto {
  const EncryptedFolderDto({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.wrappedKey,
    required this.payload,
  });

  factory EncryptedFolderDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return EncryptedFolderDto(
      id: r.child('id').asString(),
      createdAt: r.child('createdAt').asDateTime(),
      updatedAt: r.child('updatedAt').asDateTime(),
      revision: r.child('revision').asInt(),
      wrappedKey: r.child('wrappedKey').asString(),
      payload: r.child('payload').asString(),
    );
  }

  final String id;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;
  final Sealed wrappedKey;
  final Sealed payload;
}

/// Un cambio de nota o carpeta que el cliente sube en un `POST /sync`.
class SyncChangeDto {
  const SyncChangeDto({
    required this.entity,
    required this.id,
    required this.op,
    required this.baseRevision,
    this.data,
  });

  final SyncEntity entity;
  final String id;
  final SyncOp op;

  /// Revisión que el cliente conocía (0 si la creó sin conexión).
  final int baseRevision;

  /// Campos cifrados de la nota o carpeta (presente en `upsert`).
  final Map<String, Object?>? data;

  Map<String, Object?> toJson() => <String, Object?>{
    'entity': entity.wire,
    'id': id,
    'op': op.wire,
    'baseRevision': baseRevision,
    if (data != null) 'data': data,
  };
}

/// Cuerpo de `POST /sync`.
class SyncRequestDto {
  const SyncRequestDto({
    required this.deviceId,
    required this.deviceName,
    required this.changes,
    this.cursor,
  });

  final String deviceId;
  final String deviceName;

  /// Último cursor recibido; `null` descarga todo.
  final String? cursor;
  final List<SyncChangeDto> changes;

  Map<String, Object?> toJson() => <String, Object?>{
    'deviceId': deviceId,
    'deviceName': deviceName,
    'cursor': cursor,
    'changes': [for (final change in changes) change.toJson()],
  };
}

/// Un cambio del cliente que el servidor aceptó.
class SyncAppliedDto {
  const SyncAppliedDto({
    required this.entity,
    required this.id,
    required this.revision,
  });

  factory SyncAppliedDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return SyncAppliedDto(
      entity: enumFromWire(
        SyncEntity.values,
        (value) => value.wire,
        r.child('entity').asString(),
        'applied.entity',
      ),
      id: r.child('id').asString(),
      revision: r.child('revision').asInt(),
    );
  }

  final SyncEntity entity;
  final String id;
  final int revision;
}

/// Algo que cambió en el servidor desde el cursor. `deleted` es una lápida.
class SyncRemoteChangeDto {
  const SyncRemoteChangeDto({
    required this.entity,
    required this.id,
    required this.deleted,
    required this.revision,
    this.note,
    this.folder,
  });

  factory SyncRemoteChangeDto.fromJson(Object? json) {
    final r = JsonReader(json);
    final note = r.optional('note');
    final folder = r.optional('folder');
    return SyncRemoteChangeDto(
      entity: enumFromWire(
        SyncEntity.values,
        (value) => value.wire,
        r.child('entity').asString(),
        'remoteChange.entity',
      ),
      id: r.child('id').asString(),
      deleted: r.child('deleted').asBool(),
      revision: r.child('revision').asInt(),
      note: note == null ? null : EncryptedNoteDto.fromJson(note.asMap()),
      folder: folder == null
          ? null
          : EncryptedFolderDto.fromJson(folder.asMap()),
    );
  }

  final SyncEntity entity;
  final String id;
  final bool deleted;
  final int revision;
  final EncryptedNoteDto? note;
  final EncryptedFolderDto? folder;
}

/// Una nota cuyo `baseRevision` no coincide. El servidor no la modifica.
class SyncConflictReportDto {
  const SyncConflictReportDto({
    required this.noteId,
    required this.remote,
    required this.remoteDeviceName,
  });

  factory SyncConflictReportDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return SyncConflictReportDto(
      noteId: r.child('noteId').asString(),
      remote: EncryptedNoteDto.fromJson(r.child('remote').asMap()),
      remoteDeviceName: r.child('remoteDeviceName').asString(),
    );
  }

  final String noteId;
  final EncryptedNoteDto remote;
  final String remoteDeviceName;
}

/// Respuesta de `POST /sync`.
class SyncResponseDto {
  const SyncResponseDto({
    required this.cursor,
    required this.applied,
    required this.remoteChanges,
    required this.conflicts,
    this.hasMore,
  });

  factory SyncResponseDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return SyncResponseDto(
      cursor: r.child('cursor').asString(),
      hasMore: r.optional('hasMore')?.asBool(),
      applied: [
        for (final item in r.child('applied').asList())
          SyncAppliedDto.fromJson(item.asMap()),
      ],
      remoteChanges: [
        for (final item in r.child('remoteChanges').asList())
          SyncRemoteChangeDto.fromJson(item.asMap()),
      ],
      conflicts: [
        for (final item in r.child('conflicts').asList())
          SyncConflictReportDto.fromJson(item.asMap()),
      ],
    );
  }

  final String cursor;

  /// Hay más cambios remotos por bajar: repetir `POST /sync` con este cursor.
  final bool? hasMore;
  final List<SyncAppliedDto> applied;
  final List<SyncRemoteChangeDto> remoteChanges;
  final List<SyncConflictReportDto> conflicts;
}
