import 'package:axonote_app/router/app_router.dart';
import 'package:axonote_app/ui/app_icon.dart';
import 'package:flutter_test/flutter_test.dart';

import '../notes/support/notes_harness.dart';
import '../notes/support/notes_router.dart';

/// Navegación de Ajustes: el drawer entra al menú (`/settings/menu`), cada sección navega con
/// `push` y se vuelve con el botón de la pantalla y con el atrás del sistema; desde el menú se
/// vuelve a la lista.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);

  const sections = <(String, String)>[
    ('Generales', '/settings/general'),
    ('Mi cuenta', '/settings/account'),
    ('Sincronización', '/settings/sync'),
    ('Privacidad y seguridad', '/settings/privacy'),
    ('Almacenamiento', '/settings/storage'),
    ('Eliminar cuenta', '/settings/delete-account'),
    ('Acerca de', '/settings/about'),
  ];

  Future<NotesHarness> openMenu(WidgetTester tester) async {
    final h = await buildNotesHarness();
    await pumpNotesRouter(tester, h);
    await openNotesDrawer(tester);
    await tapDrawerItem(tester, 'Ajustes');
    expect(currentLocation(h), '/settings/menu');
    return h;
  }

  testWidgets('cada sección navega y su atrás vuelve al menú', (tester) async {
    final h = await openMenu(tester);
    for (final (label, route) in sections) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(currentLocation(h), route, reason: label);

      await _tapBack(tester);
      expect(currentLocation(h), '/settings/menu', reason: 'atrás de $label');
    }
  });

  testWidgets('el atrás del sistema vuelve del menú a la lista', (
    tester,
  ) async {
    final h = await openMenu(tester);
    await systemBack(tester);
    expect(currentLocation(h), '/notes');
  });

  testWidgets('el atrás del sistema vuelve de una sección al menú', (
    tester,
  ) async {
    final h = await openMenu(tester);
    await tester.tap(find.text('Generales'));
    await tester.pumpAndSettle();
    expect(currentLocation(h), '/settings/general');

    await systemBack(tester);
    expect(currentLocation(h), '/settings/menu');
  });

  testWidgets('una sección abierta por enlace directo sale a la lista', (
    tester,
  ) async {
    final h = await buildNotesHarness();
    await pumpNotesRouter(tester, h);

    // Sin pila (llegada directa): el botón «atrás» no deja atrapado al usuario.
    h.container.read(routerProvider).go('/settings/about');
    await tester.pumpAndSettle();
    expect(currentLocation(h), '/settings/about');

    await _tapBack(tester);
    expect(currentLocation(h), '/notes');
  });

  testWidgets(
    'desde Privacidad se entra a Verificación en dos pasos y se vuelve',
    (tester) async {
      final h = await openMenu(tester);
      await tester.tap(find.text('Privacidad y seguridad'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verificación en dos pasos'));
      await tester.pumpAndSettle();
      expect(currentLocation(h), '/settings/two-factor');

      await _tapBack(tester);
      expect(currentLocation(h), '/settings/privacy');
    },
  );
}

Future<void> _tapBack(WidgetTester tester) async {
  await tester.tap(
    find.byWidgetPredicate((w) => w is AppIcon && w.name == 'arrow-left').first,
  );
  await tester.pumpAndSettle();
}
