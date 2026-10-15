import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:axonote_app/features/editor/state/editor_providers.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../notes/support/notes_harness.dart';
import '../notes/support/notes_router.dart';

/// Pruebas de la pantalla real del editor (fase 11.7): carga la nota, guarda el título y se recarga
/// cuando la nota cambia por fuera (p. ej. al llegar por sincronización).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);

  Future<NotesHarness> openEditor(WidgetTester tester) async {
    final h = await buildNotesHarness();
    await pumpNotesRouter(tester, h);
    await tester.tap(find.text('Resumen: Bases de datos II'));
    await tester.pumpAndSettle();
    expect(find.byType(AppFlowyEditor), findsOneWidget);
    return h;
  }

  Future<Id> noteId(NotesHarness h) async {
    final all = await h.local.local.notes.list();
    return all.firstWhere((n) => n.title == 'Resumen: Bases de datos II').id;
  }

  testWidgets('carga el título y el cuerpo de la nota', (tester) async {
    await openEditor(tester);
    expect(
      find.widgetWithText(TextField, 'Resumen: Bases de datos II'),
      findsOneWidget,
    );
    final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
    expect(editor.editorState.document.root.children, isNotEmpty);
  });

  testWidgets('guardar el título lo persiste en la nota', (tester) async {
    final h = await openEditor(tester);
    final id = await noteId(h);
    await tester.enterText(find.byType(TextField), 'Bases de datos III');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await h.local.local.notes.get(id)).title, 'Bases de datos III');
  });

  testWidgets(
    'se recarga cuando la nota cambia por fuera y no hay cambios locales',
    (tester) async {
      final h = await openEditor(tester);
      final id = await noteId(h);
      await h.local.local.notes.update(
        id,
        const NoteDraft(title: 'Cambió por fuera', content: 'Cuerpo nuevo.'),
      );
      h.container.invalidate(noteByIdProvider(id));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'Cambió por fuera'),
        findsOneWidget,
      );
    },
  );

  testWidgets('el botón «Compartir» abre la hoja de compartir', (tester) async {
    await openEditor(tester);
    await tester.tap(find.bySemanticsLabel('Compartir').first);
    await tester.pumpAndSettle();
    expect(find.text('Compartir nota'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
  });
}
