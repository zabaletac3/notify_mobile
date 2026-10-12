import 'dart:async';

import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';

/// Fila interna del [FakeSyncStore]: igual forma que `OutboxRow` de `app/lib/data`, pero en
/// memoria (sin drift). Reproduce la semántica de `outbox.ts`/`SyncDao` lo justo para probar el
/// motor; las reglas de fusión de la cola ya están probadas a fondo en
/// `app/test/data/local/local_sync_store_test.dart` sobre el almacén real.
class _Row {
  _Row({
    required this.seq,
    required this.entity,
    required this.entityId,
    required this.op,
    required this.baseRevision,
    required this.version,
    required this.changedAt,
  });

  final int seq;
  final SyncEntity entity;
  final Id entityId;
  SyncOp op;
  int baseRevision;
  int version;
  String changedAt;

  OutboxEntry toEntry() => OutboxEntry(
    seq: seq,
    entity: entity,
    entityId: entityId,
    op: op,
    baseRevision: baseRevision,
    version: version,
    changedAt: changedAt,
  );
}

/// `SyncStore` en memoria para las pruebas del motor (no del almacén: eso ya lo cubre la fase 6
/// sobre drift real). Implementa lo mínimo de `enqueue`/`applyResult` para que `SyncEngine` tenga
/// algo real que leer y escribir.
class FakeSyncStore implements SyncStore {
  final List<_Row> _outbox = [];
  int _seq = 0;
  String? _cursor;
  IsoDate? _lastSyncedAt;
  final Map<String, String?> _meta = {};
  final Map<Id, Conflict> _conflicts = {};
  final Set<Id> _conflictedNotes = {};
  final StreamController<void> _localChanges =
      StreamController<void>.broadcast();

  @override
  Stream<void> get localChanges => _localChanges.stream;

  @override
  Future<void> enqueue(PendingChange change, IsoDate changedAt) async {
    final key = outboxKey(change.entity, change.entityId);
    final idx = _outbox.indexWhere(
      (r) => outboxKey(r.entity, r.entityId) == key,
    );
    if (idx < 0) {
      if (change.op == SyncOp.delete && change.baseRevision == 0) return;
      _outbox.add(
        _Row(
          seq: ++_seq,
          entity: change.entity,
          entityId: change.entityId,
          op: change.op,
          baseRevision: change.baseRevision,
          version: 1,
          changedAt: changedAt,
        ),
      );
      _localChanges.add(null);
      return;
    }
    final existing = _outbox[idx];
    if (change.op == SyncOp.delete) {
      if (existing.baseRevision == 0) {
        _outbox.removeAt(idx);
        _localChanges.add(null);
        return;
      }
      existing
        ..op = SyncOp.delete
        ..version += 1
        ..changedAt = changedAt;
      _localChanges.add(null);
      return;
    }
    existing
      ..op = SyncOp.upsert
      ..version += 1
      ..changedAt = changedAt;
    _localChanges.add(null);
  }

  @override
  Future<List<OutboxEntry>> pending() async => [
    for (final row in _outbox)
      if (!(row.entity == SyncEntity.note &&
          _conflictedNotes.contains(row.entityId)))
        row.toEntry(),
  ];

  @override
  Future<int> pendingCount() async => _outbox.length;

  @override
  Future<String?> cursor() async => _cursor;

  @override
  Future<IsoDate?> lastSyncedAt() async => _lastSyncedAt;

  @override
  Future<String?> readMeta(String key) async => _meta[key];

  @override
  Future<void> writeMeta(String key, String? value) async {
    _meta[key] = value;
  }

  @override
  Future<void> applyResult({
    required List<OutboxEntry> sent,
    required List<AppliedChange> applied,
    required List<ConflictReport> conflicts,
    required List<RemoteChange> remoteChanges,
    required String cursor,
    required IsoDate now,
  }) async {
    final sentVersion = {
      for (final entry in sent)
        outboxKey(entry.entity, entry.entityId): entry.version,
    };
    for (final a in applied) {
      final idx = _outbox.indexWhere(
        (r) => r.entity == a.entity && r.entityId == a.id,
      );
      if (idx < 0) continue;
      final row = _outbox[idx];
      final unchanged = row.version == sentVersion[outboxKey(a.entity, a.id)];
      if (unchanged) {
        _outbox.removeAt(idx);
      } else {
        row.baseRevision = a.revision;
      }
      _localChanges.add(null);
    }
    for (final c in conflicts) {
      _conflictedNotes.add(c.noteId);
      _conflicts[c.noteId] = Conflict(
        noteId: c.noteId,
        local: const NoteVersion(
          title: '',
          content: '',
          editedAt: '',
          deviceName: 'local',
        ),
        remote: NoteVersion(
          title: '',
          content: '',
          editedAt: now,
          deviceName: c.remoteDeviceName,
        ),
      );
    }
    _cursor = cursor;
    _lastSyncedAt = now;
  }

  @override
  Future<List<Conflict>> conflicts() async => _conflicts.values.toList();

  @override
  Future<void> resolveConflict(Id noteId, ConflictResolution resolution) async {
    _conflicts.remove(noteId);
    _conflictedNotes.remove(noteId);
    _outbox.removeWhere(
      (r) =>
          r.entity == SyncEntity.note &&
          r.entityId == noteId &&
          resolution == ConflictResolution.remote,
    );
    _localChanges.add(null);
  }

  @override
  Future<ShareRow?> share(Id noteId) async => null;

  @override
  Future<void> upsertShare(ShareRow share) async {}

  @override
  Future<void> deleteShare(Id noteId) async {}
}

/// `ItemCodec` falso: produce campos deterministas y registra qué se cifró.
class FakeItemCodec implements ItemCodec {
  final List<Id> sealedNotes = [];
  final List<Id> sealedFolders = [];

  @override
  Future<EncryptedNoteFields> sealNote(Id id) async {
    sealedNotes.add(id);
    return EncryptedNoteFields(
      folderId: null,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
      deletedAt: null,
      wrappedKey: 'wk-note-$id',
      payload: 'pl-note-$id',
    );
  }

  @override
  Future<EncryptedFolderFields> sealFolder(Id id) async {
    sealedFolders.add(id);
    return EncryptedFolderFields(
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
      wrappedKey: 'wk-folder-$id',
      payload: 'pl-folder-$id',
    );
  }
}

/// `SyncTransport` guionizado: una función por llamada esperada, en orden.
class FakeSyncTransport implements SyncTransport {
  FakeSyncTransport(this._script);

  final List<FutureOr<SyncResponse> Function(SyncRequest)> _script;
  final List<SyncRequest> requests = [];
  int _next = 0;

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    requests.add(request);
    if (_next >= _script.length) {
      throw StateError(
        'más peticiones (${requests.length}) de las guionizadas (${_script.length})',
      );
    }
    return _script[_next++](request);
  }
}

/// Reloj falso: siempre el mismo instante, salvo que se fije otro.
class FakeSyncClock implements SyncClock {
  FakeSyncClock([this._now = '2026-01-01T00:00:00.000Z']);

  IsoDate _now;

  @override
  IsoDate now() => _now;

  void set(IsoDate value) => _now = value;
}

SyncResponse emptyResponse({String cursor = '0', bool hasMore = false}) =>
    SyncResponse(
      cursor: cursor,
      hasMore: hasMore,
      applied: const [],
      conflicts: const [],
      remoteChanges: const [],
    );
