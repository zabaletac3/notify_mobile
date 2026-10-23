import 'package:flutter/material.dart';

import '../../../ui/app_icon.dart';
import '../../../ui/tokens.dart';
import '../state/editor_controller.dart';

/// Barra de formato del editor (tablero «Android — Editor»): estilo de párrafo, negrita, cursiva,
/// lista, tareas e imagen, con los iconos de los vectores del diseño (Lucide, trazo 1,75). Va sobre
/// el teclado. El botón de imagen se muestra aunque todavía no actúe (las imágenes son bloque opaco).
class EditorFormatBar extends StatefulWidget {
  const EditorFormatBar({super.key, required this.controller});

  final NoteEditorController controller;

  @override
  State<EditorFormatBar> createState() => _EditorFormatBarState();
}

class _EditorFormatBarState extends State<EditorFormatBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.editorState.selectionNotifier.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.editorState.selectionNotifier.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final controller = widget.controller;
    final type = controller.blockType;

    return Container(
      height: AxoSizes.formatBar + 12,
      padding: const EdgeInsets.fromLTRB(8, 0, 4, 0),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: c.bgSidebar,
          borderRadius: BorderRadius.circular(AxoRadii.sheet),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TextStyleButton(controller: controller, type: type),
            const SizedBox(width: 4),
            _ToolbarButton(
              icon: 'bold',
              label: 'Negrita',
              active: controller.isMarkActive('bold'),
              onPressed: controller.toggleBold,
            ),
            _ToolbarButton(
              icon: 'italic',
              label: 'Cursiva',
              active: controller.isMarkActive('italic'),
              onPressed: controller.toggleItalic,
            ),
            _ToolbarButton(
              icon: 'list',
              label: 'Lista',
              active: type == 'bulleted_list',
              onPressed: () => controller.toggleList('bulleted_list'),
            ),
            _ToolbarButton(
              icon: 'list-checks',
              label: 'Lista de tareas',
              active: type == 'todo_list',
              onPressed: () => controller.toggleList('todo_list'),
            ),
            _ToolbarButton(
              icon: 'image',
              label: 'Imagen',
              active: false,
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _TextStyleButton extends StatelessWidget {
  const _TextStyleButton({required this.controller, required this.type});

  final NoteEditorController controller;
  final String? type;

  String get _label => switch (type) {
    'heading' => 'Título',
    'quote' => 'Cita',
    'code' => 'Código',
    _ => 'Aa',
  };

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return PopupMenuButton<String>(
      tooltip: 'Estilo de párrafo',
      onOpened: controller.holdEditorFocus,
      onCanceled: controller.releaseEditorFocus,
      onSelected: (value) {
        controller.releaseEditorFocus();
        switch (value) {
          case 'paragraph':
            controller.setBlockType('paragraph');
          case 'h1':
            controller.setBlockType('heading', level: 1);
          case 'h2':
            controller.setBlockType('heading', level: 2);
          case 'h3':
            controller.setBlockType('heading', level: 3);
          case 'quote':
            controller.setBlockType('quote');
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'paragraph', child: Text('Párrafo')),
        PopupMenuItem(value: 'h1', child: Text('Título 1')),
        PopupMenuItem(value: 'h2', child: Text('Título 2')),
        PopupMenuItem(value: 'h3', child: Text('Título 3')),
        PopupMenuItem(value: 'quote', child: Text('Cita')),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: c.bgInput,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _label,
              style: AxoType.formatStyleLabel.copyWith(color: c.textPrimary),
            ),
            const SizedBox(width: 4),
            AppIcon('chevron-down', size: 14, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.active,
  });

  final String icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onPressed,
        canRequestFocus: false,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: AxoSizes.formatBarButton,
          height: AxoSizes.formatBarButton,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? c.bgSelected : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AppIcon(
            icon,
            size: AxoSizes.formatBarIcon,
            color: active ? c.accentDefault : c.textPrimary,
          ),
        ),
      ),
    );
  }
}
