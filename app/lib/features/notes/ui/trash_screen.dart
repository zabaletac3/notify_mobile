import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../router/navigation.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../state/note_dates.dart';
import '../state/notes_actions.dart';
import '../state/notes_providers.dart';
import 'note_sheets.dart';
import 'notes_widgets.dart';

/// Pantalla de la papelera (tablero «Android — Papelera»): aviso de los 30 días, notas con los días
/// que les quedan y acción «Vaciar».
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final notesAsync = ref.watch(trashNotesProvider);
    final notes = notesAsync.value ?? const <Note>[];
    final loading = notesAsync.isLoading && !notesAsync.hasValue;
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
                title: 'Papelera',
                leadingIcon: 'arrow-left',
                leadingSize: 24,
                onMenu: () => goBack(context),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextButton(
                      onPressed: notes.isEmpty
                          ? null
                          : () =>
                                _confirmEmptyTrash(context, ref, notes.length),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: Text(
                        'Vaciar',
                        style: AxoType.chipActive.copyWith(
                          color: c.accentDefault,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          children: [
                            AxoNoteSkeleton(),
                            AxoNoteSkeleton(),
                            AxoNoteSkeleton(),
                          ],
                        ),
                      )
                    : notes.isEmpty
                    ? const AxoEmptyState(
                        icon: 'trash',
                        title: 'La papelera está vacía',
                        subtitle: 'Las notas que muevas a la papelera aparecerán aquí durante 30 días.',
                      )
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: AxoBanner(
                              variant: AxoBannerVariant.note,
                              message: 'Las notas de la papelera se eliminan definitivamente después de 30 días.',
                            ),
                          ),
                          for (final note in notes)
                            AxoSwipeTile(
                              itemKey: ValueKey('trash-${note.id}'),
                              startAction: AxoSwipeAction(
                                label: 'Restaurar',
                                icon: 'arrow-left',
                                color: c.bgSelected,
                                foreground: c.accentDefault,
                                onInvoke: () => runNoteAction(
                                  context,
                                  ref,
                                  () => ref
                                      .read(notesActionsProvider)
                                      .restore(note.id),
                                  successMessage: 'Nota restaurada',
                                  errorMessage: 'No se pudo restaurar la nota',
                                ),
                              ),
                              endAction: AxoSwipeAction(
                                label: 'Eliminar',
                                icon: 'trash',
                                color: c.statusDanger,
                                foreground: c.accentOn,
                                // La eliminación definitiva no se deshace: se confirma.
                                stays: true,
                                onInvoke: () async => showDeleteForeverDialog(
                                  context,
                                  ref,
                                  note: note,
                                ),
                              ),
                              child: AxoNoteCard(
                                title: note.title.isEmpty
                                    ? 'Sin título'
                                    : note.title,
                                preview: notePreview(note),
                                date: trashDate(note.updatedAt, now),
                                unreadable: note.unreadable,
                                folderLabel: purgeLabel(
                                  daysUntilPurge(
                                    note.deletedAt ?? note.updatedAt,
                                    now,
                                    trashRetentionDays,
                                  ),
                                ),
                                onTap: () => showNoteContextSheet(
                                  context,
                                  ref,
                                  note: note,
                                  trashed: true,
                                ),
                                onLongPress: () => showNoteContextSheet(
                                  context,
                                  ref,
                                  note: note,
                                  trashed: true,
                                ),
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

  void _confirmEmptyTrash(BuildContext context, WidgetRef ref, int count) {
    showConfirmEmptyTrashDialog(context, ref, count: count);
  }
}
