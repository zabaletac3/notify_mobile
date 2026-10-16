import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';

import '../../../ui/app_icon.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../state/editor_controller.dart';
import 'editor_theme.dart';
import 'format_bar.dart';

/// Vista pura del editor (tablero «Android — Editor» de «Movil v2»). La usan tanto la pantalla real
/// como la maqueta de depuración, para que no haya dos interfaces distintas.
class EditorView extends StatelessWidget {
  const EditorView({
    super.key,
    required this.note,
    required this.controller,
    required this.titleController,
    required this.onTitleChanged,
    this.folderName,
    this.onBack,
    this.onShare,
    this.onMore,
    this.syncing = false,
  });

  final Note note;
  final NoteEditorController controller;
  final TextEditingController titleController;
  final Future<void> Function(String title) onTitleChanged;
  final String? folderName;
  final VoidCallback? onBack;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

  /// Muestra la barra «Sincronizando…» mientras el motor sincroniza (§7).
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Scaffold(
      backgroundColor: c.bgEditor,
      appBar: AppBar(
        toolbarHeight: 48,
        automaticallyImplyLeading: false,
        backgroundColor: c.bgEditor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: EditorTopBar(
          folderName: folderName,
          onBack: onBack,
          onUndo: controller.undo,
          onShare: onShare,
          onMore: onMore,
        ),
      ),
      body: Column(
        children: [
          if (syncing) const EditorSyncBanner(),
          if (note.unreadable)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: AxoBanner(
                variant: AxoBannerVariant.info,
                message: 'Esta nota no se pudo descifrar. Se muestra en solo lectura.',
              ),
            ),
          Expanded(
            child: AppFlowyEditor(
              editorState: controller.editorState,
              editorStyle: AxoEditorTheme.styleOf(context),
              autoFocus: false,
              blockComponentBuilders: AxoEditorTheme.buildersOf(context),
              header: EditorDocumentHeader(
                note: note,
                titleController: titleController,
                onTitleChanged: onTitleChanged,
              ),
              footer: EditorTagsFooter(tags: note.tags),
            ),
          ),
          _FormatBarSurface(controller: controller),
        ],
      ),
    );
  }
}

/// Indicador de «sincronizando» (de `notify_web`; Pencil no lo dibuja).
class EditorSyncBanner extends StatelessWidget {
  const EditorSyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Container(
      width: double.infinity,
      color: c.bgSelected,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: c.accentDefault,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Sincronizando…',
            style: AxoType.bodySmall.copyWith(color: c.accentDefault),
          ),
        ],
      ),
    );
  }
}

/// Andamiaje para los estados de carga/error del editor (misma barra y fondo).
class EditorScaffold extends StatelessWidget {
  const EditorScaffold({
    super.key,
    required this.child,
    this.folderName,
    this.onBack,
  });

  final Widget child;
  final String? folderName;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Scaffold(
      backgroundColor: c.bgEditor,
      appBar: AppBar(
        toolbarHeight: 48,
        automaticallyImplyLeading: false,
        backgroundColor: c.bgEditor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: EditorTopBar(folderName: folderName, onBack: onBack),
      ),
      body: child,
    );
  }
}

/// Barra superior: atrás, carpeta, deshacer, compartir y más (tablero «Android — Editor»).
class EditorTopBar extends StatelessWidget {
  const EditorTopBar({
    super.key,
    this.folderName,
    this.onBack,
    this.onUndo,
    this.onShare,
    this.onMore,
  });

  final String? folderName;
  final VoidCallback? onBack;
  final VoidCallback? onUndo;
  final VoidCallback? onShare;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          EditorIconButton(
            icon: 'arrow-left',
            label: 'Volver',
            onPressed: onBack,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Row(
              children: [
                AppIcon('folder', size: 16, color: c.accentDefault),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    folderName ?? 'Sin carpeta',
                    overflow: TextOverflow.ellipsis,
                    style: AxoType.chipActive.copyWith(color: c.accentDefault),
                  ),
                ),
              ],
            ),
          ),
          EditorIconButton(
            icon: 'undo-2',
            label: 'Deshacer',
            onPressed: onUndo,
          ),
          EditorIconButton(
            icon: 'share',
            label: 'Compartir',
            onPressed: onShare,
          ),
          EditorIconButton(icon: 'ellipsis', label: 'Más', onPressed: onMore),
        ],
      ),
    );
  }
}

/// Fecha y título, dentro del área con scroll del editor.
class EditorDocumentHeader extends StatelessWidget {
  const EditorDocumentHeader({
    super.key,
    required this.note,
    required this.titleController,
    required this.onTitleChanged,
  });

  final Note note;
  final TextEditingController titleController;
  final Future<void> Function(String title) onTitleChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatEditorDate(note.updatedAt),
            style: AxoType.editorDate.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: titleController,
            enabled: !note.unreadable,
            maxLines: null,
            style: AxoType.editorTitle.copyWith(color: c.textPrimary),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: 'Título',
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: onTitleChanged,
            onTapOutside: (_) => onTitleChanged(titleController.text),
          ),
        ],
      ),
    );
  }
}

/// Etiquetas al pie del documento (el diseño las pone al final).
class EditorTagsFooter extends StatelessWidget {
  const EditorTagsFooter({super.key, required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final c = Theme.of(context).extension<AxoColors>()!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final tag in tags)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.bgInput,
                borderRadius: BorderRadius.circular(AxoRadii.xxl),
              ),
              child: Text(
                '#$tag',
                style: AxoType.tagLabel.copyWith(color: c.tagPlum),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fecha del documento en el formato del diseño («7 de octubre de 2026, 09:12»).
String formatEditorDate(IsoDate value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.day} de ${_months[date.month - 1]} de ${date.year}, '
      '${two(date.hour)}:${two(date.minute)}';
}

const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Sitúa la barra de formato justo encima del teclado.
class _FormatBarSurface extends StatelessWidget {
  const _FormatBarSurface({required this.controller});

  final NoteEditorController controller;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: EditorFormatBar(controller: controller),
      ),
    );
  }
}

/// Botón redondo de la barra superior (40×40, radio 20).
class EditorIconButton extends StatelessWidget {
  const EditorIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.mirrored = false,
  });

  final String icon;
  final String label;
  final VoidCallback? onPressed;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Transform.flip(
              flipX: mirrored,
              child: AppIcon(icon, size: 22, color: c.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
