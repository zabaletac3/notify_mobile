import 'package:axonote_app/features/notes/ui/notes_screen.dart';
import 'package:axonote_app/features/notes/ui/trash_screen.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/notes_harness.dart';

/// Gestos de la lista (deslizar). El documento de Pencil no los define y `notify_web` tampoco: la
/// decisión está en `docs/decisions.md` (fase 9, «Gestos de la lista»).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);

  testWidgets('deslizar a la derecha en la lista fija la nota', (tester) async {
    final h = await buildNotesHarness();
    await _pump(tester, h, const NotesScreen());

    final note = await _byTitle(h, 'Resumen: Bases de datos II');
    expect(note.pinned, isFalse);

    await tester.drag(
      find.byKey(ValueKey('note-${note.id}')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();

    expect((await h.local.local.notes.get(note.id)).pinned, isTrue);
  });

  testWidgets(
    'deslizar a la izquierda en la lista manda la nota a la papelera',
    (tester) async {
      final h = await buildNotesHarness();
      await _pump(tester, h, const NotesScreen());

      final note = await _byTitle(h, 'Lectura — Diseño centrado en el usuario');
      expect(note.deletedAt, isNull);

      await tester.drag(
        find.byKey(ValueKey('note-${note.id}')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      expect((await h.local.local.notes.get(note.id)).deletedAt, isNotNull);
    },
  );

  testWidgets('deslizar a la derecha en la papelera restaura la nota', (
    tester,
  ) async {
    final h = await buildTrashHarness();
    await _pump(tester, h, const TrashScreen());

    final note = await _byTitle(h, 'Plan del proyecto final', trashed: true);
    expect(note.deletedAt, isNotNull);

    await tester.drag(
      find.byKey(ValueKey('trash-${note.id}')),
      const Offset(400, 0),
    );
    await tester.pumpAndSettle();

    expect((await h.local.local.notes.get(note.id)).deletedAt, isNull);
  });

  testWidgets('la papelera muestra los días restantes con el texto de la web', (
    tester,
  ) async {
    final h = await buildTrashHarness();
    await _pump(tester, h, const TrashScreen());

    // Las tres notas de la semilla vencen a 29, 16 y 9 días (como en el diseño).
    expect(find.text('Se elimina en 29 días'), findsOneWidget);
    expect(find.text('Se elimina en 16 días'), findsOneWidget);
    expect(find.text('Se elimina en 9 días'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, NotesHarness h, Widget home) async {
  await tester.pumpWidget(notesApp(h.container, home, AxoTheme.light()));
  await tester.pumpAndSettle();
}

Future<Note> _byTitle(
  NotesHarness h,
  String title, {
  bool trashed = false,
}) async {
  // `list()` sin filtro excluye la papelera: para las notas borradas hay que pedirla.
  final notes = await h.local.local.notes.list(
    NoteQuery(
      filter: trashed ? const NotesFilterTrash() : const NotesFilterAll(),
    ),
  );
  return notes.firstWhere((n) => n.title == title);
}
