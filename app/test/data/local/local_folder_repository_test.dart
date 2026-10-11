import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_harness.dart';

void main() {
  late DateTime now;
  late LocalHarness h;

  setUp(() {
    now = DateTime.utc(2026, 10, 7, 12);
    h = LocalHarness(now: () => now);
  });

  tearDown(() => h.close());

  test('crear, listar y renombrar', () async {
    final folder = await h.local.folders.create('Universidad');
    expect(folder.name, 'Universidad');
    expect((await h.local.folders.list()).single.id, folder.id);
    final renamed = await h.local.folders.rename(folder.id, 'Estudios');
    expect(renamed.name, 'Estudios');
    expect((await h.local.folders.list()).single.name, 'Estudios');
  });

  test(
    'valida el nombre: obligatorio, único sin distinguir mayúsculas ni tildes',
    () async {
      await h.local.folders.create('Universidad');
      await expectLater(
        h.local.folders.create('  '),
        throwsA(predicate((Object e) => e.toString().contains('validation'))),
      );
      await expectLater(
        h.local.folders.create('universidad'),
        throwsA(predicate((Object e) => e.toString().contains('validation'))),
      );
      await expectLater(
        h.local.folders.create('x' * 31),
        throwsA(predicate((Object e) => e.toString().contains('validation'))),
      );
    },
  );

  test('borrar una carpeta deja sus notas sin carpeta', () async {
    final folder = await h.local.folders.create('Universidad');
    // Simula que la carpeta ya estaba en el servidor (revisión 1).
    await h.local.syncStore.applyResult(
      sent: const [],
      applied: [
        AppliedChange(entity: SyncEntity.folder, id: folder.id, revision: 1),
      ],
      conflicts: const [],
      remoteChanges: const [],
      cursor: '1',
      now: '2026-10-07T12:00:00.000Z',
    );
    final note = await h.local.notes.create(
      NoteDraft(title: 'Resumen', folderId: folder.id),
    );
    await h.local.folders.delete(folder.id);
    expect(await h.local.folders.list(), isEmpty);
    expect((await h.local.notes.get(note.id)).folderId, isNull);
    // Se han apuntado el borrado de la carpeta y la actualización de la nota.
    final pending = await h.local.syncStore.pending();
    expect(
      pending
          .where((e) => e.entity == SyncEntity.folder && e.op == SyncOp.delete)
          .length,
      1,
    );
    expect(pending.where((e) => e.entity == SyncEntity.note).length, 1);
  });

  test('una carpeta ilegible no se puede renombrar pero sí borrar', () async {
    const garbage = 'a1.AAAAAAAAAAAAAAAA.AAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    final key = await h.vault.newItemKey(ItemEntity.folder, 'f_bad');
    await h.local.syncStore.applyResult(
      sent: const [],
      applied: const [],
      conflicts: const [],
      remoteChanges: [
        RemoteChange(
          entity: SyncEntity.folder,
          id: 'f_bad',
          deleted: false,
          revision: 1,
          folder: EncryptedFolder(
            id: 'f_bad',
            createdAt: '2026-10-07T12:00:00.000Z',
            updatedAt: '2026-10-07T12:00:00.000Z',
            revision: 1,
            wrappedKey: key.wrapped,
            payload: garbage,
          ),
        ),
      ],
      cursor: '1',
      now: '2026-10-07T12:00:00.000Z',
    );
    expect((await h.local.folders.list()).single.name, 'Carpeta ilegible');
    await expectLater(
      h.local.folders.rename('f_bad', 'Otra'),
      throwsA(predicate((Object e) => e.toString().contains('decrypt'))),
    );
    await h.local.folders.delete('f_bad');
    expect(await h.local.folders.list(), isEmpty);
  });

  test('watch emite al cambiar las carpetas', () async {
    final events = <List<Folder>>[];
    final sub = h.local.folders.watch().listen(events.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final folder = await h.local.folders.create('Cole');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await h.local.folders.rename(folder.id, 'Colegio');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(events.length, greaterThanOrEqualTo(3));
  });
}
