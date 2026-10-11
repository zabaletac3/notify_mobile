import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_harness.dart';

const _t = '2026-10-07T12:00:00.000Z';

/// Cifra la fila local [id] como un cambio remoto (lo que llegaría de otro dispositivo).
Future<EncryptedNote> remoteNote(
  LocalHarness h,
  String id, {
  int? revision,
  String device = 'd_other',
}) async {
  final row = (await h.local.deps.notes.byId(id))!;
  final sealed = await h.local.deps.codec.sealNoteForUpload(row);
  return EncryptedNote(
    id: row.id,
    folderId: row.folderId,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    revision: revision ?? row.revision + 1,
    lastEditedDeviceId: device,
    wrappedKey: sealed.wrappedKey,
    payload: sealed.payload,
  );
}

void main() {
  late LocalHarness h;

  setUp(() => h = LocalHarness(now: () => DateTime.utc(2026, 10, 7, 12)));
  tearDown(() => h.close());

  group('cola (outbox)', () {
    Future<void> enqueue(SyncOp op, String id, int base) =>
        h.local.syncStore.enqueue(
          PendingChange(
            entity: SyncEntity.note,
            entityId: id,
            op: op,
            baseRevision: base,
          ),
          _t,
        );

    test(
      'funde los cambios de una entidad con la revisión base más antigua',
      () async {
        // Borrar algo que nunca llegó al servidor no deja nada.
        await enqueue(SyncOp.delete, 'n1', 0);
        expect(await h.local.syncStore.pendingCount(), 0);

        await enqueue(SyncOp.upsert, 'n1', 0);
        var pending = (await h.local.syncStore.pending()).single;
        expect(pending.version, 1);
        expect(pending.baseRevision, 0);

        await enqueue(SyncOp.upsert, 'n1', 3);
        pending = (await h.local.syncStore.pending()).single;
        expect(pending.version, 2);
        expect(
          pending.baseRevision,
          0,
          reason: 'conserva la revisión base más antigua',
        );

        // Editar y luego borrar → solo el borrado.
        await enqueue(SyncOp.delete, 'n1', 0);
        expect(await h.local.syncStore.pendingCount(), 0);
      },
    );

    test('borrar algo ya sincronizado pasa a borrado', () async {
      await enqueue(SyncOp.upsert, 'n2', 5);
      await enqueue(SyncOp.delete, 'n2', 5);
      final pending = (await h.local.syncStore.pending()).single;
      expect(pending.op, SyncOp.delete);
      expect(pending.version, 2);
      expect(pending.baseRevision, 5);
    });

    test(
      'una nota en conflicto no se sube, pero sí cuenta como pendiente',
      () async {
        final note = await h.local.notes.create(const NoteDraft(title: 'C'));
        final enc = await remoteNote(h, note.id, revision: 2);
        await h.local.syncStore.applyResult(
          sent: const [],
          applied: const [],
          conflicts: [
            ConflictReport(
              noteId: note.id,
              remote: enc,
              remoteDeviceName: 'otro',
            ),
          ],
          remoteChanges: const [],
          cursor: 'c',
          now: _t,
        );
        expect(await h.local.syncStore.pendingCount(), 1);
        expect(await h.local.syncStore.pending(), isEmpty);
      },
    );
  });

  group('aplicar lo aceptado', () {
    test('fija la revisión, marca synced y quita la entrada', () async {
      final note = await h.local.notes.create(const NoteDraft(title: 'X'));
      final sent = await h.local.syncStore.pending();
      await h.local.syncStore.applyResult(
        sent: sent,
        applied: [
          AppliedChange(entity: SyncEntity.note, id: note.id, revision: 7),
        ],
        conflicts: const [],
        remoteChanges: const [],
        cursor: 'c1',
        now: _t,
      );
      expect(await h.local.syncStore.pendingCount(), 0);
      final got = await h.local.notes.get(note.id);
      expect(got.revision, 7);
      expect(got.syncStatus, NoteSyncStatus.synced);
      expect(await h.local.syncStore.cursor(), 'c1');
      expect(await h.local.syncStore.lastSyncedAt(), _t);
    });

    test(
      'si se edita mientras se sincroniza, la entrada queda pendiente',
      () async {
        final note = await h.local.notes.create(const NoteDraft(content: 'v1'));
        final sent = await h.local.syncStore.pending();
        await h.local.notes.update(note.id, const NoteDraft(content: 'v2'));
        await h.local.syncStore.applyResult(
          sent: sent,
          applied: [
            AppliedChange(entity: SyncEntity.note, id: note.id, revision: 5),
          ],
          conflicts: const [],
          remoteChanges: const [],
          cursor: 'c',
          now: _t,
        );
        final got = await h.local.notes.get(note.id);
        expect(got.revision, 5);
        expect(got.syncStatus, NoteSyncStatus.pending);
        expect((await h.local.syncStore.pending()).single.baseRevision, 5);
      },
    );
  });

  group('dos dispositivos', () {
    late LocalHarness a;
    late LocalHarness b;
    final master = generateKeyBytes();

    setUp(() {
      a = LocalHarness(
        master: master,
        deviceId: 'd_a',
        now: () => DateTime.utc(2026, 10, 7, 12),
      );
      b = LocalHarness(
        master: master,
        deviceId: 'd_b',
        deviceName: 'Móvil de B',
        now: () => DateTime.utc(2026, 10, 7, 12),
      );
    });

    tearDown(() async {
      await a.close();
      await b.close();
    });

    test('un cambio remoto se aplica y se descifra', () async {
      final note = await a.local.notes.create(
        const NoteDraft(title: 'Compartida', content: 'hola'),
      );
      final enc = await remoteNote(a, note.id);
      await b.local.syncStore.applyResult(
        sent: const [],
        applied: const [],
        conflicts: const [],
        remoteChanges: [
          RemoteChange(
            entity: SyncEntity.note,
            id: note.id,
            deleted: false,
            revision: enc.revision,
            note: enc,
          ),
        ],
        cursor: 'c2',
        now: _t,
      );
      final got = await b.local.notes.get(note.id);
      expect(got.title, 'Compartida');
      expect(got.content, 'hola');
      expect(got.syncStatus, NoteSyncStatus.synced);
    });

    test('un cambio local pendiente no se pisa', () async {
      final note = await a.local.notes.create(
        const NoteDraft(content: 'original'),
      );
      final enc = await remoteNote(a, note.id);
      await b.local.syncStore.applyResult(
        sent: const [],
        applied: const [],
        conflicts: const [],
        remoteChanges: [
          RemoteChange(
            entity: SyncEntity.note,
            id: note.id,
            deleted: false,
            revision: enc.revision,
            note: enc,
          ),
        ],
        cursor: 'c',
        now: _t,
      );
      await b.local.notes.update(
        note.id,
        const NoteDraft(content: 'local de B'),
      );

      final enc2 = await remoteNote(a, note.id, revision: 9);
      await b.local.syncStore.applyResult(
        sent: const [],
        applied: const [],
        conflicts: const [],
        remoteChanges: [
          RemoteChange(
            entity: SyncEntity.note,
            id: note.id,
            deleted: false,
            revision: 9,
            note: enc2,
          ),
        ],
        cursor: 'c',
        now: _t,
      );
      expect((await b.local.notes.get(note.id)).content, 'local de B');
    });

    test('un borrado remoto borra la nota y su conflicto', () async {
      final note = await a.local.notes.create(const NoteDraft(title: 'M'));
      final enc = await remoteNote(a, note.id);
      await b.local.syncStore.applyResult(
        sent: const [],
        applied: const [],
        conflicts: const [],
        remoteChanges: [
          RemoteChange(
            entity: SyncEntity.note,
            id: note.id,
            deleted: false,
            revision: enc.revision,
            note: enc,
          ),
        ],
        cursor: 'c',
        now: _t,
      );
      await b.local.syncStore.applyResult(
        sent: const [],
        applied: const [],
        conflicts: const [],
        remoteChanges: [
          RemoteChange(
            entity: SyncEntity.note,
            id: note.id,
            deleted: true,
            revision: 2,
          ),
        ],
        cursor: 'c',
        now: _t,
      );
      expect(await b.local.deps.notes.byId(note.id), isNull);
    });

    test('resolver un conflicto: remote, local y both', () async {
      for (final resolution in ConflictResolution.values) {
        final note = await a.local.notes.create(
          const NoteDraft(title: 'Base', content: 'base'),
        );
        final enc = await remoteNote(a, note.id);
        await b.local.syncStore.applyResult(
          sent: const [],
          applied: const [],
          conflicts: const [],
          remoteChanges: [
            RemoteChange(
              entity: SyncEntity.note,
              id: note.id,
              deleted: false,
              revision: enc.revision,
              note: enc,
            ),
          ],
          cursor: 'c',
          now: _t,
        );
        await b.local.notes.update(
          note.id,
          const NoteDraft(content: 'version de B'),
        );
        await a.local.notes.update(
          note.id,
          const NoteDraft(content: 'version de A'),
        );
        final remote = await remoteNote(a, note.id, revision: 5, device: 'a');
        await b.local.syncStore.applyResult(
          sent: const [],
          applied: const [],
          conflicts: [
            ConflictReport(
              noteId: note.id,
              remote: remote,
              remoteDeviceName: 'a',
            ),
          ],
          remoteChanges: const [],
          cursor: 'c',
          now: _t,
        );

        final described = await b.local.syncStore.conflicts();
        expect(described.single.local.content, 'version de B');
        expect(described.single.local.deviceName, 'Móvil de B');
        expect(described.single.remote.content, 'version de A');

        await b.local.syncStore.resolveConflict(note.id, resolution);
        expect(await b.local.syncStore.conflicts(), isEmpty);

        switch (resolution) {
          case ConflictResolution.remote:
            final got = await b.local.notes.get(note.id);
            expect(got.content, 'version de A');
            expect(got.syncStatus, NoteSyncStatus.synced);
            expect(await b.local.syncStore.pendingCount(), 0);
          case ConflictResolution.local:
            final got = await b.local.notes.get(note.id);
            expect(got.content, 'version de B');
            expect(got.revision, 5);
            expect(got.syncStatus, NoteSyncStatus.pending);
          case ConflictResolution.both:
            final original = await b.local.notes.get(note.id);
            expect(original.content, 'version de A');
            final summary = (await b.local.notes.list()).firstWhere(
              (n) => n.title.endsWith('(conflicto)'),
            );
            final copy = await b.local.notes.get(summary.id);
            expect(copy.content, 'version de B');
        }

        await a.close();
        a = LocalHarness(
          master: master,
          deviceId: 'd_a',
          now: () => DateTime.utc(2026, 10, 7, 12),
        );
        await b.close();
        b = LocalHarness(
          master: master,
          deviceId: 'd_b',
          deviceName: 'Móvil de B',
          now: () => DateTime.utc(2026, 10, 7, 12),
        );
      }
    });
  });

  test('meta y shares', () async {
    await h.local.syncStore.writeMeta('deviceId', 'd1');
    expect(await h.local.syncStore.readMeta('deviceId'), 'd1');
    expect(await h.local.syncStore.cursor(), isNull);

    await h.local.syncStore.upsertShare(
      const ShareRow(
        noteId: 'n',
        slug: 'slug',
        wrappedShareKey: 'w',
        createdAt: _t,
        updatedAt: _t,
      ),
    );
    final share = await h.local.syncStore.share('n');
    expect(share!.slug, 'slug');
    await h.local.syncStore.deleteShare('n');
    expect(await h.local.syncStore.share('n'), isNull);
  });
}
