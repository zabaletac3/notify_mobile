import 'package:axonote_app/features/notes/state/notes_providers.dart';
import 'package:axonote_app/features/notes/ui/notes_screen.dart';
import 'package:axonote_app/features/notes/ui/search_screen.dart';
import 'package:axonote_app/features/notes/ui/trash_screen.dart';
import 'package:axonote_app/ui/components.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/notes_harness.dart';

/// Tarjeta de nota de la lista, por su título (para abrir el menú contextual).
Finder noteCard(String title) =>
    find.byWidgetPredicate((w) => w is AxoNoteCard && w.title == title);

/// Semilla del golden del menú lateral: las notas de la fase más una etiqueta, para que el drawer
/// muestre las tres secciones («Biblioteca», «Carpetas», «Etiquetas»).
Future<NotesHarness> _drawerHarness() async {
  final h = await buildNotesHarness();
  await h.local.local.notes.create(
    const NoteDraft(
      title: 'Con etiqueta',
      content: 'cuerpo',
      tags: ['parcial'],
    ),
  );
  return h;
}

/// Goldens de las pantallas de notas de la fase 9, en claro y oscuro (tableros «Android — …» de
/// Pencil). Ver `docs/design/pencil-measurements.md`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);

  testWidgets('lista de notas', (t) async {
    await notesGolden(
      t,
      'lista',
      buildNotesHarness,
      (_) => const NotesScreen(),
    );
  });

  testWidgets('primera vez (vacío)', (t) async {
    await notesGolden(
      t,
      'primera-vez',
      () => buildNotesHarness(seed: false),
      (_) => const NotesScreen(),
    );
  });

  testWidgets('menú lateral', (t) async {
    await notesGolden(
      t,
      'menu-lateral',
      _drawerHarness,
      (_) => const NotesScreen(),
      afterPump: (tester, _) async {
        tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('carpeta vacía', (t) async {
    await notesGolden(
      t,
      'carpeta-vacia',
      buildFoldersOnlyHarness,
      (h) => NotesScreen(folderId: h.folderIds['Ideas']),
    );
  });

  testWidgets('papelera', (t) async {
    await notesGolden(
      t,
      'papelera',
      buildTrashHarness,
      (_) => const TrashScreen(),
    );
  });

  testWidgets('resultados de búsqueda', (t) async {
    await notesGolden(t, 'resultados-busqueda', buildNotesHarness, (h) {
      h.container.read(searchQueryProvider.notifier).set('normalización');
      return const SearchScreen();
    });
  });

  testWidgets('búsqueda sin resultados', (t) async {
    await notesGolden(t, 'busqueda-sin-resultados', buildNotesHarness, (h) {
      h.container.read(searchQueryProvider.notifier).set('xylofón');
      return const SearchScreen();
    });
  });

  testWidgets('menú contextual de nota', (t) async {
    await notesGolden(
      t,
      'menu-contextual',
      buildNotesHarness,
      (_) => const NotesScreen(),
      afterPump: (tester, _) async {
        await tester.longPress(noteCard('Resumen: Bases de datos II'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('modal mover nota', (t) async {
    await notesGolden(
      t,
      'mover-nota',
      buildNotesHarness,
      (_) => const NotesScreen(),
      afterPump: (tester, _) async {
        await tester.longPress(noteCard('Resumen: Bases de datos II'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mover a carpeta'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('modal nueva carpeta', (t) async {
    await notesGolden(
      t,
      'nueva-carpeta',
      buildNotesHarness,
      (_) => const NotesScreen(),
      afterPump: (tester, _) async {
        await tester.longPress(noteCard('Resumen: Bases de datos II'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mover a carpeta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nueva carpeta'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('confirmar eliminación', (t) async {
    await notesGolden(
      t,
      'confirmar-eliminacion',
      buildNotesHarness,
      (_) => const NotesScreen(),
      afterPump: (tester, _) async {
        await tester.longPress(noteCard('Resumen: Bases de datos II'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Mover a la papelera'));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('conflicto de sincronización', (t) async {
    await notesGolden(
      t,
      'conflicto',
      buildConflictHarness,
      (_) => const NotesScreen(),
    );
  });

  testWidgets('cargando (skeletons)', (t) async {
    await notesGolden(
      t,
      'cargando',
      buildLoadingHarness,
      (_) => const NotesScreen(),
    );
  });

  testWidgets('sin conexión', (t) async {
    await notesGolden(
      t,
      'sin-conexion',
      buildOfflineHarness,
      (_) => const NotesScreen(),
    );
  });

  testWidgets('error de servidor', (t) async {
    await notesGolden(
      t,
      'error-servidor',
      buildErrorHarness,
      (_) => const NotesScreen(),
    );
  });
}
