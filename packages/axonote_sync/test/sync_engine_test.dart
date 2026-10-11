import 'dart:async';

import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';
import 'package:test/test.dart';

import 'fakes.dart';

void main() {
  late FakeSyncStore store;
  late FakeItemCodec codec;
  late FakeSyncClock clock;

  setUp(() {
    store = FakeSyncStore();
    codec = FakeItemCodec();
    clock = FakeSyncClock();
  });

  SyncEngine engineWith(List<FutureOr<SyncResponse> Function(SyncRequest)> script) =>
      SyncEngine(
        store: store,
        transport: FakeSyncTransport(script),
        codec: codec,
        clock: clock,
      );

  test('cifra cada upsert desde la fila actual y manda el delete sin datos', () async {
    await store.enqueue(
      const PendingChange(
        entity: SyncEntity.note,
        entityId: 'n1',
        op: SyncOp.upsert,
        baseRevision: 0,
      ),
      '2026-01-01T00:00:00.000Z',
    );
    await store.enqueue(
      const PendingChange(
        entity: SyncEntity.folder,
        entityId: 'f1',
        op: SyncOp.delete,
        baseRevision: 3,
      ),
      '2026-01-01T00:00:00.000Z',
    );

    SyncRequest? seen;
    final engine = engineWith([
      (req) {
        seen = req;
        return emptyResponse(cursor: '1');
      },
    ]);

    await engine.syncNow();

    expect(codec.sealedNotes, ['n1']);
    expect(codec.sealedFolders, isEmpty, reason: 'el delete no se cifra');
    final changes = seen!.changes;
    expect(changes, hasLength(2));
    final note = changes.firstWhere((c) => c.entity == SyncEntity.note);
    expect(note.noteData, isNotNull);
    expect(note.noteData!.wrappedKey, 'wk-note-n1');
    final folder = changes.firstWhere((c) => c.entity == SyncEntity.folder);
    expect(folder.op, SyncOp.delete);
    expect(folder.folderData, isNull);
    expect(await store.cursor(), '1');
  });

  test('cifra también un upsert de carpeta desde su fila actual', () async {
    await store.enqueue(
      const PendingChange(
        entity: SyncEntity.folder,
        entityId: 'f1',
        op: SyncOp.upsert,
        baseRevision: 0,
      ),
      '2026-01-01T00:00:00.000Z',
    );

    SyncRequest? seen;
    final engine = engineWith([
      (req) {
        seen = req;
        return emptyResponse(cursor: '1');
      },
    ]);

    await engine.syncNow();

    expect(codec.sealedFolders, ['f1']);
    expect(seen!.changes.single.folderData!.wrappedKey, 'wk-folder-f1');
  });

  test('pagina mientras hasMore sea verdadero, sin repetir los cambios subidos', () async {
    await store.enqueue(
      const PendingChange(
        entity: SyncEntity.note,
        entityId: 'n1',
        op: SyncOp.upsert,
        baseRevision: 0,
      ),
      '2026-01-01T00:00:00.000Z',
    );

    final engine = engineWith([
      (req) {
        expect(req.changes, hasLength(1));
        return emptyResponse(cursor: 'page:1', hasMore: true);
      },
      (req) {
        expect(req.changes, isEmpty, reason: 'segunda página: sin cambios nuevos');
        expect(req.cursor, 'page:1');
        return emptyResponse(cursor: 'page:2', hasMore: true);
      },
      (req) {
        expect(req.changes, isEmpty);
        expect(req.cursor, 'page:2');
        return emptyResponse(cursor: 'final', hasMore: false);
      },
    ]);

    await engine.syncNow();
    expect(await store.cursor(), 'final');
    expect(codec.sealedNotes, ['n1'], reason: 'solo se cifra una vez, en la primera página');
  });

  test('se detiene en el tope de 100 páginas aunque siga habiendo hasMore', () async {
    var calls = 0;
    final script = List<FutureOr<SyncResponse> Function(SyncRequest)>.generate(
      SyncEngine.maxPages,
      (i) => (req) {
        calls++;
        return emptyResponse(cursor: 'c$i', hasMore: true);
      },
    );
    final engine = engineWith(script);
    await engine.syncNow();
    expect(calls, SyncEngine.maxPages);
  });

  test('una segunda llamada concurrente espera a la primera sin repetirla', () async {
    final completer = Completer<SyncResponse>();
    var requests = 0;
    final engine = engineWith([
      (req) {
        requests++;
        return completer.future;
      },
    ]);

    final first = engine.syncNow();
    final second = engine.syncNow();
    expect(engine.isSyncing, isTrue);

    completer.complete(emptyResponse());
    await Future.wait([first, second]);

    expect(requests, 1);
    expect(engine.isSyncing, isFalse);
  });

  test('un fallo del transporte se propaga sin reintentar', () async {
    final engine = engineWith([
      (req) => throw const AppFailure(NetworkError()),
    ]);

    await expectLater(
      engine.syncNow(),
      throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', 'network')),
    );
    expect(engine.isSyncing, isFalse, reason: 'el fallo libera el candado de un solo vuelo');
  });

  test('resolveConflict delega en el almacén y devuelve el nuevo snapshot', () async {
    await store.applyResult(
      sent: const [],
      applied: const [],
      conflicts: [
        ConflictReport(
          noteId: 'n1',
          remote: EncryptedNote(
            id: 'n1',
            folderId: null,
            createdAt: '2026-01-01T00:00:00.000Z',
            updatedAt: '2026-01-01T00:00:00.000Z',
            deletedAt: null,
            revision: 2,
            lastEditedDeviceId: 'd_b',
            wrappedKey: 'wk',
            payload: 'pl',
          ),
          remoteDeviceName: 'B',
        ),
      ],
      remoteChanges: const [],
      cursor: 'c1',
      now: '2026-01-01T00:00:00.000Z',
    );
    final engine = engineWith(const []);
    expect((await engine.snapshot()).conflicts, hasLength(1));

    final snapshot = await engine.resolveConflict('n1', ConflictResolution.remote);
    expect(snapshot.conflicts, isEmpty);
    expect((await store.conflicts()), isEmpty);
  });

  test(
    'onProgress se llama por página con el total descargado y si es la primera sincronización',
    () async {
      final progress = <SyncProgress>[];
      final engine = SyncEngine(
        store: store,
        transport: FakeSyncTransport([
          (req) => SyncResponse(
            cursor: 'page:1',
            hasMore: true,
            applied: const [],
            conflicts: const [],
            remoteChanges: [
              RemoteChange(entity: SyncEntity.note, id: 'n1', deleted: false, revision: 1),
              RemoteChange(entity: SyncEntity.note, id: 'n2', deleted: false, revision: 1),
            ],
          ),
          (req) => emptyResponse(cursor: 'final'),
        ]),
        codec: codec,
        clock: clock,
        onProgress: progress.add,
      );

      await engine.syncNow();

      expect(progress, hasLength(2));
      expect(progress[0].page, 0);
      expect(progress[0].isFirstSync, isTrue);
      expect(progress[0].downloaded, 2);
      expect(progress[0].hasMore, isTrue);
      expect(progress[1].page, 1);
      expect(progress[1].downloaded, 2, reason: 'la segunda página no trajo nada nuevo');
      expect(progress[1].hasMore, isFalse);
    },
  );

  test('el reloj real da la hora actual en formato ISO con milisegundos', () {
    final iso = const SystemSyncClock().now();
    expect(DateTime.tryParse(iso), isNotNull);
    expect(iso, endsWith('Z'));
  });

  test('snapshot refleja isSyncing mientras hay una sincronización en curso', () async {
    final completer = Completer<SyncResponse>();
    final engine = engineWith([(req) => completer.future]);

    expect((await engine.snapshot()).phase, SyncPhase.idle);
    final pending = engine.syncNow();
    expect((await engine.snapshot()).phase, SyncPhase.syncing);
    completer.complete(emptyResponse());
    await pending;
    expect((await engine.snapshot()).phase, SyncPhase.idle);
  });
}
