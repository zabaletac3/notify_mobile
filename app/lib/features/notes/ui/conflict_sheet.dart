import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../sync/state/sync_controller.dart';

/// Id del último conflicto para el que ya se abrió la hoja (evita reabrirla en cada refresco).
class ShownConflictController extends Notifier<Id?> {
  @override
  Id? build() => null;

  void mark(Id id) => state = id;
}

final shownConflictProvider = NotifierProvider<ShownConflictController, Id?>(
  ShownConflictController.new,
);

/// Hoja del conflicto de sincronización (tablero «Android — Conflicto de sincronización»): dos
/// tarjetas de versión con radio, «Conservar ambas» y «Usar la seleccionada». Cubre las tres
/// resoluciones del motor (`local`, `remote`, `both`).
Future<void> showConflictSheet(
  BuildContext context,
  WidgetRef ref, {
  required Conflict conflict,
}) async {
  // Por defecto, «Esta versión» (la local) viene seleccionada, como en el diseño.
  var useLocal = true;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (sheetContext, setState) {
          final c = Theme.of(sheetContext).extension<AxoColors>()!;
          final title = conflict.local.title.isEmpty
              ? 'Sin título'
              : conflict.local.title;
          return AxoBottomSheet(
            children: [
              Text(
                'Conflicto de sincronización',
                style: AxoType.dialogTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AxoSpacing.md),
              Text(
                '“$title” se editó en dos dispositivos a la vez. Elige qué versión conservar.',
                style: AxoType.bodySmall.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AxoSpacing.lg),
              _VersionOption(
                title: 'Esta versión',
                version: conflict.local,
                selected: useLocal,
                onTap: () => setState(() => useLocal = true),
              ),
              const SizedBox(height: AxoSpacing.lg),
              _VersionOption(
                title: 'Versión de la nube',
                version: conflict.remote,
                selected: !useLocal,
                onTap: () => setState(() => useLocal = false),
              ),
              const SizedBox(height: AxoSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AxoButton(
                      label: 'Conservar ambas',
                      labelStyle: AxoType.buttonSm,
                      variant: AxoButtonVariant.outline,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _resolve(
                          context,
                          ref,
                          conflict.noteId,
                          ConflictResolution.both,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: AxoSpacing.md),
                  Expanded(
                    child: AxoButton(
                      label: 'Usar la seleccionada',
                      labelStyle: AxoType.buttonSm,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _resolve(
                          context,
                          ref,
                          conflict.noteId,
                          useLocal
                              ? ConflictResolution.local
                              : ConflictResolution.remote,
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

Future<void> _resolve(
  BuildContext context,
  WidgetRef ref,
  Id noteId,
  ConflictResolution resolution,
) async {
  await ref
      .read(syncControllerProvider.notifier)
      .resolveConflict(noteId, resolution);
  if (!context.mounted) return;
  showAxoToast(
    context,
    message: 'Conflicto resuelto',
    variant: AxoToastVariant.success,
    actionLabel: 'Deshacer',
    onAction: () {},
  );
}

class _VersionOption extends StatelessWidget {
  const _VersionOption({
    required this.title,
    required this.version,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final NoteVersion version;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AxoRadii.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.bgSelected : c.bgApp,
          borderRadius: BorderRadius.circular(AxoRadii.lg),
          border: Border.all(
            color: selected ? c.accentDefault : c.borderDefault,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AxoRadio(selected: selected, onTap: onTap),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AxoType.buttonSm.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                '${version.deviceName} · ${version.editedAt}',
                style: AxoType.caption.copyWith(color: c.textSecondary),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 14),
              child: Text(
                _preview(version.content),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AxoType.label.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _preview(String content) {
    for (final line in content.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      return trimmed.replaceAll(RegExp(r'^#+\s*'), '');
    }
    return '';
  }
}
