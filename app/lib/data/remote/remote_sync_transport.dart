import 'package:axonote_api/axonote_api.dart' as api;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';

/// Adaptador `SyncTransport` sobre `SyncApi` (`axonote_api`): traduce entre los tipos de dominio
/// que usa el motor de sincronización (`axonote_sync`, fase 7) y los DTO del contrato.
///
/// Las fechas que **suben** (`EncryptedNoteFields`/`EncryptedFolderFields`) ya son el texto ISO
/// tal cual lo guarda la base local (`IsoDate = String`, plan §6): se copian al JSON sin pasar por
/// `DateTime`, así que no hay ningún redondeo posible. Las que **bajan** llegan en el DTO como
/// `DateTime` (la fase 4 las parsea así); aquí se devuelven a texto con `isoFromDateTime`, que
/// reproduce el mismo formato que usa el servidor (UTC, milisegundos, sufijo `Z`) — ver la prueba
/// de ida y vuelta en `remote_sync_transport_test.dart`.
///
/// `deviceId`/`deviceName` son del dispositivo local (los mismos que usa `LocalDatabase`, para que
/// los conflictos muestren el mismo nombre que la base local).
class RemoteSyncTransport implements SyncTransport {
  RemoteSyncTransport(
    this._api, {
    required this.deviceId,
    required this.deviceName,
  });

  final api.SyncApi _api;
  final String deviceId;
  final String deviceName;

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    final dto = await _api.sync(
      api.SyncRequestDto(
        deviceId: deviceId,
        deviceName: deviceName,
        cursor: request.cursor,
        changes: [for (final entry in request.changes) _changeDto(entry)],
      ),
    );
    return SyncResponse(
      cursor: dto.cursor,
      hasMore: dto.hasMore ?? false,
      applied: [for (final a in dto.applied) _appliedChange(a)],
      conflicts: [for (final c in dto.conflicts) _conflictReport(c)],
      remoteChanges: [for (final rc in dto.remoteChanges) _remoteChange(rc)],
    );
  }

  // ── petición: dominio → DTO ────────────────────────────────────────────────────────────────

  api.SyncChangeDto _changeDto(OutboxEntry entry) => api.SyncChangeDto(
    entity: _apiEntity(entry.entity),
    id: entry.entityId,
    op: _apiOp(entry.op),
    baseRevision: entry.baseRevision,
    data: entry.op == SyncOp.upsert ? _data(entry) : null,
  );

  Map<String, Object?> _data(OutboxEntry entry) {
    if (entry.entity == SyncEntity.note) {
      final fields = entry.noteData!;
      return <String, Object?>{
        'folderId': fields.folderId,
        'createdAt': fields.createdAt,
        'updatedAt': fields.updatedAt,
        'deletedAt': fields.deletedAt,
        'wrappedKey': fields.wrappedKey,
        'payload': fields.payload,
      };
    }
    final fields = entry.folderData!;
    return <String, Object?>{
      'createdAt': fields.createdAt,
      'updatedAt': fields.updatedAt,
      'wrappedKey': fields.wrappedKey,
      'payload': fields.payload,
    };
  }

  api.SyncEntity _apiEntity(SyncEntity entity) => switch (entity) {
    SyncEntity.note => api.SyncEntity.note,
    SyncEntity.folder => api.SyncEntity.folder,
  };

  api.SyncOp _apiOp(SyncOp op) => switch (op) {
    SyncOp.upsert => api.SyncOp.upsert,
    SyncOp.delete => api.SyncOp.delete,
  };

  // ── respuesta: DTO → dominio ───────────────────────────────────────────────────────────────

  SyncEntity _entity(api.SyncEntity entity) => switch (entity) {
    api.SyncEntity.note => SyncEntity.note,
    api.SyncEntity.folder => SyncEntity.folder,
  };

  AppliedChange _appliedChange(api.SyncAppliedDto dto) => AppliedChange(
    entity: _entity(dto.entity),
    id: dto.id,
    revision: dto.revision,
  );

  ConflictReport _conflictReport(api.SyncConflictReportDto dto) =>
      ConflictReport(
        noteId: dto.noteId,
        remote: _note(dto.remote),
        remoteDeviceName: dto.remoteDeviceName,
      );

  RemoteChange _remoteChange(api.SyncRemoteChangeDto dto) => RemoteChange(
    entity: _entity(dto.entity),
    id: dto.id,
    deleted: dto.deleted,
    revision: dto.revision,
    note: dto.note == null ? null : _note(dto.note!),
    folder: dto.folder == null ? null : _folder(dto.folder!),
  );

  EncryptedNote _note(api.EncryptedNoteDto dto) => EncryptedNote(
    id: dto.id,
    folderId: dto.folderId,
    createdAt: isoFromDateTime(dto.createdAt),
    updatedAt: isoFromDateTime(dto.updatedAt),
    deletedAt: dto.deletedAt == null ? null : isoFromDateTime(dto.deletedAt!),
    revision: dto.revision,
    lastEditedDeviceId: dto.lastEditedDeviceId,
    wrappedKey: dto.wrappedKey,
    payload: dto.payload,
  );

  EncryptedFolder _folder(api.EncryptedFolderDto dto) => EncryptedFolder(
    id: dto.id,
    createdAt: isoFromDateTime(dto.createdAt),
    updatedAt: isoFromDateTime(dto.updatedAt),
    revision: dto.revision,
    wrappedKey: dto.wrappedKey,
    payload: dto.payload,
  );
}
