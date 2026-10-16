import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/tokens.dart';
import '../../settings/state/app_info.dart';
import '../../settings/ui/settings_widgets.dart';

/// «Notas de la versión» (`/changelog`): historial de cambios. La entrada más reciente usa la
/// versión del paquete.
class ChangelogScreen extends ConsumerWidget {
  const ChangelogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final version = ref.watch(appInfoProvider).value?.version;
    return SettingsScaffold(
      title: 'Notas de la versión',
      children: [
        for (final entry in changelog)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Versión ${entry.version ?? version ?? ''}',
                style: AxoType.heading.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                entry.date,
                style: AxoType.settingsRowDescription.copyWith(
                  color: c.textTertiary,
                ),
              ),
              const SizedBox(height: AxoSpacing.sm),
              for (final change in entry.changes)
                Padding(
                  padding: const EdgeInsets.only(bottom: AxoSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: AxoType.body.copyWith(color: c.textSecondary),
                      ),
                      Expanded(
                        child: Text(
                          change,
                          style: AxoType.body.copyWith(color: c.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
