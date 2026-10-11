import 'package:axonote_domain/axonote_domain.dart';

import '../data/local/local_harness.dart';

/// Estado lógico observable del dispositivo bajo prueba, con las mismas claves que
/// `expected[]`/`initial` de `sync-behavior.json` (ver `contract/vectors/README.md` y
/// `sync-behavior-vectors.ts::state()`): nunca bytes cifrados, solo lo que un escenario compara.
Future<Map<String, Object?>> logicalState(LocalHarness h) async {
  return <String, Object?>{
    'notes': await _notes(h),
    'folders': await _folders(h),
    'outbox': await _outbox(h),
    'conflicts': await _conflicts(h),
    'cursor': await h.local.syncStore.cursor(),
    'lastSyncedAt': await h.local.syncStore.lastSyncedAt(),
    'pendingCount': await h.local.syncStore.pendingCount(),
  };
}

Future<List<Map<String, Object?>>> _notes(LocalHarness h) async {
  // `list()` devuelve resúmenes sin `content` (plan §4.4): hace falta `get(id)` para el texto.
  final active = await h.local.notes.list(
    const NoteQuery(filter: NotesFilterAll()),
  );
  final trash = await h.local.notes.list(
    const NoteQuery(filter: NotesFilterTrash()),
  );
  final notes = <Note>[];
  for (final summary in [...active, ...trash]) {
    notes.add(await h.local.notes.get(summary.id));
  }
  notes.sort((a, b) => a.id.compareTo(b.id));
  return [
    for (final n in notes)
      {
        'id': n.id,
        'title': n.title,
        'content': n.content,
        'revision': n.revision,
        'syncStatus': n.syncStatus.wire,
        'deleted': n.deletedAt != null,
        'folderId': n.folderId,
        'pinned': n.pinned,
      },
  ];
}

Future<List<Map<String, Object?>>> _folders(LocalHarness h) async {
  // La revisión no vive en la entidad `Folder` del dominio (solo en la fila local): se lee del
  // DAO, igual que el arnés de la web lee `db.folders` directamente en vez del repositorio.
  final rows = await h.local.deps.folders.all();
  final folders = [
    for (final row in rows)
      {'id': row.id, 'name': row.name, 'revision': row.revision},
  ];
  folders.sort((a, b) => (a['id']! as String).compareTo(b['id']! as String));
  return folders;
}

Future<List<Map<String, Object?>>> _outbox(LocalHarness h) async {
  final rows = await h.local.deps.sync.outbox();
  return [
    for (final row in rows)
      {
        'entity': row.entity,
        'entityId': row.entityId,
        'op': row.op,
        'baseRevision': row.baseRevision,
        'version': row.version,
      },
  ];
}

Future<List<Map<String, Object?>>> _conflicts(LocalHarness h) async {
  final conflicts = await h.local.syncStore.conflicts();
  return [
    for (final c in conflicts)
      {
        'noteId': c.noteId,
        'local': {
          'title': c.local.title,
          'content': c.local.content,
          'device': c.local.deviceName,
        },
        'remote': {
          'title': c.remote.title,
          'content': c.remote.content,
          'device': c.remote.deviceName,
        },
      },
  ];
}
