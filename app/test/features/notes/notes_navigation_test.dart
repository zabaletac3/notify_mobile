import 'package:flutter_test/flutter_test.dart';

import 'support/notes_harness.dart';
import 'support/notes_router.dart';

/// Salida de Papelera, Ajustes y Búsqueda: se entra desde el menú lateral (o el buscador) y se debe
/// poder volver con el botón de la pantalla y con el atrás del sistema. Regresión del fallo del ZTE:
/// el drawer navegaba con `go` (sin pila) y el botón «atrás» no salía.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);

  for (final (name, label) in [
    ('Papelera', 'Papelera'),
    ('Ajustes', 'Ajustes'),
  ]) {
    testWidgets('$name: el botón atrás de la pantalla vuelve a la lista', (
      tester,
    ) async {
      final h = await buildNotesHarness();
      await pumpNotesRouter(tester, h);
      await openNotesDrawer(tester);
      await tapDrawerItem(tester, label);

      final route = name == 'Papelera' ? '/trash' : '/settings/menu';
      expect(currentLocation(h), route);

      await tapScreenBack(tester);
      expect(currentLocation(h), '/notes');
    });

    testWidgets('$name: el atrás del sistema vuelve a la lista', (
      tester,
    ) async {
      final h = await buildNotesHarness();
      await pumpNotesRouter(tester, h);
      await openNotesDrawer(tester);
      await tapDrawerItem(tester, label);

      final route = name == 'Papelera' ? '/trash' : '/settings/menu';
      expect(currentLocation(h), route);

      await systemBack(tester);
      expect(currentLocation(h), '/notes');
    });
  }

  testWidgets('Búsqueda: el botón atrás de la pantalla vuelve a la lista', (
    tester,
  ) async {
    final h = await buildNotesHarness();
    await pumpNotesRouter(tester, h);

    await tester.tap(find.text('Buscar notas'));
    await tester.pumpAndSettle();
    expect(currentLocation(h), '/search');

    await tapScreenBack(tester);
    expect(currentLocation(h), '/notes');
  });

  testWidgets('Búsqueda: el atrás del sistema vuelve a la lista', (
    tester,
  ) async {
    final h = await buildNotesHarness();
    await pumpNotesRouter(tester, h);

    await tester.tap(find.text('Buscar notas'));
    await tester.pumpAndSettle();
    expect(currentLocation(h), '/search');

    await systemBack(tester);
    expect(currentLocation(h), '/notes');
  });
}
