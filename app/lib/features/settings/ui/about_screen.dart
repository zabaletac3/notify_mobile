import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../state/app_info.dart';
import 'settings_labels.dart';
import 'settings_widgets.dart';

/// Acerca de (`/settings/about`, tablero «Android — Acerca de»): identidad, versión y enlaces a los
/// textos legales. La versión sale del paquete (`appInfoProvider`).
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final info = ref.watch(appInfoProvider).value;
    final version = info?.version ?? settingsSampleVersion;
    final build = info?.build ?? settingsSampleBuild;
    return SettingsScaffold(
      title: 'Acerca de',
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AxoSpacing.sm),
          child: Column(
            children: [
              Container(
                width: AxoSizes.settingsLogo,
                height: AxoSizes.settingsLogo,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentDefault,
                  borderRadius: BorderRadius.circular(AxoRadii.fab),
                ),
                child: Text(
                  'A',
                  style: AxoType.brand.copyWith(color: c.accentOn),
                ),
              ),
              const SizedBox(height: AxoSpacing.sm),
              Text(
                'AxoNote',
                style: AxoType.topTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AxoSpacing.sm),
              Text(
                'Versión $version (build $build)',
                style: AxoType.settingsRowValue.copyWith(color: c.textTertiary),
              ),
            ],
          ),
        ),
        AxoSettingsGroup(
          children: [
            AxoSettingRow(
              label: 'Notas de la versión',
              chevron: true,
              onTap: () => context.push('/changelog'),
            ),
            AxoSettingRow(
              label: 'Términos de uso',
              chevron: true,
              onTap: () => context.push('/terms'),
            ),
            AxoSettingRow(
              label: 'Política de privacidad',
              chevron: true,
              onTap: () => context.push('/privacy'),
            ),
            AxoSettingRow(
              label: 'Licencias de código abierto',
              chevron: true,
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'AxoNote',
                applicationVersion: 'Versión $version (build $build)',
              ),
            ),
            AxoSettingRow(
              label: 'Contacto y soporte',
              chevron: true,
              onTap: () => context.push('/support'),
            ),
          ],
        ),
        Text(
          '© 2026 AxoNote. Todos los derechos reservados.',
          textAlign: TextAlign.center,
          style: AxoType.caption.copyWith(color: c.textTertiary),
        ),
      ],
    );
  }
}
