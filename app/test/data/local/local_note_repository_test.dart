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

  test('crear, listar y obtener', () async {
    final note = await h.local.notes.create(
      const NoteDraft(
        title: 'Idea',
        content: 'uno',
        tags: ['#Proyecto Final', 'privado', 'proyecto-final'],
      ),
    );
    expect(note.revision, 0);
    expect(note.syncStatus, NoteSyncStatus.pending);
    expect(note.createdAt, '2026-10-07T12:00:00.000Z');
    // Etiquetas normalizadas y sin duplicados.
    expect(note.tags, ['proyecto-final', 'privado']);

    final list = await h.local.notes.list();
    expect(list.single.id, note.id);
    expect((await h.local.notes.get(note.id)).title, 'Idea');
  });

  test('la vista previa se calcula al escribir', () async {
    final note = await h.local.notes.create(
      const NoteDraft(title: 'T', content: '# Título\n\nCuerpo **fuerte**'),
    );
    final row = await h.local.deps.notes.byId(note.id);
    expect(row!.preview, 'Título Cuerpo fuerte');
  });

  test('editar conserva la clave y actualiza el contenido', () async {
    final note = await h.local.notes.create(const NoteDraft(content: 'uno'));
    final before = await h.local.deps.notes.byId(note.id);
    now = now.add(const Duration(minutes: 1));
    final updated = await h.local.notes.update(
      note.id,
      const NoteDraft(content: 'dos'),
    );
    final after = await h.local.deps.notes.byId(note.id);
    expect(updated.content, 'dos');
    expect(after!.wrappedKey, before!.wrappedKey);
    expect(after.content, 'dos');
    expect(after.updatedAt, '2026-10-07T12:01:00.000Z');
  });

  test('no se puede editar una nota en la papelera', () async {
    final note = await h.local.notes.create(const NoteDraft(content: 'x'));
    await h.local.notes.moveToTrash(note.id);
    await expectLater(
      h.local.notes.update(note.id, const NoteDraft(content: 'y')),
      throwsA(predicate((Object e) => e.toString().contains('validation'))),
    );
  });

  test('mover a la papelera desfija y restaurar lo revierte', () async {
    final note = await h.local.notes.create(
      const NoteDraft(title: 'P', pinned: true),
    );
    final trashed = await h.local.notes.moveToTrash(note.id);
    expect(trashed.deletedAt, isNotNull);
    expect(trashed.pinned, isFalse);
    expect((await h.local.notes.list()).isEmpty, isTrue);
    expect(
      (await h.local.notes.list(const NoteQuery(filter: NotesFilterTrash())))
          .length,
      1,
    );

    final restored = await h.local.notes.restore(note.id);
    expect(restored.deletedAt, isNull);
    expect((await h.local.notes.list()).length, 1);
  });

  test('duplicar crea otra nota con su propia clave', () async {
    final note = await h.local.notes.create(
      const NoteDraft(title: 'Base', pinned: true),
    );
    final copy = await h.local.notes.duplicate(note.id);
    expect(copy.id, isNot(note.id));
    expect(copy.title, 'Base (copia)');
    expect(copy.pinned, isFalse);
    final original = await h.local.deps.notes.byId(note.id);
    final copied = await h.local.deps.notes.byId(copy.id);
    expect(copied!.wrappedKey, isNot(original!.wrappedKey));
  });

  test('borrado definitivo y vaciado de la papelera', () async {
    final a = await h.local.notes.create(const NoteDraft(title: 'A'));
    final b = await h.local.notes.create(const NoteDraft(title: 'B'));
    await h.local.notes.moveToTrash(a.id);
    await h.local.notes.deleteForever(a.id);
    expect(await h.local.deps.notes.byId(a.id), isNull);
    expect(await h.local.notes.emptyTrash(), 0);

    await h.local.notes.moveToTrash(b.id);
    expect(await h.local.notes.emptyTrash(), 1);
    expect(await h.local.deps.notes.countWhere('deleted_at IS NOT NULL'), 0);
  });

  test('la papelera se vacía sola a los 30 días y avisa al servidor', () async {
    final note = await h.local.notes.create(const NoteDraft(title: 'Vieja'));
    // Simula que ya se había sincronizado (revisión 1) antes de ir a la papelera.
    await h.local.syncStore.applyResult(
      sent: const [],
      applied: [
        AppliedChange(entity: SyncEntity.note, id: note.id, revision: 1),
      ],
      conflicts: const [],
      remoteChanges: const [],
      cursor: '1',
      now: '2026-10-07T12:00:00.000Z',
    );
    await h.local.notes.moveToTrash(note.id);
    now = now.add(const Duration(days: trashRetentionDays + 1));
    expect(
      await h.local.notes.list(const NoteQuery(filter: NotesFilterTrash())),
      isEmpty,
    );
    expect(await h.local.syncStore.pendingCount(), greaterThan(0));
    // La entrada pendiente es un borrado (no un upsert).
    final pending = await h.local.syncStore.pending();
    expect(pending.single.op, SyncOp.delete);
  });

  test('buscar con FTS5 sin distinguir tildes', () async {
    await h.local.notes.create(
      const NoteDraft(title: 'Apuntes', content: 'La normalización ÁÉÍ'),
    );
    await h.local.notes.create(
      const NoteDraft(title: 'Otra', content: 'nada que ver'),
    );
    final found = await h.local.notes.search('normalizacion');
    expect(found.single.title, 'Apuntes');
    final found2 = await h.local.notes.search('zzz');
    expect(found2, isEmpty);
  });

  test('conteos de la barra lateral', () async {
    final folder = await h.local.folders.create('Universidad');
    await h.local.notes.create(const NoteDraft(title: 'Uno'));
    await h.local.notes.create(const NoteDraft(title: 'Dos'));
    final withFolder = await h.local.notes.create(
      NoteDraft(title: 'Tres', folderId: folder.id, tags: ['x'], pinned: true),
    );
    final trashed = await h.local.notes.create(
      const NoteDraft(title: 'Cuatro'),
    );
    await h.local.notes.moveToTrash(trashed.id);

    final counts = await h.local.notes.counts();
    expect(counts.all, 3);
    expect(counts.pinned, 1);
    expect(counts.trash, 1);
    expect(counts.unfiled, 2);
    expect(counts.byFolder[folder.id], 1);
    expect(counts.byTag['x'], 1);
    expect(withFolder.pinned, isTrue);
  });

  group('notas ilegibles', () {
    Future<String> applyUnreadable() async {
      const garbage = 'a1.AAAAAAAAAAAAAAAA.AAAAAAAAAAAAAAAAAAAAAAAAAAAA';
      final created = await h.vault.newItemKey(ItemEntity.note, 'n_bad');
      await h.local.syncStore.applyResult(
        sent: const [],
        applied: const [],
        conflicts: const [],
        remoteChanges: [
          RemoteChange(
            entity: SyncEntity.note,
            id: 'n_bad',
            deleted: false,
            revision: 1,
            note: EncryptedNote(
              id: 'n_bad',
              folderId: null,
              createdAt: '2026-10-07T12:00:00.000Z',
              updatedAt: '2026-10-07T12:00:00.000Z',
              deletedAt: null,
              revision: 1,
              lastEditedDeviceId: 'd_other',
              wrappedKey: created.wrapped,
              payload: garbage,
            ),
          ),
        ],
        cursor: '1',
        now: '2026-10-07T12:00:00.000Z',
      );
      return garbage;
    }

    test('sale marcada como ilegible, sin contenido', () async {
      await applyUnreadable();
      final note = await h.local.notes.get('n_bad');
      expect(note.title, 'Nota ilegible');
      expect(note.content, '');
      expect(note.unreadable, isTrue);
    });

    test('no se puede editar ni duplicar; mover a la papelera conserva el texto cifrado', () async {
      final garbage = await applyUnreadable();
      await expectLater(
        h.local.notes.update('n_bad', const NoteDraft(content: 'nuevo')),
        throwsA(predicate((Object e) => e.toString().contains('decrypt'))),
      );
      await expectLater(
        h.local.notes.duplicate('n_bad'),
        throwsA(predicate((Object e) => e.toString().contains('decrypt'))),
      );
      await h.local.notes.moveToTrash('n_bad');
      final row = await h.local.deps.notes.byId('n_bad');
      expect(row!.rawPayload, garbage);
      expect(row.deletedAt, isNotNull);
    });
  });

  test('watch emite al cambiar las notas', () async {
    final events = <List<Note>>[];
    final sub = h.local.notes.watch().listen(events.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final note = await h.local.notes.create(const NoteDraft(title: 'Viva'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await h.local.notes.moveToTrash(note.id);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(events.length, greaterThanOrEqualTo(3));
  });
}
