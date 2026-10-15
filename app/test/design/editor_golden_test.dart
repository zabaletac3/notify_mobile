import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:axonote_app/dev/editor_gallery.dart';
import 'package:axonote_app/ui/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Carga la fuente Inter (empaquetada en `assets/fonts`) en las pruebas.
Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.otf'));
  }
  await loader.load();
}

/// Monta la maqueta a tamaño de tablero (412×915), en el estado y modo pedidos.
Future<void> _pump(
  WidgetTester tester,
  EditorMockState state, {
  required bool dark,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: EditorGallery(
        key: ValueKey('${state.name}-$dark'),
        initialState: state,
        initialDark: dark,
        showDevBar: false,
      ),
    ),
  );
  // El editor parpadea el cursor: se avanza un tiempo fijo en vez de `pumpAndSettle`.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadInter);

  for (final state in EditorMockState.values) {
    for (final (mode, dark) in [('claro', false), ('oscuro', true)]) {
      testWidgets('golden ${state.label} · $mode', (tester) async {
        await _pump(tester, state, dark: dark);
        await expectLater(
          find.byType(EditorGallery),
          matchesGoldenFile('goldens/editor-${state.name}-$mode.png'),
        );
      });
    }
  }

  testWidgets('el editor usa los tokens del modo (texto y cursor)', (
    tester,
  ) async {
    await _pump(tester, EditorMockState.normal, dark: true);
    final darkEditor = tester.widget<AppFlowyEditor>(
      find.byType(AppFlowyEditor),
    );
    expect(
      darkEditor.editorStyle.textStyleConfiguration.text.color,
      AxoColors.dark.textPrimary,
    );
    expect(darkEditor.editorStyle.cursorColor, AxoColors.dark.accentDefault);

    await _pump(tester, EditorMockState.normal, dark: false);
    final lightEditor = tester.widget<AppFlowyEditor>(
      find.byType(AppFlowyEditor),
    );
    expect(
      lightEditor.editorStyle.textStyleConfiguration.text.color,
      AxoColors.light.textPrimary,
    );
  });
}
