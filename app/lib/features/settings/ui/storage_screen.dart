import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../notes/state/notes_providers.dart';
import '../../notes/ui/note_sheets.dart';
import '../state/import_export_controller.dart';
import '../state/storage_controller.dart';
import 'settings_widgets.dart';

/// Almacenamiento y exportación (`/settings/storage`, tablero «Android — Almacenamiento y
/// exportación»): uso real (`GET /storage/usage`) y exportar/importar Markdown (fase 11.5).
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = ref.watch(storageUsageProvider);
    return SettingsScaffold(
      title: 'Almacenamiento y exportación',
      children: [
        _StorageUsageCard(usage: usage),
        AxoSettingsGroup(
          title: 'Uso',
          children: [
            AxoSettingRow(
              label: 'Notas',
              value: usage.value == null
                  ? null
                  : _formatBytes(usage.value!.notesBytes),
              chevron: true,
            ),
            AxoSettingRow(
              label: 'Imágenes',
              value: usage.value == null
                  ? null
                  : _formatBytes(usage.value!.imagesBytes),
              chevron: true,
            ),
            AxoSettingRow(
              label: 'Papelera',
              value: usage.value == null
                  ? null
                  : _formatBytes(usage.value!.trashBytes),
              chevron: true,
            ),
          ],
        ),
        AxoSettingsGroup(
          title: 'Exportar',
          children: [
            AxoSettingRow(
              label: 'Exportar todas las notas',
              description: 'Archivo .zip con Markdown',
              chevron: true,
              onTap: () => _exportAll(context, ref),
            ),
            AxoSettingRow(
              label: 'Exportar como PDF',
              chevron: true,
              onTap: () => showAxoToast(
                context,
                message: 'Disponible pronto',
                variant: AxoToastVariant.info,
              ),
            ),
            AxoSettingRow(
              label: 'Importar notas',
              chevron: true,
              onTap: () => _import(context, ref),
            ),
          ],
        ),
        AxoSettingsGroup(
          children: [
            AxoSettingRow(
              label: 'Vaciar papelera',
              danger: true,
              onTap: () => _emptyTrash(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportAll(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(importExportControllerProvider)
        .exportAllNotes();
    if (!context.mounted) return;
    switch (result) {
      case Ok(value: final saved):
        if (saved) {
          showAxoToast(context, message: 'Notas exportadas');
        }
      case Err(error: final error):
        showErrorToast(context, error);
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(importExportControllerProvider).importNotes();
    if (!context.mounted) return;
    switch (result) {
      case Ok(value: final outcome):
        if (outcome.created == 0) {
          showAxoToast(
            context,
            message: 'No se importó ninguna nota',
            variant: AxoToastVariant.error,
          );
          return;
        }
        final created = outcome.created == 1
            ? '1 nota importada'
            : '${outcome.created} notas importadas';
        final skipped = outcome.skipped == 0
            ? ''
            : (outcome.skipped == 1
                  ? ' · 1 archivo omitido'
                  : ' · ${outcome.skipped} archivos omitidos');
        showAxoToast(context, message: '$created$skipped');
      case Err(error: final error):
        showErrorToast(context, error);
    }
  }

  void _emptyTrash(BuildContext context, WidgetRef ref) {
    final count = ref.read(noteCountsProvider).value?.trash ?? 0;
    if (count == 0) {
      showAxoToast(
        context,
        message: 'La papelera está vacía',
        variant: AxoToastVariant.info,
      );
      return;
    }
    showConfirmEmptyTrashDialog(context, ref, count: count);
  }
}

class _StorageUsageCard extends StatelessWidget {
  const _StorageUsageCard({required this.usage});

  final AsyncValue<StorageUsage> usage;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Material(
      color: c.bgApp,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AxoRadii.xl),
        side: BorderSide(color: c.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (usage.value != null) ...[
              Text(
                '${_formatBytes(usage.value!.usedBytes)} de '
                '${_formatBytes(usage.value!.quotaBytes)} usados',
                style: AxoType.button.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AxoSpacing.md),
              SizedBox(
                height: AxoSizes.settingsProgress,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AxoSizes.settingsProgress / 2,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: c.borderDefault),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: usage.value!.percentUsed.clamp(0, 1),
                        child: ColoredBox(color: c.accentDefault),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AxoSpacing.md),
              Text(
                'Tienes ${_formatBytes(usage.value!.availableBytes)} disponibles.',
                style: AxoType.settingsRowDescription.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ] else if (usage.hasError) ...[
              Text(
                'No pudimos calcular el espacio usado.',
                style: AxoType.settingsRowDescription.copyWith(
                  color: c.textTertiary,
                ),
              ),
            ] else ...[
              const AxoSkeleton(width: 180, height: 16),
              const SizedBox(height: AxoSpacing.md),
              const AxoSkeleton(width: 348, height: AxoSizes.settingsProgress),
              const SizedBox(height: AxoSpacing.md),
              const AxoSkeleton(width: 172, height: 13),
            ],
          ],
        ),
      ),
    );
  }
}

/// Formatea bytes como en la web (`180 MB`, `1 GB`, `844 MB`).
String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = (value >= 100 || value == value.roundToDouble())
      ? value.round().toString()
      : value.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
