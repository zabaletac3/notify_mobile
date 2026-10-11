import 'package:axonote_app/data/local/local_item_codec.dart';
import 'package:axonote_app/features/sync/state/sync_controller.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../data/local/local_harness.dart';

class _FakeTransport implements SyncTransport {
  _FakeTransport(this._handler);

  final Future<SyncResponse> Function(SyncRequest) _handler;

  @override
  Future<SyncResponse> sync(SyncRequest request) => _handler(request);
}

/// Envuelve un `SyncStore` real y hace fallar `conflicts()` (y por tanto `snapshot()`), para
/// probar que un fallo al leer el almacén después de sincronizar no deja la fase en `syncing`
/// para siempre.
class _ThrowingSnapshotStore implements SyncStore {
  _ThrowingSnapshotStore(this._inner);

  final SyncStore _inner;

  @override
  Future<void> enqueue(PendingChange change, IsoDate changedAt) =>
      _inner.enqueue(change, changedAt);
  @override
  Future<List<OutboxEntry>> pending() => _inner.pending();
  @override
  Future<int> pendingCount() => _inner.pendingCount();
  @override
  Stream<void> get localChanges => _inner.localChanges;
  @override
  Future<String?> cursor() => _inner.cursor();
  @override
  Future<IsoDate?> lastSyncedAt() => _inner.lastSyncedAt();
  @override
  Future<String?> readMeta(String key) => _inner.readMeta(key);
  @override
  Future<void> writeMeta(String key, String? value) =>
      _inner.writeMeta(key, value);
  @override
  Future<void> applyResult({
    required List<OutboxEntry> sent,
    required List<AppliedChange> applied,
    required List<ConflictReport> conflicts,
    required List<RemoteChange> remoteChanges,
    required String cursor,
    required IsoDate now,
  }) => _inner.applyResult(
    sent: sent,
    applied: applied,
    conflicts: conflicts,
    remoteChanges: remoteChanges,
    cursor: cursor,
    now: now,
  );
  @override
  Future<List<Conflict>> conflicts() async =>
      throw StateError('fallo simulado al leer el almacén');
  @override
  Future<void> resolveConflict(Id noteId, ConflictResolution resolution) =>
      _inner.resolveConflict(noteId, resolution);
  @override
  Future<ShareRow?> share(Id noteId) => _inner.share(noteId);
  @override
  Future<void> upsertShare(ShareRow share) => _inner.upsertShare(share);
  @override
  Future<void> deleteShare(Id noteId) => _inner.deleteShare(noteId);
}

SyncResponse _ok({String cursor = '0'}) => SyncResponse(
  cursor: cursor,
  hasMore: false,
  applied: const [],
  conflicts: const [],
  remoteChanges: const [],
);

void main() {
  late LocalHarness h;
  late ProviderContainer container;
  late SyncController controller;

  setUp(() {
    h = LocalHarness();
    container = ProviderContainer();
    controller = container.read(syncControllerProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await h.close();
  });

  SyncEngine engineWith(Future<SyncResponse> Function(SyncRequest) handler) =>
      SyncEngine(
        store: h.local.syncStore,
        transport: _FakeTransport(handler),
        codec: LocalItemCodec(h.local.deps),
      );

  test('sin motor adjunto el estado queda vacío', () async {
    expect(container.read(syncControllerProvider), SyncUiState.empty);
    await controller.syncNow(); // no debe lanzar ni cambiar nada.
    expect(container.read(syncControllerProvider), SyncUiState.empty);
  });

  test('attach carga el snapshot del almacén', () async {
    await h.local.notes.create(const NoteDraft(title: 'x'));
    controller.attach(engineWith((r) async => _ok()));
    await controller.refresh();
    expect(container.read(syncControllerProvider).pendingCount, 1);
    expect(container.read(syncControllerProvider).phase, SyncPhase.idle);
  });

  test('syncNow sube la cola y vuelve a idle sin error', () async {
    await h.local.notes.create(const NoteDraft(title: 'x'));
    controller.attach(
      engineWith(
        (r) async => SyncResponse(
          cursor: '1',
          hasMore: false,
          applied: [
            for (final c in r.changes)
              AppliedChange(entity: c.entity, id: c.entityId, revision: 1),
          ],
          conflicts: const [],
          remoteChanges: const [],
        ),
      ),
    );
    await controller.syncNow();
    final state = container.read(syncControllerProvider);
    expect(state.phase, SyncPhase.idle);
    expect(state.pendingCount, 0);
    expect(state.lastError, isNull);
  });

  test('un fallo de red deja la fase en offline con el error', () async {
    controller.attach(
      engineWith((r) async => throw const AppFailure(NetworkError())),
    );
    await controller.syncNow();
    final state = container.read(syncControllerProvider);
    expect(state.phase, SyncPhase.offline);
    expect(state.lastError, isA<NetworkError>());
  });

  test('un fallo de servidor deja la fase en error', () async {
    controller.attach(
      engineWith((r) async => throw const AppFailure(ServerError())),
    );
    await controller.syncNow();
    expect(container.read(syncControllerProvider).phase, SyncPhase.error);
  });

  test(
    'session-expired llama onSessionExpired y no queda como aviso persistente',
    () async {
      var called = false;
      controller.onSessionExpired = () => called = true;
      controller.attach(
        engineWith((r) async => throw const AppFailure(SessionExpiredError())),
      );
      await controller.syncNow();
      expect(called, isTrue);
      expect(container.read(syncControllerProvider).lastError, isNull);
    },
  );

  test(
    'device-revoked llama onDeviceRevoked y no queda como aviso persistente',
    () async {
      var called = false;
      controller.onDeviceRevoked = () => called = true;
      controller.attach(
        engineWith((r) async => throw const AppFailure(DeviceRevokedError())),
      );
      await controller.syncNow();
      expect(called, isTrue);
      expect(container.read(syncControllerProvider).lastError, isNull);
    },
  );

  test('resolveConflict delega en el motor y refresca el estado', () async {
    final note = await h.local.notes.create(
      const NoteDraft(title: 'Compartida', content: 'base'),
    );
    final sealed = await h.local.deps.codec.sealNoteForUpload(
      (await h.local.deps.notes.byId(note.id))!,
    );
    await h.local.syncStore.applyResult(
      sent: const [],
      applied: const [],
      conflicts: [
        ConflictReport(
          noteId: note.id,
          remote: EncryptedNote(
            id: note.id,
            folderId: null,
            createdAt: '2026-01-01T00:00:00.000Z',
            updatedAt: '2026-01-01T00:00:00.000Z',
            deletedAt: null,
            revision: 2,
            lastEditedDeviceId: 'd_b',
            wrappedKey: sealed.wrappedKey,
            payload: sealed.payload,
          ),
          remoteDeviceName: 'B',
        ),
      ],
      remoteChanges: const [],
      cursor: 'c',
      now: '2026-01-01T00:00:00.000Z',
    );
    controller.attach(engineWith((r) async => _ok()));
    await controller.refresh();
    expect(container.read(syncControllerProvider).conflicts, hasLength(1));

    await controller.resolveConflict(note.id, ConflictResolution.remote);
    expect(container.read(syncControllerProvider).conflicts, isEmpty);
  });

  test(
    'un fallo que no es AppFailure no deja la fase colgada en syncing',
    () async {
      controller.attach(
        engineWith((r) async => throw StateError('dato interno inconsistente')),
      );
      await controller.syncNow();
      final state = container.read(syncControllerProvider);
      expect(state.phase, SyncPhase.error);
      expect(state.lastError, isA<UnknownError>());
    },
  );

  test(
    'locked se descarta en silencio: sin aviso persistente (A3)',
    () async {
      controller.attach(
        engineWith((r) async => throw const AppFailure(LockedError())),
      );
      await controller.syncNow();
      final state = container.read(syncControllerProvider);
      expect(state.lastError, isNull);
      expect(state.phase, isNot(SyncPhase.error));
    },
  );

  test(
    'un fallo al leer el snapshot tras sincronizar también deja fase error, no syncing',
    () async {
      final throwing = _ThrowingSnapshotStore(h.local.syncStore);
      controller.attach(
        SyncEngine(
          store: throwing,
          transport: _FakeTransport((r) async => _ok()),
          codec: LocalItemCodec(h.local.deps),
        ),
      );
      await controller.syncNow();
      final state = container.read(syncControllerProvider);
      expect(state.phase, SyncPhase.error);
      expect(state.lastError, isA<UnknownError>());
    },
  );

  test('detach limpia el estado', () async {
    await h.local.notes.create(const NoteDraft(title: 'x'));
    controller.attach(engineWith((r) async => _ok()));
    await controller.refresh();
    expect(container.read(syncControllerProvider).pendingCount, 1);

    controller.detach();
    expect(container.read(syncControllerProvider), SyncUiState.empty);
  });
}
