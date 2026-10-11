import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: AxoSpacing.xxxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: c.statusDangerBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '!',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: c.statusDanger,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.serverErrorTitle,
                textAlign: TextAlign.center,
                style: AxoType.dialogTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: 34),
              Text(
                l10n.serverErrorBody,
                textAlign: TextAlign.center,
                style: AxoType.bodySmall.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: 14),
              if (onRetry != null)
                UnconstrainedBox(
                  constrainedAxis: Axis.horizontal,
                  child: AxoButton(
                    label: l10n.retry,
                    onPressed: onRetry,
                    labelStyle: AxoType.button.copyWith(fontSize: 15),
                  ),
                ),
              if (code != null) ...[
                const SizedBox(height: 14),
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
