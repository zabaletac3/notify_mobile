import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/app_icon.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../auth/state/auth_controller.dart';
import '../../vault/state/vault_lock.dart';
import '../state/note_dates.dart';
import '../state/notes_actions.dart';
import '../state/notes_providers.dart';
import '../state/notes_view.dart';

/// Muestra un aviso efímero con un mensaje de error legible (traducido del `kind`).
void showErrorToast(BuildContext context, AppError error) {
  final message = switch (error) {
    NetworkError() => 'Sin conexión. Inténtalo de nuevo.',
    DecryptError() => 'No se pudo descifrar esta nota.',
    NotFoundError() => 'No encontramos esa nota.',
    LockedError() => 'La app está bloqueada.',
    _ => 'No se pudo completar la acción. Inténtalo de nuevo.',
  };
  showAxoToast(context, message: message, variant: AxoToastVariant.error);
}

/// Menú contextual de una nota (tablero «Android — Menú contextual de nota»). En la papelera
/// ofrece restaurar y eliminar definitivamente.
Future<void> showNoteContextSheet(
  BuildContext context,
  WidgetRef ref, {
  required Note note,
  String? folderName,
  bool trashed = false,
}) async {
  final now = ref.read(clockNowProvider)();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final c = Theme.of(sheetContext).extension<AxoColors>()!;
      final meta = [
        ?folderName,
        if (trashed)
          trashDate(note.updatedAt, now)
        else
          noteListDate(note.updatedAt, now),
      ].join(' · ');
      return AxoBottomSheet(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title.isEmpty ? 'Sin título' : note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AxoType.sheetTitle.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: AxoType.label.copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AxoSpacing.lg),
          AxoSheetActions(
            children: trashed
                ? [
                    AxoOptionRow(
                      label: 'Restaurar',
                      icon: 'arrow-left',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        runNoteAction(
                          context,
                          ref,
                          () => ref.read(notesActionsProvider).restore(note.id),
                          successMessage: 'Nota restaurada',
                          errorMessage: 'No se pudo restaurar la nota',
                        );
                      },
                    ),
                    AxoOptionRow(
                      label: 'Eliminar definitivamente',
                      icon: 'trash',
                      destructive: true,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        showDeleteForeverDialog(context, ref, note: note);
                      },
                    ),
                  ]
                : [
                    AxoOptionRow(
                      label: note.pinned ? 'Desfijar' : 'Fijar nota',
                      icon: 'pin',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        runNoteAction(
                          context,
                          ref,
                          () => ref.read(notesActionsProvider).togglePin(note),
                          successMessage: note.pinned
                              ? 'Nota desfijada'
                              : 'Nota fijada',
                          errorMessage: 'No se pudo fijar la nota',
                        );
                      },
                    ),
                    AxoOptionRow(
                      label: 'Mover a carpeta',
                      icon: 'folder',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        showMoveSheet(context, ref, note: note);
                      },
                    ),
                    AxoOptionRow(
                      label: 'Cambiar nombre',
                      icon: 'pencil',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        showRenameDialog(context, ref, note: note);
                      },
                    ),
                    AxoOptionRow(
                      label: 'Duplicar',
                      icon: 'copy',
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        runNoteAction(
                          context,
                          ref,
                          () =>
                              ref.read(notesActionsProvider).duplicate(note.id),
                          successMessage: 'Nota duplicada',
                          errorMessage: 'No se pudo duplicar la nota',
                        );
                      },
                    ),
                    AxoOptionRow(
                      label: 'Mover a la papelera',
                      icon: 'trash',
                      destructive: true,
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        showConfirmTrashDialog(context, ref, note: note);
                      },
                    ),
                  ],
          ),
        ],
      );
    },
  );
}

/// Selector de carpeta para mover una nota (tablero «Android — Modal mover nota»).
Future<void> showMoveSheet(
  BuildContext context,
  WidgetRef ref, {
  required Note note,
}) async {
  final folders = ref.read(foldersProvider).value ?? const <Folder>[];
  Id? selected = note.folderId;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setState) {
          final c = Theme.of(sheetContext).extension<AxoColors>()!;
          return AxoBottomSheet(
            children: [
              Text(
                'Mover a carpeta',
                style: AxoType.dialogTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AxoSpacing.md),
              Text(
                '“${note.title.isEmpty ? 'Sin título' : note.title}”',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AxoType.bodySmall.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AxoSpacing.lg),
              Container(
                decoration: BoxDecoration(
                  color: c.bgApp,
                  borderRadius: BorderRadius.circular(AxoRadii.xl),
                  border: Border.all(color: c.borderDefault),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < folders.length + 1; i++) ...[
                      if (i > 0) Container(height: 1, color: c.borderDefault),
                      if (i == 0)
                        _MoveRow(
                          label: 'Sin carpeta',
                          icon: 'folder',
                          selected: selected == null,
                          onTap: () => setState(() => selected = null),
                        )
                      else
                        _MoveRow(
                          label: folders[i - 1].name,
                          icon: 'folder',
                          selected: selected == folders[i - 1].id,
                          onTap: () =>
                              setState(() => selected = folders[i - 1].id),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AxoSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    showNewFolderSheet(context, ref, moveNoteId: note.id);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+',
                        style: AxoType.heading.copyWith(color: c.accentDefault),
                      ),
                      const SizedBox(width: AxoSpacing.sm),
                      Text(
                        'Nueva carpeta',
                        style: AxoType.chipActive.copyWith(
                          color: c.accentDefault,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AxoSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AxoButton(
                      label: 'Cancelar',
                      labelStyle: AxoType.buttonSm,
                      variant: AxoButtonVariant.outline,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                  const SizedBox(width: AxoSpacing.md),
                  Expanded(
                    child: AxoButton(
                      label: 'Mover aquí',
                      labelStyle: AxoType.buttonSm,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        runNoteAction(
                          context,
                          ref,
                          () => ref
                              .read(notesActionsProvider)
                              .moveToFolder(note.id, selected),
                          successMessage: selected == null
                              ? 'Nota movida'
                              : 'Nota movida a ${_folderNameOf(folders, selected!)}',
                          errorMessage: 'No se pudo mover la nota',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            AxoRadio(selected: selected, onTap: onTap),
            const SizedBox(width: AxoSpacing.md),
            AppIcon(icon, size: 18, color: c.textSecondary),
            const SizedBox(width: AxoSpacing.md),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: (selected ? AxoType.buttonSm : AxoType.bodyUi).copyWith(
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo «Nueva carpeta» (tablero «Android — Modal nueva carpeta»). Si viene [moveNoteId] (se
/// creó desde «Mover a carpeta»), la nota se mueve a la carpeta nueva, como en la web.
Future<void> showNewFolderSheet(
  BuildContext context,
  WidgetRef ref, {
  Id? moveNoteId,
}) async {
  final controller = TextEditingController();
  final created = await showDialog<String>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      child: _NewFolderDialog(controller: controller),
    ),
  );
  controller.dispose();
  if (created == null || !context.mounted) return;
  final actions = ref.read(notesActionsProvider);
  final result = await actions.createFolder(created);
  if (!context.mounted) return;
  switch (result) {
    case Ok(value: final folder):
      if (moveNoteId != null) {
        final moved = await actions.moveToFolder(moveNoteId, folder.id);
        if (!context.mounted) return;
        switch (moved) {
          case Ok():
            showAxoToast(
              context,
              message: 'Nota movida a ${folder.name}',
              variant: AxoToastVariant.success,
            );
          case Err(error: final error):
            showErrorToast(context, error);
        }
        return;
      }
      showAxoToast(
        context,
        message: 'Carpeta creada',
        variant: AxoToastVariant.success,
      );
    case Err():
      showAxoToast(
        context,
        message: 'No se pudo crear la carpeta',
        variant: AxoToastVariant.error,
      );
  }
}

String _folderNameOf(List<Folder> folders, Id id) {
  for (final folder in folders) {
    if (folder.id == id) return folder.name;
  }
  return '';
}

class _NewFolderDialog extends StatefulWidget {
  const _NewFolderDialog({required this.controller});

  final TextEditingController controller;

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return AxoDialog(
      title: 'Nueva carpeta',
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Organiza tus notas por tema, curso o proyecto.',
            style: AxoType.bodySmall.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AxoSpacing.lg),
          Text('Nombre', style: AxoType.label.copyWith(color: c.textPrimary)),
          const SizedBox(height: 6),
          Container(
            height: AxoSizes.input,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: c.bgEditor,
              borderRadius: BorderRadius.circular(AxoRadii.lg),
              border: Border.all(color: c.accentDefault, width: 2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    autofocus: true,
                    maxLength: folderNameMaxLength,
                    onChanged: (_) => setState(() {}),
                    style: AxoType.bodyUi.copyWith(color: c.textPrimary),
                    cursorColor: c.accentDefault,
                    decoration: const InputDecoration(
                      isDense: true,
                      counterText: '',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AxoSpacing.xs),
          Text(
            '${widget.controller.text.characters.length}/$folderNameMaxLength',
            style: AxoType.caption.copyWith(color: c.textTertiary),
          ),
        ],
      ),
      actions: [
        AxoButton(
          label: 'Cancelar',
          labelStyle: AxoType.buttonSm,
          variant: AxoButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AxoButton(
          label: 'Crear',
          labelStyle: AxoType.buttonSm,
          onPressed: () {
            final name = widget.controller.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(name);
          },
        ),
      ],
    );
  }
}

/// Diálogo «Confirmar eliminación» (tablero «Android — Confirmar eliminación»).
Future<void> showConfirmTrashDialog(
  BuildContext context,
  WidgetRef ref, {
  required Note note,
}) async {
  final c = Theme.of(context).extension<AxoColors>()!;
  final title = note.title.isEmpty ? 'Sin título' : note.title;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      child: AxoDialog(
        danger: true,
        icon: 'trash',
        title: '¿Mover a la papelera?',
        content: Text(
          '“$title” se conservará 30 días en la papelera. Puedes restaurarla cuando quieras.',
          style: AxoType.bodySmall.copyWith(color: c.textSecondary),
        ),
        actions: [
          AxoButton(
            label: 'Cancelar',
            labelStyle: AxoType.buttonSm,
            variant: AxoButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AxoButton(
            label: 'Mover a la papelera',
            labelStyle: AxoType.buttonSm,
            variant: AxoButtonVariant.destructive,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              runNoteAction(
                context,
                ref,
                () => ref.read(notesActionsProvider).moveToTrash(note.id),
                successMessage: 'Nota movida a la papelera',
                errorMessage: 'No se pudo mover la nota',
                undoLabel: 'Deshacer',
                onUndo: () {
                  ref.read(notesActionsProvider).restore(note.id);
                },
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// Diálogo de eliminación definitiva (desde la papelera).
Future<void> showDeleteForeverDialog(
  BuildContext context,
  WidgetRef ref, {
  required Note note,
}) async {
  final c = Theme.of(context).extension<AxoColors>()!;
  final title = note.title.isEmpty ? 'Sin título' : note.title;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      child: AxoDialog(
        danger: true,
        icon: 'trash',
        title: '¿Eliminar esta nota?',
        content: Text(
          '“$title” se borrará para siempre. Esta acción no se puede deshacer.',
          style: AxoType.bodySmall.copyWith(color: c.textSecondary),
        ),
        actions: [
          AxoButton(
            label: 'Cancelar',
            labelStyle: AxoType.buttonSm,
            variant: AxoButtonVariant.outline,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          AxoButton(
            label: 'Eliminar',
            labelStyle: AxoType.buttonSm,
            variant: AxoButtonVariant.destructive,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              runNoteAction(
                context,
                ref,
                () => ref.read(notesActionsProvider).deleteForever(note.id),
                successMessage: 'Nota eliminada definitivamente',
                errorMessage: 'No se pudo eliminar la nota',
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// Diálogo para cambiar el nombre (título) de una nota.
Future<void> showRenameDialog(
  BuildContext context,
  WidgetRef ref, {
  required Note note,
}) async {
  final controller = TextEditingController(text: note.title);
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: AxoDialog(
          title: 'Cambiar nombre',
          content: AxoField(
            label: 'Título',
            controller: controller,
            autofocus: true,
          ),
          actions: [
            AxoButton(
              label: 'Cancelar',
              labelStyle: AxoType.buttonSm,
              variant: AxoButtonVariant.outline,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            AxoButton(
              label: 'Guardar',
              labelStyle: AxoType.buttonSm,
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  if (name == null || name.isEmpty || !context.mounted) return;
  await runNoteAction(
    context,
    ref,
    () => ref.read(notesActionsProvider).rename(note.id, name),
    successMessage: 'Nombre cambiado',
    errorMessage: 'No se pudo cambiar el nombre',
  );
}

/// Menú de la lista desde el botón «más»: orden (sin tablero propio, compuesto con los componentes
/// base) y, mientras no existan los ajustes de la fase 11, el bloqueo y el cierre de sesión.
Future<void> showSortSheet(
  BuildContext context,
  WidgetRef ref,
  Id? folderId,
) async {
  final current = ref.read(notesViewProvider).sort;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final c = Theme.of(sheetContext).extension<AxoColors>()!;
      return AxoBottomSheet(
        children: [
          Text(
            'Ordenar por',
            style: AxoType.dialogTitle.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AxoSpacing.lg),
          AxoSheetActions(
            children: [
              for (final (sort, label) in const [
                (NoteSort.updated, 'Última edición'),
                (NoteSort.created, 'Fecha de creación'),
                (NoteSort.title, 'Título'),
              ])
                AxoOptionRow(
                  label: label,
                  icon: sort == current ? 'check' : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    ref.read(notesViewProvider.notifier).setSort(sort);
                  },
                ),
            ],
          ),
          const SizedBox(height: AxoSpacing.lg),
          AxoSheetActions(
            children: [
              AxoOptionRow(
                label: 'Bloquear',
                icon: 'lock',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(vaultLockControllerProvider).lock();
                },
              ),
              AxoOptionRow(
                label: 'Cerrar sesión',
                icon: 'log-out',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(authControllerProvider.notifier).logout();
                },
              ),
            ],
          ),
        ],
      );
    },
  );
}

/// Ejecuta una acción de nota y muestra el resultado como aviso. [errorMessage] usa el texto de la
/// web para ese fallo (p. ej. «No se pudo mover la nota»); sin él, se traduce el `kind`.
/// [undoLabel]/[onUndo] añaden la acción de deshacer (como el aviso «Deshacer» de la web).
Future<void> runNoteAction<T>(
  BuildContext context,
  WidgetRef ref,
  Future<Result<T>> Function() action, {
  required String successMessage,
  String? errorMessage,
  String? undoLabel,
  VoidCallback? onUndo,
}) async {
  final result = await action();
  if (!context.mounted) return;
  switch (result) {
    case Ok():
      showAxoToast(
        context,
        message: successMessage,
        variant: AxoToastVariant.success,
        actionLabel: undoLabel,
        onAction: onUndo,
      );
    case Err(error: final error):
      if (errorMessage == null) {
        showErrorToast(context, error);
      } else {
        showAxoToast(
          context,
          message: errorMessage,
          variant: AxoToastVariant.error,
        );
      }
  }
}

/// Hora actual para las etiquetas de las hojas (evita arrastrar el reloj a cada sitio).
final clockNowProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});
