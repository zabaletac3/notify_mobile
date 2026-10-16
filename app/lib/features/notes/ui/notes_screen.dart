import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../settings/state/settings_controller.dart';
import '../../sync/state/sync_controller.dart';
import '../state/notes_actions.dart';
import '../state/notes_providers.dart';
import '../state/notes_view.dart';
import 'conflict_sheet.dart';
import 'note_sheets.dart';
import 'notes_widgets.dart';

/// Pantalla de la lista de notas (`/notes` y `/folders/:id`). Tableros «Android — Lista de notas»,
/// «Primera vez (vacío)», «Carpeta vacía», «Cargando (skeletons)», «Sin conexión» y «Error de
/// servidor».
class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key, this.folderId});

  /// Si viene, la pantalla es la de una carpeta (`/folders/:id`): título, chips y FAB apuntan a esa
  /// carpeta.
  final Id? folderId;

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> {
  /// Se necesita la clave del `Scaffold` para abrir el drawer desde la barra superior: el `context`
  /// del `build` está por encima del `Scaffold` y `Scaffold.of(context)` fallaría.
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// «Abrir con una nota nueva»: se abre una sola vez por visita a la lista.
  bool _openedNewNote = false;

  @override
  Widget build(BuildContext context) {
    final folderId = widget.folderId;
    final c = Theme.of(context).extension<AxoColors>()!;
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final counts = ref.watch(noteCountsProvider).value;
    final notesAsync = folderId == null
        ? ref.watch(notesListProvider)
        : ref.watch(folderNotesProvider(folderId));
    final offline =
        ref.watch(syncControllerProvider).phase == SyncPhase.offline;
    final now = ref.watch(clockProvider).now();
    final showPreview = ref.watch(settingsProvider).showPreview;

    // Cuando aparece un conflicto, se ofrece resolverlo (una vez por nota).
    ref.listen(syncControllerProvider, (_, next) {
      final conflict = next.firstConflict;
      if (conflict == null) return;
      if (ref.read(shownConflictProvider) == conflict.noteId) return;
      ref.read(shownConflictProvider.notifier).mark(conflict.noteId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showConflictSheet(context, ref, conflict: conflict);
      });
    });

    final folderName = folderId == null ? null : _folderName(folders, folderId);
    final title = folderId == null
        ? 'Todas las notas'
        : (folderName ?? 'Carpeta');

    final folderNames = {for (final f in folders) f.id: f.name};
    final notes = notesAsync.value ?? const <Note>[];
    final rows = folderId == null
        ? ref.watch(notesRowsProvider)
        : groupRows(notes, now);
    final loading = notesAsync.isLoading && !notesAsync.hasValue;
    final error = notesAsync.hasError;
    final firstTimeEmpty =
        !loading &&
            !error &&
            notes.isEmpty &&
            folderId == null &&
            counts != null
        ? counts.all == 0
        : false;

    Widget body;
    if (firstTimeEmpty) {
      body = _SearchBarButton(
        onTap: () => context.push('/search'),
        child: const AxoEmptyState(
          logo: true,
          illustrationText: 'A',
          title: 'Bienvenido a AxoNote',
          subtitle: 'Aquí vivirán tus apuntes, listas y ideas. Escribe tu primera nota para empezar.',
          footer: _FirstNoteButton(),
        ),
      );
    } else if (loading) {
      body = _LoadingBody(folders: folders, selectedFolderId: folderId);
    } else if (error) {
      body = _SearchBarButton(
        onTap: () => context.push('/search'),
        child: const AxoEmptyState(
          danger: true,
          illustrationText: '!',
          title: 'No pudimos conectar con el servidor',
          subtitle: 'Algo falló de nuestro lado. Tus notas están a salvo en este dispositivo. Inténtalo de nuevo en unos minutos.',
          footer: _RetryButton(),
        ),
      );
    } else {
      final total = _totalFor(
        counts,
        ref.watch(notesViewProvider).filter,
        folderId,
      );
      final children = <Widget>[
        if (!firstTimeEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                total == null
                    ? (notes.length == 1 ? '1 nota' : '${notes.length} notas')
                    : (total == 1 ? '1 nota' : '$total notas'),
                style: AxoType.label.copyWith(color: c.textSecondary),
              ),
            ),
          ),
        _SearchBarButton(
          onTap: () => context.push('/search'),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        if (folders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FolderChipsRow(
              folders: folders,
              selectedFolderId: folderId,
              onSelect: (id) => _goFolder(context, ref, id),
            ),
          ),
        Expanded(
          child: notes.isEmpty
              ? AxoEmptyState(
                  icon: 'folder',
                  title: folderId == null
                      ? 'Aquí no hay notas'
                      : 'Esta carpeta está vacía',
                  subtitle: 'Crea una nota nueva o mueve aquí notas de otras carpetas.',
                  footer: _NewNoteButton(folderId: folderId),
                )
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Carga la página siguiente solo cuando la ventana ya está llena (evita crecer
                    // sin control mientras se desplaza).
                    final window = ref.read(notesWindowProvider);
                    if (notes.length >= window &&
                        notification.metrics.extentAfter < 600) {
                      ref.read(notesWindowProvider.notifier).loadMore();
                    }
                    return false;
                  },
                  child: NoteGroupsList(
                    rows: rows,
                    now: now,
                    showPreview: showPreview,
                    folderNames: folderNames,
                    onOpen: (note) => context.push('/notes/${note.id}'),
                    onLongPress: (note) => showNoteContextSheet(
                      context,
                      ref,
                      note: note,
                      folderName: note.folderId == null
                          ? null
                          : folderNames[note.folderId],
                    ),
                    // Gestos (ver `docs/decisions.md`): derecha fija/desfija, izquierda a la
                    // papelera (con deshacer, como el aviso de la web).
                    swipeStart: (note) => AxoSwipeAction(
                      label: note.pinned ? 'Desfijar' : 'Fijar',
                      icon: 'pin',
                      color: c.bgSelected,
                      foreground: c.accentDefault,
                      stays: true,
                      onInvoke: () => runNoteAction(
                        context,
                        ref,
                        () => ref.read(notesActionsProvider).togglePin(note),
                        successMessage: note.pinned
                            ? 'Nota desfijada'
                            : 'Nota fijada',
                        errorMessage: 'No se pudo fijar la nota',
                      ),
                    ),
                    swipeEnd: (note) => AxoSwipeAction(
                      label: 'Papelera',
                      icon: 'trash',
                      color: c.statusDanger,
                      foreground: c.accentOn,
                      onInvoke: () => runNoteAction(
                        context,
                        ref,
                        () =>
                            ref.read(notesActionsProvider).moveToTrash(note.id),
                        successMessage: 'Nota movida a la papelera',
                        errorMessage: 'No se pudo mover la nota',
                        undoLabel: 'Deshacer',
                        onUndo: () {
                          ref.read(notesActionsProvider).restore(note.id);
                        },
                      ),
                    ),
                  ),
                ),
        ),
      ];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }

    // «Abrir con una nota nueva»: al mostrar la lista, abre una nota nueva una sola vez.
    if (!_openedNewNote &&
        !loading &&
        !error &&
        folderId == null &&
        ref.read(settingsProvider).openWithNewNote) {
      _openedNewNote = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _newNote(context, ref, null);
      });
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: c.bgApp,
      drawer: _buildDrawer(
        context,
        ref,
        folderId: folderId,
        folders: folders,
        counts: counts,
      ),
      floatingActionButton: AxoFab(
        label: 'Nueva nota',
        onPressed: () => _newNote(context, ref, folderId),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NotesTopBar(
              title: title,
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onTitleTap: () => _scaffoldKey.currentState?.openDrawer(),
              actions: [
                NotesIconButton(
                  icon: 'ellipsis',
                  onTap: () => showSortSheet(context, ref, folderId),
                ),
              ],
            ),
            if (offline)
              AxoOfflineBanner(
                message: 'Sin conexión. Tus cambios se guardan aquí y se sincronizarán al volver.',
                onRetry: () =>
                    ref.read(syncControllerProvider.notifier).syncNow(),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

String? _folderName(List<Folder> folders, Id id) {
  for (final folder in folders) {
    if (folder.id == id) return folder.name;
  }
  return null;
}

/// Total de notas de la vista actual para el conteo de la cabecera («12 notas»). En una carpeta
/// abierta por ruta directa (`/folders/:id`), aunque el filtro aún no se haya fijado, se cuenta la
/// carpeta de la ruta.
int? _totalFor(NoteCounts? counts, NotesFilter filter, Id? routeFolderId) {
  if (counts == null) return null;
  if (routeFolderId != null && filter is NotesFilterAll) {
    return counts.byFolder[routeFolderId] ?? 0;
  }
  return switch (filter) {
    NotesFilterAll() => counts.all,
    NotesFilterPinned() => counts.pinned,
    NotesFilterFolder(:final folderId) => counts.byFolder[folderId] ?? 0,
    NotesFilterTag(:final tag) => counts.byTag[tag] ?? 0,
    NotesFilterTrash() => counts.trash,
  };
}

void _goFolder(BuildContext context, WidgetRef ref, Id? folderId) {
  ref
      .read(notesViewProvider.notifier)
      .setFilter(
        folderId == null ? const NotesFilterAll() : NotesFilterFolder(folderId),
      );
  if (folderId == null) {
    context.go('/notes');
  } else {
    context.go('/folders/$folderId');
  }
}

Future<void> _newNote(BuildContext context, WidgetRef ref, Id? folderId) async {
  final result = await ref
      .read(notesActionsProvider)
      .create(folderId: folderId);
  if (!context.mounted) return;
  switch (result) {
    case Ok(value: final note):
      await context.push('/notes/${note.id}');
    case Err(error: final error):
      showErrorToast(context, error);
  }
}

Widget _buildDrawer(
  BuildContext context,
  WidgetRef ref, {
  required Id? folderId,
  required List<Folder> folders,
  required NoteCounts? counts,
}) {
  final filter = ref.watch(notesViewProvider).filter;
  final countsByFolder = counts?.byFolder ?? const <Id, int>{};
  final tags = (counts?.byTag ?? const <String, int>{}).entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  final loading = counts == null;
  return AxoDrawer(
    onClose: () => Navigator.of(context).pop(),
    sections: [
      const AxoDrawerSection(label: 'Biblioteca'),
      AxoDrawerItem(
        label: 'Todas las notas',
        icon: 'file-text',
        count: counts?.all.toString(),
        loading: loading,
        selected: folderId == null && filter is NotesFilterAll,
        onTap: () {
          Navigator.of(context).pop();
          _goFolder(context, ref, null);
        },
      ),
      AxoDrawerItem(
        label: 'Fijadas',
        icon: 'pin',
        count: counts?.pinned.toString(),
        loading: loading,
        selected: filter is NotesFilterPinned,
        onTap: () {
          Navigator.of(context).pop();
          ref
              .read(notesViewProvider.notifier)
              .setFilter(const NotesFilterPinned());
          context.go('/notes');
        },
      ),
      const AxoDrawerSection(label: 'Carpetas'),
      for (final folder in folders)
        AxoDrawerItem(
          label: folder.name,
          icon: 'folder',
          count: countsByFolder[folder.id]?.toString(),
          loading: loading,
          selected:
              folderId == folder.id ||
              (filter is NotesFilterFolder && filter.folderId == folder.id),
          onTap: () {
            Navigator.of(context).pop();
            _goFolder(context, ref, folder.id);
          },
        ),
      if (tags.isNotEmpty) ...[
        const AxoDrawerSection(label: 'Etiquetas'),
        for (final tag in tags)
          AxoDrawerItem(
            label: '#${tag.key}',
            icon: 'tag',
            count: '${tag.value}',
            selected: filter is NotesFilterTag && filter.tag == tag.key,
            onTap: () {
              Navigator.of(context).pop();
              ref
                  .read(notesViewProvider.notifier)
                  .setFilter(NotesFilterTag(tag.key));
              context.go('/notes');
            },
          ),
      ],
      const SizedBox(height: AxoSpacing.lg),
    ],
    footer: [
      AxoDrawerItem(
        label: 'Papelera',
        icon: 'trash',
        count: counts?.trash.toString(),
        loading: loading,
        selected: filter is NotesFilterTrash,
        onTap: () {
          Navigator.of(context).pop();
          context.push('/trash');
        },
      ),
      AxoDrawerNewFolder(
        onTap: () {
          // Se cierra el drawer y el diálogo se abre con el context estable de la pantalla, no el
          // del drawer, que se desmonta.
          Navigator.of(context).pop();
          showNewFolderSheet(context, ref);
        },
      ),
      const SizedBox(height: AxoSpacing.xs),
      AxoDrawerItem(
        label: 'Ajustes',
        icon: 'settings',
        onTap: () {
          Navigator.of(context).pop();
          context.push('/settings/menu');
        },
      ),
    ],
  );
}

class _SearchBarButton extends StatelessWidget {
  const _SearchBarButton({required this.onTap, this.child, this.padding});

  final VoidCallback onTap;
  final Widget? child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final field = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: AxoSizes.searchBar,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: c.bgInput,
          borderRadius: BorderRadius.circular(AxoRadii.card),
        ),
        child: Row(
          children: [
            AppIcon('search', size: 20, color: c.textSecondary),
            const SizedBox(width: AxoSpacing.md),
            Text(
              'Buscar notas',
              style: AxoType.search.copyWith(color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
    if (child == null) {
      return Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 12),
        child: field,
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: field,
        ),
        Expanded(child: child!),
      ],
    );
  }
}

class _FirstNoteButton extends ConsumerWidget {
  const _FirstNoteButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AxoButton(
      label: 'Crear mi primera nota',
      labelStyle: AxoType.buttonSm,
      onPressed: () => _newNote(context, ref, null),
    );
  }
}

class _NewNoteButton extends ConsumerWidget {
  const _NewNoteButton({this.folderId});

  final Id? folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AxoButton(
      label: 'Nueva nota',
      labelStyle: AxoType.buttonSm,
      onPressed: () => _newNote(context, ref, folderId),
    );
  }
}

class _RetryButton extends ConsumerWidget {
  const _RetryButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AxoButton(
      label: 'Reintentar',
      labelStyle: AxoType.buttonSm,
      onPressed: () => ref.invalidate(notesListProvider),
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.folders, required this.selectedFolderId});

  final List<Folder> folders;
  final Id? selectedFolderId;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            height: AxoSizes.searchBar,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: c.bgInput,
              borderRadius: BorderRadius.circular(AxoRadii.card),
            ),
            child: Row(
              children: [
                AppIcon('search', size: 20, color: c.textSecondary),
                const SizedBox(width: AxoSpacing.md),
                Text(
                  'Buscar notas',
                  style: AxoType.search.copyWith(color: c.textTertiary),
                ),
              ],
            ),
          ),
        ),
        if (folders.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FolderChipsRow(
              folders: folders,
              selectedFolderId: selectedFolderId,
              onSelect: (_) {},
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: AxoSkeleton(width: 70, height: 12),
        ),
        const Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                SizedBox(height: AxoSpacing.sm),
                AxoNoteSkeleton(),
                AxoNoteSkeleton(),
                AxoNoteSkeleton(),
                AxoNoteSkeleton(),
                AxoNoteSkeleton(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
