import 'package:axonote_domain/axonote_domain.dart';

import 'failures.dart';
import 'local_deps.dart';
import 'outbox.dart';
import 'rows.dart';

/// Almacén de sincronización sobre drift (plan §7). Porta la semántica de
/// `notify_web/src/lib/data/local/local-sync-repository.ts` (la parte de almacén: cursor, cola,
/// aplicar cambios remotos, conflictos y shares). El motor de sincronización es la fase 7.
class LocalSyncStore implements SyncStore {
  LocalSyncStore(this._d) : _outbox = Outbox(_d.sync);

  final LocalDeps _d;
  final Outbox _outbox;

  String _iso() => isoFromDateTime(_d.now());

  // ── cola ────────────────────────────────────────────────────────────────────────────────────

  @override
  Future<void> enqueue(PendingChange change, IsoDate changedAt) =>
      _outbox.enqueue(
        entity: change.entity,
        entityId: change.entityId,
        op: change.op,
        baseRevision: change.baseRevision,
        changedAt: changedAt,
      );

  @override
  Future<List<OutboxEntry>> pending() => _d.lock.run(
    () async => [for (final row in await _d.sync.pending()) row.toEntry()],
  );

  @override
  Future<int> pendingCount() => _d.lock.run(_d.sync.outboxCount);

  // ── meta ────────────────────────────────────────────────────────────────────────────────────

  @override
  Future<String?> cursor() => _d.lock.run(() => _d.sync.meta('cursor'));

  @override
  Future<IsoDate?> lastSyncedAt() =>
      _d.lock.run(() => _d.sync.meta('lastSyncedAt'));

  @override
  Future<String?> readMeta(String key) => _d.lock.run(() => _d.sync.meta(key));

  @override
  Future<void> writeMeta(String key, String? value) =>
      _d.lock.run(() => _d.sync.setMeta(key, value));

  // ── aplicar la respuesta del servidor ───────────────────────────────────────────────────────

  @override
  Future<void> applyResult({
    required List<OutboxEntry> sent,
    required List<AppliedChange> applied,
    required List<ConflictReport> conflicts,
    required List<RemoteChange> remoteChanges,
    required String cursor,
    required IsoDate now,
  }) => _d.lock.run(() async {
    final sentVersion = {
      for (final entry in sent)
        outboxKey(entry.entity, entry.entityId): entry.version,
    };
    // Descifrar los cambios remotos ANTES de abrir la transacción: mantener la escritura durante
    // el descifrado de una página de 500 elementos bloquearía la base demasiado tiempo. Seguimos
    // dentro del Mutex, así que nada local cambia entre medias. Si el cofre se bloquea aquí, no se
    // aplica nada.
    final remoteNoteRows = <String, NoteRow>{};
    final remoteFolderRows = <String, FolderRow>{};
    for (final ch in remoteChanges) {
      if (ch.deleted) continue;
      if (ch.entity == SyncEntity.note && ch.note != null) {
        remoteNoteRows[ch.id] = await _d.codec.noteRowFromRemote(
          ch.note!,
          NoteSyncStatus.synced,
        );
      } else if (ch.entity == SyncEntity.folder && ch.folder != null) {
        remoteFolderRows[ch.id] = await _d.codec.folderRowFromRemote(
          ch.folder!,
        );
      }
    }

    await _d.db.transaction(() async {
      // 1) Lo que el servidor aceptó.
      for (final a in applied) {
        final entry = await _d.sync.outboxEntry(a.entity.wire, a.id);
        final hasEntry = entry.isNotEmpty;
        final unchanged =
            hasEntry &&
            (entry['version']! as int) ==
                sentVersion[outboxKey(a.entity, a.id)];
        final editedWhileSyncing = hasEntry && !unchanged;
        if (a.entity == SyncEntity.note) {
          final row = await _d.notes.byId(a.id);
          if (row != null) {
            await _d.notes.upsert(
              row.copyWith(
                revision: a.revision,
                syncStatus: editedWhileSyncing
                    ? NoteSyncStatus.pending
                    : NoteSyncStatus.synced,
              ),
            );
          }
        } else {
          final row = await _d.folders.byId(a.id);
          if (row != null) {
            await _d.folders.upsert(row.copyWith(revision: a.revision));
          }
        }
        if (hasEntry) {
          final seq = entry['seq']! as int;
          if (unchanged) {
            await _d.sync.deleteOutbox(seq);
          } else {
            await _d.sync.updateOutbox(
              seq,
              entry['op']! as String,
              a.revision,
              entry['version']! as int,
              entry['changed_at']! as String,
            );
          }
        }
      }

      // 2) Conflictos: el servidor no aplicó el cambio.
      for (final c in conflicts) {
        await _d.sync.putConflict(
          ConflictRow(
            noteId: c.noteId,
            remote: c.remote,
            remoteDeviceName: c.remoteDeviceName,
            detectedAt: now,
          ),
        );
        final row = await _d.notes.byId(c.noteId);
        if (row != null) {
          await _d.notes.upsert(
            row.copyWith(syncStatus: NoteSyncStatus.conflict),
          );
        }
      }

      // 3) Lo que cambió en otros dispositivos.
      for (final ch in remoteChanges) {
        final pending = await _d.sync.outboxEntry(ch.entity.wire, ch.id);
        if (ch.entity == SyncEntity.note) {
          final conflict = await _d.sync.conflict(ch.id);
          if (conflict != null && ch.note != null) {
            await _d.sync.putConflict(
              ConflictRow(
                noteId: ch.id,
                remote: ch.note!,
                remoteDeviceName: conflict.remoteDeviceName,
                detectedAt: conflict.detectedAt,
              ),
            );
          }
          // Con un cambio local pendiente no se pisa: se resolverá al subirlo.
          if (pending.isNotEmpty) continue;
          if (ch.deleted) {
            await _d.notes.delete(ch.id);
            await _d.sync.deleteConflict(ch.id);
          } else if (ch.note != null) {
            await _d.notes.upsert(remoteNoteRows[ch.id]!);
          }
        } else {
          if (pending.isNotEmpty && !ch.deleted) continue;
          if (ch.deleted) {
            await _d.folders.delete(ch.id);
          } else if (ch.folder != null) {
            await _d.folders.upsert(remoteFolderRows[ch.id]!);
          }
        }
      }

      await _d.sync.setMeta('cursor', cursor);
      await _d.sync.setMeta('lastSyncedAt', now);
    });
  });

  // ── conflictos ──────────────────────────────────────────────────────────────────────────────

  @override
  Future<List<Conflict>> conflicts() => _d.lock.run(() async {
    final rows = await _d.sync.conflicts();
    final result = <Conflict>[];
    try {
      for (final row in rows) {
        final localRow = await _d.notes.byId(row.noteId);
        if (localRow == null) continue;
        final local = localRow.toNote();
        final remote = (await _d.codec.noteRowFromRemote(
          row.remote,
          NoteSyncStatus.synced,
        )).toNote();
        result.add(
          Conflict(
            noteId: row.noteId,
            local: NoteVersion(
              title: local.title,
              content: local.content,
              editedAt: local.updatedAt,
              deviceName: _d.deviceName,
            ),
            remote: NoteVersion(
              title: remote.title,
              content: remote.content,
              editedAt: remote.updatedAt,
              deviceName: row.remoteDeviceName,
            ),
          ),
        );
      }
    } on AppFailure catch (e) {
      if (e.kind == 'locked') return const [];
      rethrow;
    }
    return result;
  });

  @override
  Future<void> resolveConflict(Id noteId, ConflictResolution resolution) =>
      _d.lock.run(() async {
        final conflict = await _d.sync.conflict(noteId);
        final localRow = await _d.notes.byId(noteId);
        if (conflict == null || localRow == null) failNotFound('conflict');
        final now = _iso();
        final remoteRow = await _d.codec.noteRowFromRemote(
          conflict.remote,
          NoteSyncStatus.synced,
        );

        // Para «ambas» hay que cifrar la copia con una clave nueva: antes de la transacción.
        NoteRow? copy;
        if (resolution == ConflictResolution.both) {
          final mine = localRow.toNote();
          copy = await _d.codec.noteRow(
            mine.copyWith(
              id: newId(_d.now().millisecondsSinceEpoch),
              title: '${mine.title} (conflicto)',
              pinned: false,
              createdAt: now,
              updatedAt: now,
              revision: 0,
              syncStatus: NoteSyncStatus.pending,
              lastEditedDeviceId: _d.deviceId,
            ),
          );
        }

        await _d.db.transaction(() async {
          final pending = await _d.sync.outboxEntry('note', noteId);
          switch (resolution) {
            case ConflictResolution.remote:
              await _d.notes.upsert(remoteRow);
              if (pending.isNotEmpty) {
                await _d.sync.deleteOutbox(pending['seq']! as int);
              }
            case ConflictResolution.both:
              final created = copy!;
              await _d.notes.upsert(created);
              await _outbox.enqueue(
                entity: SyncEntity.note,
                entityId: created.id,
                op: SyncOp.upsert,
                baseRevision: 0,
                changedAt: now,
              );
              await _d.notes.upsert(remoteRow);
              if (pending.isNotEmpty) {
                await _d.sync.deleteOutbox(pending['seq']! as int);
              }
            case ConflictResolution.local:
              await _d.notes.upsert(
                localRow.copyWith(
                  revision: conflict.remote.revision,
                  syncStatus: NoteSyncStatus.pending,
                ),
              );
              if (pending.isNotEmpty) {
                await _d.sync.updateOutbox(
                  pending['seq']! as int,
                  pending['op']! as String,
                  conflict.remote.revision,
                  pending['version']! as int,
                  pending['changed_at']! as String,
                );
              }
          }
          await _d.sync.deleteConflict(noteId);
        });
      });

  // ── shares ──────────────────────────────────────────────────────────────────────────────────

  @override
  Future<ShareRow?> share(Id noteId) =>
      _d.lock.run(() => _d.sync.share(noteId));

  @override
  Future<void> upsertShare(ShareRow share) =>
      _d.lock.run(() => _d.sync.putShare(share));

  @override
  Future<void> deleteShare(Id noteId) =>
      _d.lock.run(() => _d.sync.deleteShare(noteId));
}
