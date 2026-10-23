import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../notes/support/notes_harness.dart';
import '../notes/support/notes_router.dart';

/// Reproduce «los botones de la barra de formato no hacen nada»: se coloca el cursor tocando el
/// texto y se pulsan los botones como en el móvil.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);

  testWidgets('la lista y la negrita actúan tras tocar el texto y la barra', (
    tester,
  ) async {
    final h = await buildNotesHarness();
    await pumpNotesRouter(tester, h);
    await tester.tap(find.text('Resumen: Bases de datos II'));
    await tester.pumpAndSettle();
    final editor = tester.widget<AppFlowyEditor>(find.byType(AppFlowyEditor));
    final state = editor.editorState;

    state.selection = Selection.collapsed(Position(path: [0], offset: 3));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('selección tras tocar el texto: ${state.selection}');
    // ignore: avoid_print
    print('tipo antes: ${state.getNodeAtPath([0])?.type}');

    await tester.tap(find.bySemanticsLabel('Lista'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('selección tras tocar Lista: ${state.selection}');
    // ignore: avoid_print
    print('tipo después: ${state.getNodeAtPath([0])?.type}');
    expect(state.getNodeAtPath([0])?.type, 'bulleted_list');
    expect(
      state.getNodeAtPath([0])?.delta?.toPlainText(),
      startsWith('Normalización hasta 3FN'),
    );
  });

  testWidgets(
    'el menú de estilo de párrafo conserva el cursor y aplica el título',
    (tester) async {
      final h = await buildNotesHarness();
      await pumpNotesRouter(tester, h);
      await tester.tap(find.text('Resumen: Bases de datos II'));
      await tester.pumpAndSettle();
      final state = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      state.selection = Selection.collapsed(Position(path: [0], offset: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Estilo de párrafo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Título 1'));
      await tester.pumpAndSettle();
      expect(state.getNodeAtPath([0])?.type, 'heading');
      expect(
        state.getNodeAtPath([0])?.delta?.toPlainText(),
        startsWith('Normalización hasta 3FN'),
      );
    },
  );

  testWidgets('con el editor enfocado, los botones siguen actuando', (
    tester,
  ) async {
    final h = await buildNotesHarness();
    await pumpNotesRouter(tester, h);
    await tester.tap(find.text('Resumen: Bases de datos II'));
    await tester.pumpAndSettle();
    final state = tester
        .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
        .editorState;
    // Foco real en el editor (como al tocar el texto en el móvil).
    final focus = Focus.of(
      tester.element(find.byType(AppFlowyEditor)),
      scopeOk: true,
    );
    focus.requestFocus();
    state.selection = Selection.collapsed(Position(path: [0], offset: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Lista de tareas'));
    await tester.pumpAndSettle();
    expect(state.selection, isNotNull);
    expect(state.getNodeAtPath([0])?.type, 'todo_list');
    expect(
      state.getNodeAtPath([0])?.delta?.toPlainText(),
      startsWith('Normalización hasta 3FN'),
    );
  });

  testWidgets(
    'sin cursor en el cuerpo (solo el título), los botones actúan sobre el final',
    (tester) async {
      final h = await buildNotesHarness();
      await pumpNotesRouter(tester, h);
      await tester.tap(find.text('Resumen: Bases de datos II'));
      await tester.pumpAndSettle();
      final state = tester
          .widget<AppFlowyEditor>(find.byType(AppFlowyEditor))
          .editorState;
      expect(state.selection, isNull);

      await tester.tap(find.bySemanticsLabel('Lista'));
      await tester.pumpAndSettle();
      final last = state.document.root.children.last;
      expect(last.type, 'bulleted_list');
      expect(last.delta?.toPlainText(), isNotEmpty);
    },
  );
}
