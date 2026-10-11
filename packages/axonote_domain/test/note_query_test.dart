import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

Note note({
  String id = 'n',
  String? folderId,
  String title = 't',
  String content = '',
  List<String> tags = const [],
  bool pinned = false,
  String createdAt = '2026-10-01T00:00:00.000Z',
  String updatedAt = '2026-10-01T00:00:00.000Z',
  String? deletedAt,
  int revision = 1,
  NoteSyncStatus syncStatus = NoteSyncStatus.synced,
  String lastEditedDeviceId = 'd',
  bool unreadable = false,
}) {
  return Note(
    id: id,
    folderId: folderId,
    title: title,
    content: content,
    tags: tags,
    pinned: pinned,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    revision: revision,
    syncStatus: syncStatus,
    lastEditedDeviceId: lastEditedDeviceId,
    unreadable: unreadable,
  );
}

void main() {
  group('consulta de notas', () {
    final notes = [
      note(
        id: 'a',
        title: 'Zeta',
        updatedAt: '2026-10-03T10:00:00.000Z',
        revision: 3,
      ),
      note(
        id: 'b',
        title: 'alfa',
        folderId: 'f1',
        pinned: true,
        updatedAt: '2026-10-01T10:00:00.000Z',
      ),
      note(
        id: 'c',
        title: 'Ñandú',
        tags: ['x'],
        createdAt: '2026-09-01T00:00:00.000Z',
      ),
      note(id: 'd', title: 'trash', deletedAt: '2026-10-02T00:00:00.000Z'),
    ];

    test(
      'por defecto excluye la papelera y ordena por updatedAt descendente',
      () {
        final result = queryNotes(notes);
        expect(result.map((n) => n.id).toList(), ['a', 'b', 'c']);
      },
    );

    test('la papelera solo sale con el filtro trash', () {
      expect(
        queryNotes(
          notes,
          const NoteQuery(filter: NotesFilterTrash()),
        ).map((n) => n.id).toList(),
        ['d'],
      );
    });

    test('filtra por fijadas, carpeta y etiqueta', () {
      expect(
        queryNotes(
          notes,
          const NoteQuery(filter: NotesFilterPinned()),
        ).map((n) => n.id).toList(),
        ['b'],
      );
      expect(
        queryNotes(
          notes,
          const NoteQuery(filter: NotesFilterFolder('f1')),
        ).map((n) => n.id).toList(),
        ['b'],
      );
      expect(
        queryNotes(
          notes,
          const NoteQuery(filter: NotesFilterTag('x')),
        ).map((n) => n.id).toList(),
        ['c'],
      );
    });

    test('ordena por título sin distinguir mayúsculas ni tildes', () {
      expect(
        queryNotes(
          notes,
          const NoteQuery(sort: NoteSort.title),
        ).map((n) => n.title).toList(),
        ['alfa', 'Ñandú', 'Zeta'],
      );
    });

    test('ordena por creación descendente', () {
      expect(
        queryNotes(
          notes,
          const NoteQuery(sort: NoteSort.created),
        ).map((n) => n.id).toList(),
        ['a', 'b', 'c'],
      );
    });
  });

  group('agrupación de notas (como la lista del diseño)', () {
    final now = DateTime(2026, 10, 7, 12);
    String at(int y, int monthIndex, int d, [int h = 10]) =>
        isoFromDateTime(DateTime(y, monthIndex + 1, d, h));

    test('agrupa en Fijadas · Hoy · Esta semana · mes', () {
      final groups = groupNotes([
        note(id: 'a', pinned: true, updatedAt: at(2026, 9, 1)),
        note(id: 'b', updatedAt: at(2026, 9, 7, 9)),
        note(id: 'c', updatedAt: at(2026, 9, 4)),
        note(id: 'd', updatedAt: at(2026, 8, 28)),
        note(id: 'e', updatedAt: at(2025, 8, 3)),
      ], now);
      expect(
        groups
            .map((g) => [g.key, g.label, g.notes.map((n) => n.id).toList()])
            .toList(),
        [
          [
            'pinned',
            'Fijadas',
            ['a'],
          ],
          [
            'today',
            'Hoy',
            ['b'],
          ],
          [
            'week',
            'Esta semana',
            ['c'],
          ],
          [
            '2026-09',
            'Septiembre',
            ['d'],
          ],
          [
            '2025-09',
            'Septiembre 2025',
            ['e'],
          ],
        ],
      );
    });

    test('no genera grupos vacíos', () {
      expect(groupNotes([], now), isEmpty);
    });

    test('calcula los días que faltan para vaciar la papelera', () {
      int days(int ago) => daysUntilPurge(
        isoFromDateTime(now.subtract(Duration(days: ago))),
        now,
        trashRetentionDays,
      );
      expect(days(1), 29);
      expect(days(14), 16);
      expect(days(21), 9);
      expect(days(45), 0);
    });

    test('Fijadas primero y los meses de más nuevo a más viejo', () {
      final groups = groupNotes([
        note(id: 'old', updatedAt: at(2026, 7, 3)),
        note(id: 'today', updatedAt: at(2026, 9, 7)),
        note(id: 'sep', updatedAt: at(2026, 8, 20)),
        note(id: 'pin', pinned: true, updatedAt: at(2026, 0, 1)),
      ], now);
      expect(groups.map((g) => g.key).toList(), [
        'pinned',
        'today',
        '2026-09',
        '2026-08',
      ]);
    });
  });

  group('validación de nombre de carpeta', () {
    const existing = ['Universidad', 'Recetas'];

    test('obligatorio', () {
      final v = validateFolderName('  ', existing);
      expect(v, isA<Invalid>());
      expect((v as Invalid).errors, {'name': 'required'});
    });

    test('máximo 30 caracteres', () {
      final v = validateFolderName('x' * 31, existing);
      expect((v as Invalid).errors['name'], 'name-too-long');
    });

    test('único sin distinguir mayúsculas ni tildes', () {
      expect(
        (validateFolderName('universidad', existing) as Invalid).errors['name'],
        'name-taken',
      );
      expect(
        (validateFolderName('RÉCETAS', existing) as Invalid).errors['name'],
        'name-taken',
      );
      expect(validateFolderName('Proyectos', existing), isA<Valid>());
    });
  });
}
