import 'dart:async';

import 'package:axonote_domain/axonote_domain.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;

import 'failures.dart';
import 'local_deps.dart';
import 'outbox.dart';
import 'rows.dart';

/// Carpetas guardadas en local (drift), con el nombre en claro dentro de una base cifrada.
/// Reglas portadas de `notify_web/src/lib/data/local/local-folder-repository.ts`.
class LocalFolderRepository implements FolderRepository {
  LocalFolderRepository(this._d) : _outbox = Outbox(_d.sync);

  final LocalDeps _d;
  final Outbox _outbox;

  String _iso() => isoFromDateTime(_d.now());

  Future<FolderRow> _requireRow(String id) async {
    final row = await _d.folders.byId(id);
    if (row == null) failNotFound('folder');
    return row;
  }

  Future<Folder> _save(
    Folder folder,
    int revision, {
    String? wrappedKey,
    FolderRow? previous,
  }) async {
    final row = await _d.codec.folderRow(
      folder,
      revision,
      wrappedKey: wrappedKey,
      previous: previous,
    );
    await _d.db.transaction(() async {
      await _d.folders.upsert(row);
      await _outbox.enqueue(
        entity: SyncEntity.folder,
        entityId: row.id,
        op: SyncOp.upsert,
        baseRevision: row.revision,
        changedAt: _iso(),
      );
    });
    return folder;
  }

  @override
  Future<List<Folder>> list() => _d.lock.run(() async {
    final rows = await _d.folders.all();
    final folders = [for (final row in rows) row.toFolder()];
    folders.sort((a, b) {
      final byCreated = a.createdAt.compareTo(b.createdAt);
      return byCreated != 0
          ? byCreated
          : foldText(a.name).compareTo(foldText(b.name));
    });
    return folders;
  });

  @override
  Stream<List<Folder>> watch() {
    late final StreamController<List<Folder>> controller;
    StreamSubscription<void>? subscription;
    Future<void> emit() async {
      if (!controller.isClosed) controller.add(await list());
    }

    controller = StreamController<List<Folder>>(
      onListen: () async {
        await emit();
        subscription = _d.db
            .tableUpdates(const TableUpdateQuery.any())
            .where((updates) => updates.any((u) => u.table == 'folders'))
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
  Future<Folder> create(String name) => _d.lock.run(() async {
    final existing = [for (final row in await _d.folders.all()) row.name];
    final check = validateFolderName(name, existing);
    if (check is Invalid) failValidation(check.errors);
    final now = _iso();
    final folder = Folder(
      id: newId(_d.now().millisecondsSinceEpoch),
      name: name.trim(),
      createdAt: now,
      updatedAt: now,
    );
    return _save(folder, 0);
  });

  @override
  Future<Folder> rename(String id, String name) => _d.lock.run(() async {
    final row = await _requireRow(id);
    if (row.unreadable) failDecrypt();
    final others = [
      for (final r in await _d.folders.all())
        if (r.id != id) r.name,
    ];
    final check = validateFolderName(name, others);
    if (check is Invalid) failValidation(check.errors);
    final next = row.toFolder().copyWith(name: name.trim(), updatedAt: _iso());
    return _save(next, row.revision, wrappedKey: row.wrappedKey, previous: row);
  });

  @override
  Future<void> delete(String id) => _d.lock.run(() async {
    final folder = await _requireRow(id);
    await _d.db.transaction(() async {
      await _d.folders.delete(id);
      await _outbox.enqueue(
        entity: SyncEntity.folder,
        entityId: id,
        op: SyncOp.delete,
        baseRevision: folder.revision,
        changedAt: _iso(),
      );
      // Sus notas pasan a «sin carpeta»; es un metadato, no hace falta descifrar nada.
      final affected = await _d.notes.byFolder(id);
      for (final note in affected) {
        final next = note.copyWith(
          clearFolderId: true,
          updatedAt: _iso(),
          syncStatus: note.syncStatus == NoteSyncStatus.conflict
              ? NoteSyncStatus.conflict
              : NoteSyncStatus.pending,
          lastEditedDeviceId: _d.deviceId,
        );
        await _d.notes.upsert(next);
        await _outbox.enqueue(
          entity: SyncEntity.note,
          entityId: note.id,
          op: SyncOp.upsert,
          baseRevision: note.revision,
          changedAt: _iso(),
        );
      }
    });
  });
}
