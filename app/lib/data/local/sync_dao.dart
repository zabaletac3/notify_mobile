import 'package:axonote_domain/axonote_domain.dart';
import 'package:drift/drift.dart';

import 'app_database.dart';
import 'encrypted_json.dart';

/// DAO de las tablas de sincronización: `outbox`, `conflicts`, `shares` y `meta`. Solo guarda
/// filas; la semántica de la cola y de aplicar la respuesta vive en `LocalSyncStore`.
class SyncDao {
  SyncDao(this._db);

  final AppDatabase _db;

  // ── outbox ──────────────────────────────────────────────────────────────────────────────────

  Future<Map<String, Object?>> outboxEntry(
    String entity,
    String entityId,
  ) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM outbox WHERE entity = ? AND entity_id = ? LIMIT 1',
          variables: [Variable<String>(entity), Variable<String>(entityId)],
        )
        .get();
    return rows.isEmpty ? const {} : rows.first.data;
  }

  Future<List<OutboxRow>> outbox() async {
    final rows = await _db
        .customSelect('SELECT * FROM outbox ORDER BY seq')
        .get();
    return [for (final row in rows) _outbox(row)];
  }

  /// Cambios pendientes en orden de `seq`, sin las notas que están en conflicto.
  Future<List<OutboxRow>> pending() async {
    final rows = await _db
        .customSelect(
          'SELECT o.* FROM outbox o WHERE NOT (o.entity = \'note\' AND EXISTS '
          '(SELECT 1 FROM conflicts c WHERE c.note_id = o.entity_id)) ORDER BY o.seq',
        )
        .get();
    return [for (final row in rows) _outbox(row)];
  }

  Future<int> outboxCount() async {
    final rows = await _db
        .customSelect('SELECT COUNT(*) AS c FROM outbox')
        .get();
    return rows.first.read<int>('c');
  }

  Future<int> insertOutbox(
    String entity,
    String entityId,
    String op,
    int baseRevision,
    int version,
    String changedAt,
  ) {
    return _db.customInsert(
      'INSERT INTO outbox(entity, entity_id, op, base_revision, version, changed_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      variables: [
        Variable<String>(entity),
        Variable<String>(entityId),
        Variable<String>(op),
        Variable<int>(baseRevision),
        Variable<int>(version),
        Variable<String>(changedAt),
      ],
    );
  }

  Future<void> updateOutbox(
    int seq,
    String op,
    int baseRevision,
    int version,
    String changedAt,
  ) async {
    await _db.customUpdate(
      'UPDATE outbox SET op = ?, base_revision = ?, version = ?, changed_at = ? WHERE seq = ?',
      variables: [
        Variable<String>(op),
        Variable<int>(baseRevision),
        Variable<int>(version),
        Variable<String>(changedAt),
        Variable<int>(seq),
      ],
    );
  }

  Future<void> deleteOutbox(int seq) async {
    await _db.customUpdate(
      'DELETE FROM outbox WHERE seq = ?',
      variables: [Variable<int>(seq)],
    );
  }

  // ── conflicts ───────────────────────────────────────────────────────────────────────────────

  Future<void> putConflict(ConflictRow conflict) async {
    await _db.customInsert(
      'INSERT INTO conflicts(note_id, remote_json, remote_wrapped_key, remote_revision, '
      'remote_device_name, detected_at) VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(note_id) DO UPDATE SET remote_json = excluded.remote_json, '
      'remote_wrapped_key = excluded.remote_wrapped_key, remote_revision = excluded.remote_revision, '
      'remote_device_name = excluded.remote_device_name, detected_at = excluded.detected_at',
      variables: [
        Variable<String>(conflict.noteId),
        Variable<String>(encodeEncryptedNote(conflict.remote)),
        Variable<String>(conflict.remote.wrappedKey),
        Variable<int>(conflict.remote.revision),
        Variable<String>(conflict.remoteDeviceName),
        Variable<String>(conflict.detectedAt),
      ],
    );
    _db.notifyUpdates({const TableUpdate('conflicts')});
  }

  Future<List<ConflictRow>> conflicts() async {
    final rows = await _db.customSelect('SELECT * FROM conflicts').get();
    return [for (final row in rows) _conflict(row)];
  }

  Future<ConflictRow?> conflict(String noteId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM conflicts WHERE note_id = ? LIMIT 1',
          variables: [Variable<String>(noteId)],
        )
        .get();
    return rows.isEmpty ? null : _conflict(rows.first);
  }

  Future<void> deleteConflict(String noteId) async {
    await _db.customUpdate(
      'DELETE FROM conflicts WHERE note_id = ?',
      variables: [Variable<String>(noteId)],
    );
    _db.notifyUpdates({const TableUpdate('conflicts')});
  }

  // ── shares ──────────────────────────────────────────────────────────────────────────────────

  Future<ShareRow?> share(String noteId) async {
    final rows = await _db
        .customSelect(
          'SELECT * FROM shares WHERE note_id = ? LIMIT 1',
          variables: [Variable<String>(noteId)],
        )
        .get();
    if (rows.isEmpty) return null;
    final row = rows.first;
    return ShareRow(
      noteId: row.read<String>('note_id'),
      slug: row.read<String>('slug'),
      wrappedShareKey: row.read<String>('wrapped_share_key'),
      createdAt: row.read<String>('created_at'),
      updatedAt: row.read<String>('updated_at'),
    );
  }

  Future<void> putShare(ShareRow share) async {
    await _db.customInsert(
      'INSERT INTO shares(note_id, slug, wrapped_share_key, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(note_id) DO UPDATE SET slug = excluded.slug, '
      'wrapped_share_key = excluded.wrapped_share_key, created_at = excluded.created_at, '
      'updated_at = excluded.updated_at',
      variables: [
        Variable<String>(share.noteId),
        Variable<String>(share.slug),
        Variable<String>(share.wrappedShareKey),
        Variable<String>(share.createdAt),
        Variable<String>(share.updatedAt),
      ],
    );
  }

  Future<void> deleteShare(String noteId) async {
    await _db.customUpdate(
      'DELETE FROM shares WHERE note_id = ?',
      variables: [Variable<String>(noteId)],
    );
  }

  // ── meta ────────────────────────────────────────────────────────────────────────────────────

  Future<String?> meta(String key) async {
    final rows = await _db
        .customSelect(
          'SELECT value FROM meta WHERE key = ? LIMIT 1',
          variables: [Variable<String>(key)],
        )
        .get();
    return rows.isEmpty ? null : rows.first.read<String?>('value');
  }

  Future<void> setMeta(String key, String? value) async {
    await _db.customInsert(
      'INSERT INTO meta(key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
      variables: [Variable<String>(key), Variable<String>(value)],
    );
  }

  OutboxRow _outbox(QueryRow row) => OutboxRow(
    seq: row.read<int>('seq'),
    entity: row.read<String>('entity'),
    entityId: row.read<String>('entity_id'),
    op: row.read<String>('op'),
    baseRevision: row.read<int>('base_revision'),
    version: row.read<int>('version'),
    changedAt: row.read<String>('changed_at'),
  );

  ConflictRow _conflict(QueryRow row) => ConflictRow(
    noteId: row.read<String>('note_id'),
    remote: decodeEncryptedNote(row.read<String>('remote_json')),
    remoteDeviceName: row.read<String>('remote_device_name'),
    detectedAt: row.read<String>('detected_at'),
  );
}

/// Fila de `outbox` (sin datos del elemento: la cola guarda solo referencias, A4).
class OutboxRow {
  const OutboxRow({
    required this.seq,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.baseRevision,
    required this.version,
    required this.changedAt,
  });

  final int seq;
  final String entity;
  final String entityId;
  final String op;
  final int baseRevision;
  final int version;
  final String changedAt;

  OutboxEntry toEntry() => OutboxEntry(
    seq: seq,
    entity: SyncEntity.fromWire(entity),
    entityId: entityId,
    op: op == 'delete' ? SyncOp.delete : SyncOp.upsert,
    baseRevision: baseRevision,
    version: version,
    changedAt: changedAt,
  );
}
