import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shadow_sealer.dart';

/// Reloj fijo del motor para las pruebas de vectores: todo `lastSyncedAt` queda en el instante
/// que fija `sync-behavior-vectors.ts` al generarlos.
class FixedSyncClock implements SyncClock {
  const FixedSyncClock(this._now);

  final String _now;

  @override
  String now() => _now;
}

typedef EditHook = Future<void> Function();

/// `SyncTransport` guionizado: reproduce un paso `sync`/`editDuringSync` de
/// `sync-behavior.json`. Cada llamada a [sync] comprueba la petición contra el intercambio
/// grabado, aplica el gancho de edición si le toca a este intercambio (`editDuringSync`: la
/// edición ocurre justo cuando la petición está «en vuelo», antes de que la respuesta vuelva al
/// motor — igual que `editDuringSync` en `sync-behavior-vectors.ts`) y devuelve la respuesta
/// grabada, ya con sus notas y carpetas remotas cifradas de verdad ([ShadowSealer]).
class ScriptedSyncTransport implements SyncTransport {
  ScriptedSyncTransport({
    required this.exchanges,
    required this.shadow,
    this.editIndex,
    this.editHook,
  });

  final List<Map<String, Object?>> exchanges;
  final ShadowSealer shadow;
  final int? editIndex;
  final EditHook? editHook;
  int _next = 0;

  /// Cuántos intercambios se consumieron de verdad; al final de un paso debe igualar
  /// `exchanges.length` (ninguno de más, ninguno de menos).
  int get consumed => _next;

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    final index = _next;
    if (index >= exchanges.length) {
      throw StateError(
        'el motor pidió más páginas (${index + 1}) de las grabadas (${exchanges.length})',
      );
    }
    final exchange = exchanges[index];
    _assertRequest(
      (exchange['request']! as Map).cast<String, Object?>(),
      request,
    );
    final response = await _buildResponse(
      (exchange['response']! as Map).cast<String, Object?>(),
      shadow,
    );
    if (editIndex == index && editHook != null) {
      await editHook!();
    }
    _next++;
    return response;
  }
}

void _assertRequest(Map<String, Object?> expected, SyncRequest actual) {
  expect(actual.cursor, expected['cursor']);
  final expectedChanges = (expected['changes']! as List)
      .cast<Map<String, Object?>>()
      .toList();
  expect(
    actual.changes,
    hasLength(expectedChanges.length),
    reason: 'cambios subidos distintos de los grabados',
  );
  for (var i = 0; i < expectedChanges.length; i++) {
    final e = expectedChanges[i];
    final a = actual.changes[i];
    expect(a.entity.wire, e['entity']);
    expect(a.entityId, e['id']);
    expect(a.op.wire, e['op']);
    expect(a.baseRevision, e['baseRevision']);
  }
}

Future<SyncResponse> _buildResponse(
  Map<String, Object?> json,
  ShadowSealer shadow,
) async {
  final applied = [
    for (final a in (json['applied']! as List).cast<Map<String, Object?>>())
      AppliedChange(
        entity: _entity(a['entity']! as String),
        id: a['id']! as String,
        revision: a['revision']! as int,
      ),
  ];

  final remoteChangesJson = (json['remoteChanges']! as List)
      .cast<Map<String, Object?>>()
      .toList();
  final remoteChanges = <RemoteChange>[];
  for (final rc in remoteChangesJson) {
    EncryptedNote? note;
    EncryptedFolder? folder;
    final noteJson = rc['note'];
    if (noteJson != null) {
      final n = (noteJson as Map).cast<String, Object?>();
      note = await shadow.note(
        id: n['id']! as String,
        title: n['title']! as String,
        content: n['content']! as String,
        folderId: n['folderId'] as String?,
        revision: n['revision']! as int,
        deletedAt: n['deletedAt'] as String?,
      );
    }
    final folderJson = rc['folder'];
    if (folderJson != null) {
      final f = (folderJson as Map).cast<String, Object?>();
      folder = await shadow.folder(
        id: f['id']! as String,
        name: f['name']! as String,
        revision: f['revision']! as int,
      );
    }
    remoteChanges.add(
      RemoteChange(
        entity: _entity(rc['entity']! as String),
        id: rc['id']! as String,
        deleted: rc['deleted']! as bool,
        revision: rc['revision']! as int,
        note: note,
        folder: folder,
      ),
    );
  }

  final conflicts = <ConflictReport>[];
  for (final cc in (json['conflicts']! as List).cast<Map<String, Object?>>()) {
    final noteId = cc['noteId']! as String;
    final remoteJson = (cc['remote']! as Map).cast<String, Object?>();
    // El vector solo guarda título/texto en `conflicts[].remote` (ver README); el resto de
    // campos del `EncryptedNote` (carpeta, revisión, lápida) vienen del `remoteChanges` de la
    // misma respuesta: todo escenario que trae un conflicto trae también su acompañante con el
    // mismo id (comprobado sobre los 19 escenarios).
    final companion = remoteChangesJson.firstWhere(
      (m) => m['entity'] == 'note' && m['id'] == noteId && m['note'] != null,
      orElse: () => throw StateError(
        'conflicto de $noteId sin su remoteChange acompañante en la misma respuesta',
      ),
    );
    final companionNote = (companion['note']! as Map).cast<String, Object?>();
    final remote = await shadow.note(
      id: noteId,
      title: remoteJson['title']! as String,
      content: remoteJson['content']! as String,
      folderId: companionNote['folderId'] as String?,
      revision: companionNote['revision']! as int,
      deletedAt: companionNote['deletedAt'] as String?,
    );
    conflicts.add(
      ConflictReport(
        noteId: noteId,
        remote: remote,
        remoteDeviceName: cc['remoteDeviceName']! as String,
      ),
    );
  }

  return SyncResponse(
    cursor: json['cursor']! as String,
    hasMore: json['hasMore']! as bool,
    applied: applied,
    conflicts: conflicts,
    remoteChanges: remoteChanges,
  );
}

SyncEntity _entity(String wire) =>
    wire == 'note' ? SyncEntity.note : SyncEntity.folder;
