import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../notes/ui/note_sheets.dart';
import '../../settings/state/import_export_controller.dart';
import '../state/share_controller.dart';

/// Exporta una nota como `.md` (fila «Exportar como Markdown» de la hoja «Compartir»). La
/// implementación de archivos está en `features/settings/state/import_export_controller.dart`.
Future<void> exportNoteAsMarkdown(
  BuildContext context,
  WidgetRef ref,
  Id noteId,
) async {
  final result = await ref
      .read(importExportControllerProvider)
      .exportNote(noteId);
  if (!context.mounted) return;
  switch (result) {
    case Ok(value: final saved):
      if (saved) {
        showAxoToast(context, message: 'Nota exportada');
      }
    case Err(error: final error):
      showErrorToast(context, error);
  }
}

/// Hoja «Compartir nota» (tablero «Android — Compartir nota»). Desde el editor y desde el menú
/// contextual de la lista. Crea, copia o revoca el enlace público de la nota.
Future<void> showShareSheet(
  BuildContext context,
  WidgetRef ref, {
  required Note note,
  VoidCallback? onExportMarkdown,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ShareSheet(note: note, onExportMarkdown: onExportMarkdown),
  );
}

class _ShareSheet extends ConsumerStatefulWidget {
  const _ShareSheet({required this.note, this.onExportMarkdown});

  final Note note;
  final VoidCallback? onExportMarkdown;

  @override
  ConsumerState<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<_ShareSheet> {
  @override
  void initState() {
    super.initState();
    // Trae el enlace que la nota ya tenga (p. ej. tras recargar la app).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(shareControllerProvider.notifier).load(widget.note.id);
    });
  }

  Future<void> _toggle(bool on) async {
    final controller = ref.read(shareControllerProvider.notifier);
    final result = on
        ? await controller.create(widget.note.id)
        : await controller.revoke(widget.note.id);
    if (!mounted) return;
    switch (result) {
      case Ok():
        break;
      case Err(error: final error):
        showErrorToast(context, error);
    }
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    showAxoToast(context, message: 'Enlace copiado');
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final state = ref.watch(shareControllerProvider);
    final link = state.linkFor(widget.note.id);
    final title = widget.note.title.isEmpty ? 'Sin título' : widget.note.title;

    return AxoBottomSheet(
      children: [
        Text(
          'Compartir nota',
          style: AxoType.dialogTitle.copyWith(color: c.textPrimary),
        ),
        const SizedBox(height: AxoSpacing.md),
        Text(
          '“$title”',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AxoType.body.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: AxoSpacing.lg),
        Row(
          children: [
            Expanded(
              child: Container(
                height: AxoSizes.searchBar,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: c.bgInput,
                  borderRadius: BorderRadius.circular(AxoRadii.lg),
                ),
                child: Text(
                  link?.url ?? 'Activa el enlace para compartir',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AxoType.bodyUi.copyWith(
                    color: link == null ? c.textTertiary : c.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AxoSpacing.md),
            AxoButton(
              label: 'Copiar',
              labelStyle: AxoType.buttonSm,
              onPressed: link == null ? null : () => _copy(link.url),
            ),
          ],
        ),
        const SizedBox(height: AxoSpacing.lg),
        AxoSheetActions(
          children: [
            _ToggleRow(
              value: link != null,
              busy: state.busy,
              onChanged: _toggle,
            ),
            AxoOptionRow(
              label: 'Exportar como PDF',
              icon: 'upload',
              onTap: () => showAxoToast(
                context,
                message: 'Disponible pronto',
                variant: AxoToastVariant.info,
              ),
            ),
            AxoOptionRow(
              label: 'Exportar como Markdown',
              icon: 'file-text',
              onTap: () {
                final export = widget.onExportMarkdown;
                if (export == null) {
                  showAxoToast(
                    context,
                    message: 'Disponible pronto',
                    variant: AxoToastVariant.info,
                  );
                  return;
                }
                Navigator.of(context).pop();
                export();
              },
            ),
            AxoOptionRow(
              label: 'Enviar una copia',
              icon: 'share',
              onTap: () => showAxoToast(
                context,
                message: 'Disponible pronto',
                variant: AxoToastVariant.info,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Fila del interruptor «Cualquiera con el enlace puede ver».
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.value,
    required this.busy,
    required this.onChanged,
  });

  final bool value;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return SizedBox(
      height: AxoSizes.settingsRowTall,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cualquiera con el enlace puede ver',
                    style: AxoType.settingsRowLabel.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Solo lectura, no pueden editar',
                    style: AxoType.settingsRowDescription.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AxoSwitch(value: value, onChanged: busy ? null : onChanged),
          ],
        ),
      ),
    );
  }
}
