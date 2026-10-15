import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../router/navigation.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../sync/state/sync_controller.dart';
import '../state/note_dates.dart';
import '../state/notes_providers.dart';
import 'note_sheets.dart';
import 'notes_widgets.dart';

/// Pantalla de búsqueda (tableros «Android — Resultados de búsqueda» y «Búsqueda sin resultados»):
/// buscador editable con el término, conteo de resultados, lista con el término resaltado y estado
/// vacío con «Borrar búsqueda».
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(searchQueryProvider),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final term = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final results = resultsAsync.value ?? const <Note>[];
    final folders = ref.watch(foldersProvider).value ?? const <Folder>[];
    final folderNames = {for (final f in folders) f.id: f.name};
    final offline =
        ref.watch(syncControllerProvider).phase == SyncPhase.offline;
    final now = ref.watch(clockProvider).now();

    return PopScope(
      canPop: canGoBack(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goBack(context);
      },
      child: Scaffold(
        backgroundColor: c.bgApp,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              NotesTopBar(
                title: 'Buscar',
                onMenu: () => goBack(context),
                leadingIcon: 'arrow-left',
                leadingSize: 24,
              ),
              if (offline)
                AxoOfflineBanner(
                  message: 'Sin conexión. Buscando solo en este dispositivo.',
                  onRetry: () =>
                      ref.read(syncControllerProvider.notifier).syncNow(),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          results.length == 1
                              ? '1 resultado'
                              : '${results.length} resultados',
                          style: AxoType.label.copyWith(color: c.textSecondary),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: AxoSearchField(
                        controller: _controller,
                        autofocus: true,
                        onChanged: (value) =>
                            ref.read(searchQueryProvider.notifier).set(value),
                        onClear: () =>
                            ref.read(searchQueryProvider.notifier).clear(),
                      ),
                    ),
                    const SizedBox(height: AxoSpacing.sm),
                    Expanded(
                      child: term.trim().isEmpty
                          ? const SizedBox.shrink()
                          : results.isEmpty
                          ? AxoEmptyState(
                              icon: 'search',
                              title: 'Sin resultados',
                              subtitle:
                                  'No encontramos notas con “$term”. Revisa la ortografía o prueba con otra palabra.',
                              footer: AxoButton(
                                label: 'Borrar búsqueda',
                                labelStyle: AxoType.buttonSm,
                                variant: AxoButtonVariant.outline,
                                onPressed: () {
                                  _controller.clear();
                                  ref
                                      .read(searchQueryProvider.notifier)
                                      .clear();
                                },
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              children: [
                                for (final note in results)
                                  AxoNoteCard(
                                    title: note.title.isEmpty
                                        ? 'Sin título'
                                        : note.title,
                                    preview: notePreview(note),
                                    date: noteListDate(note.updatedAt, now),
                                    pinned: note.pinned,
                                    unreadable: note.unreadable,
                                    folderLabel: note.folderId == null
                                        ? null
                                        : folderNames[note.folderId],
                                    highlight: term,
                                    onTap: () =>
                                        context.push('/notes/${note.id}'),
                                    onLongPress: () => showNoteContextSheet(
                                      context,
                                      ref,
                                      note: note,
                                      folderName: note.folderId == null
                                          ? null
                                          : folderNames[note.folderId],
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
