import 'package:axonote_app/app/local_session.dart';
import 'package:axonote_app/bootstrap/providers.dart';
import 'package:axonote_app/features/auth/state/vault_lifecycle.dart';
import 'package:axonote_app/features/sync/state/sync_controller.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/features/vault/state/timer_factory.dart';
import 'package:axonote_app/features/vault/state/vault_lock.dart';
import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../data/local/local_harness.dart';
import '../../auth/support/fakes.dart';

/// Fecha base de las pruebas de la fase 9 (miércoles 14 de octubre de 2026, 09:30).
final DateTime baseNow = DateTime(2026, 10, 14, 9, 30);

/// Datos locales en memoria con las notas y carpetas de los tableros de la fase 9.
class NotesHarness {
  NotesHarness(this.local, this.clock, this.container, this.folderIds);

  final LocalHarness local;
  final FakeClock clock;
  final ProviderContainer container;
  final Map<String, Id> folderIds;
}

ProviderContainer _container(
  LocalHarness local,
  FakeClock clock, {
  NoteRepository? notes,
  FolderRepository? folders,
  bool locked = false,
  SyncController Function()? sync,
}) {
  return ProviderContainer(
    // Sin reintento automático: el de Riverpod deja un `Timer` pendiente que rompe las pruebas.
    retry: (_, _) => null,
    overrides: [
      noteRepositoryProvider.overrideWithValue(
        locked ? null : (notes ?? local.local.notes),
      ),
      folderRepositoryProvider.overrideWithValue(
        locked ? null : (folders ?? local.local.folders),
      ),
      clockProvider.overrideWithValue(clock),
      vaultTimerFactoryProvider.overrideWithValue(FakeTimerFactory(clock)),
      vaultLifecycleProvider.overrideWithValue(VaultLifecycle.none),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      vaultPrefsProvider.overrideWithValue(FakeVaultPrefs()),
      argon2idProvider.overrideWithValue(FakeArgon2id()),
      deviceNameProvider.overrideWithValue('Test'),
      localDataCleanerProvider.overrideWithValue(FakeCleaner()),
      if (sync != null) syncControllerProvider.overrideWith(sync),
    ],
  );
}

Future<NotesHarness> buildNotesHarness({bool seed = true}) async {
  AxonotePlatform.instance = FakeAxonotePlatform();
  final clock = FakeClock(baseNow);
  final local = LocalHarness(now: () => clock.now(), deviceId: 'd_test');
  final container = _container(local, clock);
  addTearDown(container.dispose);
  addTearDown(local.close);
  final folderIds = seed ? await _seed(local, clock) : <String, Id>{};
  return NotesHarness(local, clock, container, folderIds);
}

Future<NotesHarness> buildFoldersOnlyHarness() async {
  AxonotePlatform.instance = FakeAxonotePlatform();
  final clock = FakeClock(baseNow);
  final local = LocalHarness(now: () => clock.now(), deviceId: 'd_test');
  final container = _container(local, clock);
  addTearDown(container.dispose);
  addTearDown(local.close);
  final folderIds = await _seedFolders(local, clock);
  return NotesHarness(local, clock, container, folderIds);
}

/// Papelera con tres notas (una de ayer, una de hace 2 semanas y una de hace 3).
Future<NotesHarness> buildTrashHarness() async {
  final harness = await buildNotesHarness();
  for (final (title, daysAgo) in const [
    ('Plan del proyecto final', 1),
    ('Ejercicios de cálculo vectorial', 14),
    ('Notas de clase — Redes', 21),
  ]) {
    harness.clock.set(baseNow.subtract(Duration(days: daysAgo)));
    final all = await harness.local.local.notes.list();
    final note = all.firstWhere((n) => n.title == title);
    await harness.local.local.notes.moveToTrash(note.id);
  }
  harness.clock.set(baseNow);
  return harness;
}

/// Lista en carga: sin repositorio (cofre bloqueado), con las carpetas ya en memoria.
Future<NotesHarness> buildLoadingHarness() async {
  AxonotePlatform.instance = FakeAxonotePlatform();
  final clock = FakeClock(baseNow);
  final local = LocalHarness(now: () => clock.now(), deviceId: 'd_test');
  final container = _container(local, clock, locked: true);
  addTearDown(container.dispose);
  addTearDown(local.close);
  final folderIds = await _seedFolders(local, clock);
  return NotesHarness(local, clock, container, folderIds);
}

/// Lista con error del repositorio y sincronización en `offline`.
Future<NotesHarness> buildErrorHarness() async {
  AxonotePlatform.instance = FakeAxonotePlatform();
  final clock = FakeClock(baseNow);
  final local = LocalHarness(now: () => clock.now(), deviceId: 'd_test');
  final container = _container(
    local,
    clock,
    notes: _FailingNoteRepository(),
    folders: _FailingFolderRepository(),
    sync: _OfflineSyncController.new,
  );
  addTearDown(container.dispose);
  addTearDown(local.close);
  return NotesHarness(local, clock, container, const {});
}

/// Lista con un conflicto de sincronización pendiente.
Future<NotesHarness> buildConflictHarness() async {
  final harness = await buildNotesHarness();
  // Se cambia el controlador de sincronización por uno con un conflicto.
  final conflictContainer = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      noteRepositoryProvider.overrideWithValue(harness.local.local.notes),
      folderRepositoryProvider.overrideWithValue(harness.local.local.folders),
      clockProvider.overrideWithValue(harness.clock),
      syncControllerProvider.overrideWith(_ConflictSyncController.new),
    ],
  );
  addTearDown(conflictContainer.dispose);
  return NotesHarness(
    harness.local,
    harness.clock,
    conflictContainer,
    harness.folderIds,
  );
}

/// Sincronización en `offline` (aviso persistente) sobre datos reales.
Future<NotesHarness> buildOfflineHarness() async {
  final harness = await buildNotesHarness();
  final container = _container(
    harness.local,
    harness.clock,
    sync: _OfflineSyncController.new,
  );
  addTearDown(container.dispose);
  return NotesHarness(
    harness.local,
    harness.clock,
    container,
    harness.folderIds,
  );
}

Future<Map<String, Id>> _seedFolders(
  LocalHarness local,
  FakeClock clock,
) async {
  clock.set(DateTime(2026, 9, 20, 10, 0));
  final folders = local.local.folders;
  final ids = <String, Id>{};
  for (final name in const ['Universidad', 'Personal', 'Ideas', 'Recetas']) {
    ids[name] = (await folders.create(name)).id;
  }
  return ids;
}

Future<Map<String, Id>> _seed(LocalHarness local, FakeClock clock) async {
  final notes = local.local.notes;
  final ids = await _seedFolders(local, clock);
  final universidad = ids['Universidad']!;

  Future<void> note(
    String title,
    String content,
    DateTime when, {
    bool pinned = false,
  }) async {
    clock.set(when);
    await notes.create(
      NoteDraft(
        title: title,
        content: content,
        folderId: universidad,
        pinned: pinned,
      ),
    );
  }

  await note(
    'Notas de clase — Redes',
    'Modelo OSI vs TCP/IP, encapsulamiento y capas.',
    DateTime(2026, 9, 28, 11, 0),
  );
  await note(
    'Ejercicios de cálculo vectorial',
    'Taller 5: gradiente, divergencia y rotacional.',
    baseNow.subtract(const Duration(days: 3)),
  );
  await note(
    'Lectura — Diseño centrado en el usuario',
    'Capítulos 3 y 4. Ideas clave sobre modelos mentales.',
    baseNow.subtract(const Duration(days: 1)),
  );
  await note(
    'Resumen: Bases de datos II',
    'Normalización hasta 3FN, ejemplos con la tabla de pedidos.',
    DateTime(2026, 10, 14, 9, 12),
  );
  await note(
    'Plan del proyecto final',
    'Entregables: prototipo en Figma, app en Tauri y memoria.',
    DateTime(2026, 10, 14, 8, 0),
    pinned: true,
  );
  clock.set(baseNow);
  return ids;
}

/// Fija la sincronización en `offline` para el golden del aviso sin conexión.
class _OfflineSyncController extends SyncController {
  @override
  SyncUiState build() => const SyncUiState(
    phase: SyncPhase.offline,
    pendingCount: 0,
    conflicts: [],
    lastSyncedAt: null,
  );
}

/// Expone un conflicto pendiente para el golden de la hoja de conflicto.
class _ConflictSyncController extends SyncController {
  @override
  SyncUiState build() => const SyncUiState(
    phase: SyncPhase.idle,
    pendingCount: 1,
    conflicts: [
      Conflict(
        noteId: 'n1',
        local: NoteVersion(
          title: 'Resumen: Bases de datos II',
          content: 'Normalización hasta 3FN, ejemplos con dependencias.',
          editedAt: '2026-10-14T09:12:00.000Z',
          deviceName: 'Pixel 8',
        ),
        remote: NoteVersion(
          title: 'Resumen: Bases de datos II',
          content: 'Normalización hasta 2FN, pendientes: repasar ejercicios.',
          editedAt: '2026-10-14T09:10:00.000Z',
          deviceName: 'Laptop Fedora',
        ),
      ),
    ],
    lastSyncedAt: null,
  );
}

class _FailingNoteRepository implements NoteRepository {
  @override
  Future<List<Note>> list([NoteQuery query = const NoteQuery()]) async =>
      throw const AppFailure(NetworkError());

  @override
  Stream<List<Note>> watch([NoteQuery query = const NoteQuery()]) =>
      Stream<List<Note>>.error(const AppFailure(NetworkError()));

  Never _fail() => throw const AppFailure(NetworkError());

  @override
  Future<Note> get(Id id) async => _fail();

  @override
  Future<List<Note>> search(
    String term, [
    NoteQuery query = const NoteQuery(),
  ]) async => _fail();

  @override
  Future<Note> create([NoteDraft draft = const NoteDraft()]) async => _fail();

  @override
  Future<Note> update(Id id, NoteDraft patch) async => _fail();

  @override
  Future<Note> duplicate(Id id) async => _fail();

  @override
  Future<Note> moveToTrash(Id id) async => _fail();

  @override
  Future<Note> restore(Id id) async => _fail();

  @override
  Future<void> deleteForever(Id id) async => _fail();

  @override
  Future<int> emptyTrash() async => _fail();

  @override
  Future<NoteCounts> counts() async => _fail();
}

class _FailingFolderRepository implements FolderRepository {
  @override
  Future<List<Folder>> list() async => throw const AppFailure(NetworkError());

  @override
  Stream<List<Folder>> watch() =>
      Stream<List<Folder>>.error(const AppFailure(NetworkError()));

  @override
  Future<Folder> create(String name) async =>
      throw const AppFailure(NetworkError());

  @override
  Future<Folder> rename(Id id, String name) async =>
      throw const AppFailure(NetworkError());

  @override
  Future<void> delete(Id id) async => throw const AppFailure(NetworkError());
}

/// Envuelve [home] en el chasis del tablero (412×915, barra de estado 39 y de gestos 26). La
/// [Key] distinta por modo obliga a recrear el árbol (y su `Navigator`) entre el golden claro y el
/// oscuro: si no, una hoja modal abierta en el claro seguiría abierta en el oscuro.
Widget notesApp(
  ProviderContainer container,
  Widget home,
  ThemeData theme, {
  Key? key,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    key: key,
    debugShowCheckedModeBanner: false,
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(412, 915),
        padding: EdgeInsets.only(top: 39, bottom: 26),
        viewPadding: EdgeInsets.only(top: 39, bottom: 26),
      ),
      child: home,
    ),
  ),
);

Future<void> loadInter() async {
  final loader = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.otf'));
  }
  await loader.load();
}

/// Renderiza [home] en claro y oscuro y compara con los goldens `notes-<name>-<mode>.png`.
Future<void> notesGolden(
  WidgetTester tester,
  String name,
  Future<NotesHarness> Function() make,
  Widget Function(NotesHarness harness) home, {
  Future<void> Function(WidgetTester tester, NotesHarness harness)? afterPump,
}) async {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = const Size(824, 1830);
  addTearDown(tester.view.reset);
  final shadows = debugDisableShadows;
  debugDisableShadows = false;
  try {
    for (final (mode, theme) in [
      ('light', AxoTheme.light()),
      ('dark', AxoTheme.dark()),
    ]) {
      final harness = await make();
      await tester.pumpWidget(
        notesApp(
          harness.container,
          home(harness),
          theme,
          key: ValueKey('$name-$mode'),
        ),
      );
      await tester.pumpAndSettle();
      if (afterPump != null) {
        await afterPump(tester, harness);
        await tester.pumpAndSettle();
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/notes-$name-$mode.png'),
      );
    }
  } finally {
    debugDisableShadows = shadows;
  }
}
