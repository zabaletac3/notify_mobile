import 'dart:async';

import 'package:axonote_domain/axonote_domain.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;

import 'failures.dart';
import 'fts.dart';
import 'local_deps.dart';
import 'outbox.dart';
import 'rows.dart';

/// Notas guardadas en local (drift), con el contenido en claro dentro de una base cifrada. Cada
/// escritura deja una entrada en la cola para subirla (plan §6). Reglas portadas de
/// `notify_web/src/lib/data/local/local-note-repository.ts`.
class LocalNoteRepository implements NoteRepository {
  LocalNoteRepository(this._d) : _outbox = Outbox(_d.sync);

  final LocalDeps _d;
  final Outbox _outbox;

  String _iso() => isoFromDateTime(_d.now());

  Note _touch(Note note) => note.copyWith(
    updatedAt: _iso(),
    syncStatus: note.syncStatus == NoteSyncStatus.conflict
        ? NoteSyncStatus.conflict
        : NoteSyncStatus.pending,
    lastEditedDeviceId: _d.deviceId,
  );

  Future<NoteRow> _requireRow(String id) async {
    final row = await _d.notes.byId(id);
    if (row == null) failNotFound('note');
    return row;
  }

  /// Cifra (solo la clave) y guarda la nota, y apunta el cambio. Todo dentro del mismo candado.
  Future<Note> _save(Note note, {String? wrappedKey, NoteRow? previous}) async {
    final row = await _d.codec.noteRow(
      note,
      previous: previous,
      wrappedKey: wrappedKey,
    );
    await _d.db.transaction(() async {
      await _d.notes.upsert(row);
      await _outbox.enqueue(
        entity: SyncEntity.note,
        entityId: row.id,
        op: SyncOp.upsert,
        baseRevision: row.revision,
        changedAt: _iso(),
      );
    });
    return note;
  }

  /// La papelera se vacía sola a los 30 días. Debe ir dentro del candado, sin abrir transacción
  /// anidada.
  Future<void> _purgeExpired() async {
    final limit = isoFromDateTime(
      _d.now().subtract(const Duration(days: trashRetentionDays)),
    );
    final expired = await _d.notes.expired(limit);
    if (expired.isEmpty) return;
    await _d.db.transaction(() async {
      for (final row in expired) {
        await _remove(row);
      }
    });
  }

  /// Borra la fila local y avisa al servidor. Dentro de una transacción.
  Future<void> _remove(NoteRow row) async {
    await _d.notes.delete(row.id);
    await _d.sync.deleteConflict(row.id);
    await _outbox.enqueue(
      entity: SyncEntity.note,
      entityId: row.id,
      op: SyncOp.delete,
      baseRevision: row.revision,
      changedAt: _iso(),
    );
  }

  @override
  Future<List<Note>> list([NoteQuery query = const NoteQuery()]) =>
      _d.lock.run(() async {
        await _purgeExpired();
        final rows = await _d.notes.query(query);
        return [for (final row in rows) row.toNote()];
      });

  @override
  Stream<List<Note>> watch([NoteQuery query = const NoteQuery()]) {
    late final StreamController<List<Note>> controller;
    StreamSubscription<void>? subscription;
    Future<void> emit() async {
      if (!controller.isClosed) controller.add(await list(query));
    }

    controller = StreamController<List<Note>>(
      onListen: () async {
        await emit();
        subscription = _d.db
            .tableUpdates(const TableUpdateQuery.any())
            .where((updates) => updates.any((u) => u.table == 'notes'))
            .listen((_) => unawaited(emit()));
      },
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
      },
    );
    return controller.stream;
  }

  @override
  Future<Note> get(String id) =>
      _d.lock.run(() async => (await _requireRow(id)).toNote());

  /// Búsqueda local por FTS5 (prefijos, sin distinguir tildes).
  @override
  Future<List<Note>> search(
    String term, [
    NoteQuery query = const NoteQuery(),
  ]) => _d.lock.run(() async {
    final match = ftsMatch(term);
    if (match == null) return <Note>[];
    final rows = await _d.notes.search(match, limit: query.limit);
    return [for (final row in rows) row.toNote()];
  });

  @override
  Future<Note> create([NoteDraft draft = const NoteDraft()]) =>
      _d.lock.run(() async {
        final now = _iso();
        return _save(
          Note(
            id: newId(_d.now().millisecondsSinceEpoch),
            folderId: draft.folderId,
            title: draft.title ?? '',
            content: draft.content ?? '',
            tags: _normalizedTags(draft.tags ?? const []),
            pinned: draft.pinned ?? false,
            createdAt: now,
            updatedAt: now,
            deletedAt: null,
            revision: 0,
            syncStatus: NoteSyncStatus.pending,
            lastEditedDeviceId: _d.deviceId,
          ),
        );
      });

  @override
  Future<Note> update(String id, NoteDraft patch) => _d.lock.run(() async {
    final row = await _requireRow(id);
    final note = row.toNote();
    if (note.deletedAt != null) failValidation({'note': 'in-trash'});
    // De una nota ilegible solo se puede cambiar la carpeta.
    if (note.unreadable &&
        (patch.title != null ||
            patch.content != null ||
            patch.tags != null ||
            patch.pinned != null)) {
      failDecrypt();
    }
    var next = note;
    if (patch.title != null) next = next.copyWith(title: patch.title);
    if (patch.content != null) next = next.copyWith(content: patch.content);
    if (patch.folderIdPresent) {
      if (patch.folderId != null &&
          (await _d.folders.byId(patch.folderId!)) == null) {
        failNotFound('folder');
      }
      next = next.copyWith(folderId: patch.folderId);
    }
    if (patch.tags != null) {
      next = next.copyWith(tags: _normalizedTags(patch.tags!));
    }
    if (patch.pinned != null) next = next.copyWith(pinned: patch.pinned);
    return _save(_touch(next), wrappedKey: row.wrappedKey, previous: row);
  });

  @override
  Future<Note> duplicate(String id) => _d.lock.run(() async {
    final row = await _requireRow(id);
    final src = row.toNote();
    if (src.unreadable) failDecrypt();
    final now = _iso();
    // La copia es otra nota: sin `wrappedKey`, para que lleve su propia clave.
    return _save(
      src.copyWith(
        id: newId(_d.now().millisecondsSinceEpoch),
        title: '${src.title} (copia)',
        pinned: false,
        createdAt: now,
        updatedAt: now,
        revision: 0,
        syncStatus: NoteSyncStatus.pending,
        lastEditedDeviceId: _d.deviceId,
      ),
    );
  });

  @override
  Future<Note> moveToTrash(String id) => _d.lock.run(() async {
    final row = await _requireRow(id);
    return _save(
      _touch(row.toNote().copyWith(deletedAt: _iso(), pinned: false)),
      wrappedKey: row.wrappedKey,
      previous: row,
    );
  });

  @override
  Future<Note> restore(String id) => _d.lock.run(() async {
    final row = await _requireRow(id);
    return _save(
      _touch(row.toNote().copyWith(deletedAt: null)),
      wrappedKey: row.wrappedKey,
      previous: row,
    );
  });

  @override
  Future<void> deleteForever(String id) => _d.lock.run(() async {
    final row = await _requireRow(id);
    await _d.db.transaction(() => _remove(row));
  });

  @override
  Future<int> emptyTrash() => _d.lock.run(() async {
    final trashed = await _d.notes.trashed();
    if (trashed.isEmpty) return 0;
    await _d.db.transaction(() async {
      for (final row in trashed) {
        await _remove(row);
      }
    });
    return trashed.length;
  });

  @override
  Future<NoteCounts> counts() => _d.lock.run(() async {
    final byFolder = await _d.notes.countByFolder();
    final byTag = await _d.notes.countByTag();
    return NoteCounts(
      all: await _d.notes.countWhere('deleted_at IS NULL'),
      pinned: await _d.notes.countWhere('deleted_at IS NULL AND pinned = 1'),
      trash: await _d.notes.countWhere('deleted_at IS NOT NULL'),
      unfiled: await _d.notes.countWhere(
        'deleted_at IS NULL AND folder_id IS NULL',
      ),
      byFolder: byFolder,
      byTag: byTag,
    );
  });

  List<String> _normalizedTags(List<String> tags) => {
    for (final tag in tags.map(normalizeTag))
      if (tag.isNotEmpty) tag,
  }.toList();
}
