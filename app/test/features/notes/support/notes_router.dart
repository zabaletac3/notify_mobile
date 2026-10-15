import 'package:axonote_app/app/session.dart';
import 'package:axonote_app/features/notes/ui/notes_widgets.dart';
import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/router/app_router.dart';
import 'package:axonote_app/ui/components.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notes_harness.dart';

/// Arranca la app real (con `go_router`) sobre el [h] dado, con la sesión desbloqueada, y espera a
/// que asiente en la lista de notas.
Future<void> pumpNotesRouter(WidgetTester tester, NotesHarness h) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  h.container.read(sessionProvider.notifier).set(AxoSession.unlocked);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AxoTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: h.container.read(routerProvider),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Abre el menú lateral de la lista de notas.
Future<void> openNotesDrawer(WidgetTester tester) async {
  tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
  await tester.pumpAndSettle();
}

/// Toca una entrada del menú lateral por su etiqueta.
Future<void> tapDrawerItem(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(AxoDrawer), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Toca el botón «atrás» de la pantalla (barra superior de notas o `AppBar` de los ajustes).
Future<void> tapScreenBack(WidgetTester tester) async {
  final tooltip = find.byTooltip('Atrás');
  final target = tooltip.evaluate().isNotEmpty
      ? tooltip
      : find.byWidgetPredicate(
          (w) => w is NotesIconButton && w.icon == 'arrow-left',
        );
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

/// Simula el botón/gesto «atrás» del sistema (mensaje `popRoute` de la plataforma).
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (_) {},
  );
  await tester.pumpAndSettle();
}

/// Ruta actual del router (sirve también para destinos abiertos con `push`, que `uri` no refleja).
String currentLocation(NotesHarness h) => h.container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .last
    .matchedLocation;
