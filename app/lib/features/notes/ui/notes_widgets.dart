import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';

import '../../../ui/app_icon.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../state/note_dates.dart';
import '../state/notes_providers.dart';

/// Barra superior de la lista (tableros «Android — Lista de notas» y «Papelera»): 48 de alto,
/// relleno [4,8], hueco 4. Botón de menú (40×40, radio 20), título con chevron (o título simple),
/// y acciones a la derecha (p. ej. «más» o «Vaciar»).
class NotesTopBar extends StatelessWidget {
  const NotesTopBar({
    super.key,
    required this.title,
    this.onMenu,
    this.onTitleTap,
    this.leadingIcon = 'menu',
    this.leadingSize = 22,
    this.actions = const [],
  });

  final String title;
  final VoidCallback? onMenu;
  final VoidCallback? onTitleTap;
  final String leadingIcon;
  final double leadingSize;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            NotesIconButton(
              icon: leadingIcon,
              size: leadingSize,
              onTap: onMenu,
            ),
            const SizedBox(width: AxoSpacing.xs),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: onTitleTap,
                  borderRadius: BorderRadius.circular(AxoRadii.sm),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AxoType.topTitle.copyWith(
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        if (onTitleTap != null) ...[
                          const SizedBox(width: 6),
                          AppIcon(
                            'chevron-down',
                            size: 18,
                            color: c.textSecondary,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Botón de icono circular de la barra superior (40×40, radio 20).
class NotesIconButton extends StatelessWidget {
  const NotesIconButton({
    super.key,
    required this.icon,
    this.size = 22,
    this.color,
    this.onTap,
  });

  final String icon;
  final double size;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AppIcon(icon, size: size, color: color ?? c.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Fila de chips de carpeta («Todas» + cada carpeta), del tablero «Android — Lista de notas».
/// [selectedFolderId] es `null` cuando está elegido «Todas».
class FolderChipsRow extends StatelessWidget {
  const FolderChipsRow({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.onSelect,
  });

  final List<Folder> folders;
  final Id? selectedFolderId;
  final ValueChanged<Id?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 53,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
        children: [
          AxoFolderChip(
            label: 'Todas',
            selected: selectedFolderId == null && folders.isNotEmpty,
            onTap: () => onSelect(null),
          ),
          for (final folder in folders) ...[
            const SizedBox(width: AxoSpacing.sm),
            AxoFolderChip(
              label: folder.name,
              icon: 'folder',
              selected: selectedFolderId == folder.id,
              onTap: () => onSelect(folder.id),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pinta las notas agrupadas (Fijadas · Hoy · Esta semana · mes) con las cabeceras del diseño.
/// [onOpen] abre la nota; [onLongPress] abre el menú contextual. Se construye de forma perezosa
/// (`ListView.builder`) con las filas ya agrupadas ([rows], de `notesRowsProvider`) para que
/// 10 000 notas no se materialicen ni se reagrupen de golpe (plan §4.4 y §11).
class NoteGroupsList extends StatelessWidget {
  const NoteGroupsList({
    super.key,
    required this.rows,
    required this.now,
    this.highlight,
    this.onOpen,
    this.onLongPress,
    this.swipeStart,
    this.swipeEnd,
    this.folderNames = const {},
    this.showPreview = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  final List<NoteListRow> rows;
  final DateTime now;
  final String? highlight;
  final ValueChanged<Note>? onOpen;
  final ValueChanged<Note>? onLongPress;

  /// Acción al deslizar hacia la derecha (null = ese lado no se puede deslizar).
  final AxoSwipeAction? Function(Note note)? swipeStart;

  /// Acción al deslizar hacia la izquierda.
  final AxoSwipeAction? Function(Note note)? swipeEnd;
  final Map<Id, String> folderNames;
  final EdgeInsets padding;

  /// Mostrar la vista previa de cada nota (ajuste «Mostrar vista previa en la lista»).
  final bool showPreview;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        final header = row.header;
        if (header != null) return AxoNoteGroupHeader(label: header);
        final value = row.note!;
        return AxoSwipeTile(
          itemKey: ValueKey('note-${value.id}'),
          startAction: swipeStart?.call(value),
          endAction: swipeEnd?.call(value),
          child: AxoNoteCard(
            title: value.title.isEmpty ? 'Sin título' : value.title,
            preview: notePreview(value),
            date: noteListDate(value.updatedAt, now),
            pinned: value.pinned,
            unreadable: value.unreadable,
            showPreview: showPreview,
            folderLabel: value.folderId == null
                ? null
                : folderNames[value.folderId],
            highlight: highlight,
            onTap: onOpen == null ? null : () => onOpen!(value),
            onLongPress: onLongPress == null ? null : () => onLongPress!(value),
          ),
        );
      },
    );
  }
}

/// Primera línea del contenido de una nota, para la vista previa de la tarjeta. En un resultado de
/// `list()` el `content` viene vacío (plan §4.4) y se usa la columna `preview` ya calculada.
String notePreview(Note note) {
  if (note.unreadable) return 'No se pudo descifrar esta nota.';
  if (note.preview.isNotEmpty) return note.preview;
  return derivePreview(note.content);
}
