import 'package:axonote_app/ui/components.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/notes_harness.dart';
import 'support/notes_router.dart';

/// Crear una carpeta no debe lanzar la aserción `dependents.isEmpty` del framework al cerrarse el
/// diálogo (regresión del ZTE). Se cubren las dos entradas: el pie del menú lateral y «Mover a
/// carpeta».
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);

  testWidgets('crear carpeta desde el menú lateral no revienta', (
    tester,
  ) async {
    final h = await buildNotesHarness();
    await pumpNotesRouter(tester, h);
    await openNotesDrawer(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AxoDrawer),
        matching: find.text('Nueva carpeta'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Proyecto');
    await tester.pump();
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    final names = (await h.local.local.folders.list()).map((f) => f.name);
    expect(names, contains('Proyecto'));
  });

  testWidgets('crear carpeta desde «Mover a carpeta» no revienta y mueve', (
    tester,
  ) async {
    final h = await buildNotesHarness();
    await pumpNotesRouter(tester, h);

    final notes = await h.local.local.notes.list(
      const NoteQuery(filter: NotesFilterAll()),
    );
    final note = notes.firstWhere(
      (n) => n.title == 'Resumen: Bases de datos II',
    );

    await tester.longPress(find.text('Resumen: Bases de datos II'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover a carpeta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva carpeta'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Proyecto');
    await tester.pump();
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    final created = (await h.local.local.folders.list()).firstWhere(
      (f) => f.name == 'Proyecto',
    );
    expect((await h.local.local.notes.get(note.id)).folderId, created.id);
  });
}
