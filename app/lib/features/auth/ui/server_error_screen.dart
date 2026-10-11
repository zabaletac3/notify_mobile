import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';

/// Error de servidor (tablero «7 · Estados y errores — Error de servidor»): icono de peligro,
/// título, cuerpo, botón de reintento y el código de error. Se usa como pantalla de error global.
class ServerErrorScreen extends StatelessWidget {
  const ServerErrorScreen({super.key, this.code, this.onRetry});

  final int? code;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    return Scaffold(
      backgroundColor: c.bgApp,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AxoSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: c.statusDangerBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon(
                    'circle-alert',
                    size: 40,
                    color: c.statusDanger,
                  ),
                ),
              ),
              const SizedBox(height: AxoSpacing.xxl),
              Text(
                l10n.serverErrorTitle,
                textAlign: TextAlign.center,
                style: AxoType.dialogTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AxoSpacing.md),
              Text(
                l10n.serverErrorBody,
                textAlign: TextAlign.center,
                style: AxoType.body.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AxoSpacing.xl),
              if (onRetry != null)
                AxoButton(label: l10n.retry, onPressed: onRetry),
              if (code != null) ...[
                const SizedBox(height: AxoSpacing.md),
                Text(
                  l10n.errorCodeLabel('$code'),
                  style: AxoType.caption.copyWith(color: c.textTertiary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
