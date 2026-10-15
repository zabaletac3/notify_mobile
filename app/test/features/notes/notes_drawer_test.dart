import 'package:axonote_app/app/session.dart';
import 'package:axonote_app/features/notes/state/notes_view.dart';
import 'package:axonote_app/features/notes/ui/notes_screen.dart';
import 'package:axonote_app/features/notes/ui/notes_widgets.dart';
import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/router/app_router.dart';
import 'package:axonote_app/ui/components.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/notes_harness.dart';

/// Menú lateral (drawer) de la lista de notas. Reproduce la apertura desde la barra superior y la
/// navegación de cada entrada (tablero «Android — Menú lateral»). No forma parte del conjunto de la
/// fase 9: es la revisión del informe `docs/review-sidebar.md`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);

  testWidgets('el botón de menú abre el drawer', (tester) async {
    final h = await buildNotesHarness();
    await tester.pumpWidget(
      notesApp(h.container, const NotesScreen(), AxoTheme.light()),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate((w) => w is NotesIconButton && w.icon == 'menu'),
    );
    await tester.pumpAndSettle();

    expect(_isDrawerOpen(tester), isTrue, reason: 'el drawer debe abrirse');
  });

  testWidgets('el título abre el drawer', (tester) async {
    final h = await buildNotesHarness();
    await tester.pumpWidget(
      notesApp(h.container, const NotesScreen(), AxoTheme.light()),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NotesTopBar),
        matching: find.text('Todas las notas'),
      ),
    );
    await tester.pumpAndSettle();

    expect(_isDrawerOpen(tester), isTrue, reason: 'el drawer debe abrirse');
  });

  testWidgets('«Todas las notas» está activa al abrir el drawer', (
    tester,
  ) async {
    final h = await buildNotesHarness();
    await _pumpRouter(tester, h);
    await _openDrawer(tester);

    expect(_item(tester, 'Todas las notas').selected, isTrue);
  });

  testWidgets('«Fijadas» filtra las fijadas', (tester) async {
    final h = await buildNotesHarness();
    await _pumpRouter(tester, h);
    await _openDrawer(tester);

    await _tapItem(tester, 'Fijadas');
    expect(
      h.container.read(notesViewProvider).filter,
      isA<NotesFilterPinned>(),
    );
    expect(_isDrawerOpen(tester), isFalse, reason: 'el drawer debe cerrarse');
  });

  testWidgets('una carpeta navega a /folders/:id', (tester) async {
    final h = await buildNotesHarness();
    await _pumpRouter(tester, h);
    await _openDrawer(tester);

    await _tapItem(tester, 'Universidad');
    final filter = h.container.read(notesViewProvider).filter;
    expect(filter, isA<NotesFilterFolder>());
    expect((filter as NotesFilterFolder).folderId, h.folderIds['Universidad']);
    expect(_location(h), '/folders/${h.folderIds['Universidad']}');
  });

  testWidgets('una etiqueta filtra por etiqueta', (tester) async {
    final h = await buildNotesHarness();
    await h.local.local.notes.create(
      const NoteDraft(
        title: 'Con etiqueta',
        content: 'cuerpo',
        tags: ['parcial'],
      ),
    );
    await _pumpRouter(tester, h);
    await _openDrawer(tester);

    await _tapItem(tester, '#parcial');
    final filter = h.container.read(notesViewProvider).filter;
    expect(filter, isA<NotesFilterTag>());
    expect((filter as NotesFilterTag).tag, 'parcial');
  });

  testWidgets('«Papelera» navega a /trash', (tester) async {
    final h = await buildNotesHarness();
    await _pumpRouter(tester, h);
    await _openDrawer(tester);

    await _tapItem(tester, 'Papelera');
    expect(_location(h), '/trash');
  });

  testWidgets('«Ajustes» navega a /settings/menu', (tester) async {
    final h = await buildNotesHarness();
    await _pumpRouter(tester, h);
    await _openDrawer(tester);

    await _tapItem(tester, 'Ajustes');
    expect(_location(h), '/settings/menu');
  });

  testWidgets(
    'los contadores se reservan con esqueleto si aún no hay conteos',
    (tester) async {
      final h = await buildLoadingHarness();
      await tester.pumpWidget(
        notesApp(h.container, const NotesScreen(), AxoTheme.light()),
      );
      await tester.pumpAndSettle();
      await _openDrawer(tester);

      final drawer = find.byType(AxoDrawer);
      expect(
        find.descendant(of: drawer, matching: find.text('0')),
        findsNothing,
        reason: 'no se pinta «0» mientras los conteos son nulos',
      );
      expect(
        find.descendant(of: drawer, matching: find.byType(AxoSkeleton)),
        findsWidgets,
      );
    },
  );

  testWidgets('la entrada activa (Fijadas) queda marcada al reabrir', (
    tester,
  ) async {
    final h = await buildNotesHarness();
    await _pumpRouter(tester, h);
    await _openDrawer(tester);
    await _tapItem(tester, 'Fijadas');
    await _openDrawer(tester);

    expect(_item(tester, 'Fijadas').selected, isTrue);
  });
}

AxoDrawerItem _item(WidgetTester tester, String label) =>
    tester.widget<AxoDrawerItem>(find.widgetWithText(AxoDrawerItem, label));

bool _isDrawerOpen(WidgetTester tester) =>
    tester.state<ScaffoldState>(find.byType(Scaffold).first).isDrawerOpen;

Future<void> _pumpRouter(WidgetTester tester, NotesHarness h) async {
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

Future<void> _openDrawer(WidgetTester tester) async {
  tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
  await tester.pumpAndSettle();
}

Future<void> _tapItem(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(AxoDrawer), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

String _location(NotesHarness h) => h.container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .last
    .matchedLocation;
