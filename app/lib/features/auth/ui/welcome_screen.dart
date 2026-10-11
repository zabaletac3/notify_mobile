import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import 'auth_widgets.dart';

/// Bienvenida (tablero «1 · Onboarding — Bienvenida», leído por el MCP): fondo `bgEditor`
/// (#fffdf8), logo 96 (radio 24), marca 34/700 y eslogan 16/400 centrados en vertical; abajo los
/// botones de 54 y el pie legal 12/400.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    return Scaffold(
      backgroundColor: c.bgEditor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AxoSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // La galería de componentes (solo debug) se abre manteniendo pulsado el
                      // logotipo, para no añadir elementos que no están en el tablero.
                      GestureDetector(
                        onLongPress: kDebugMode
                            ? () => context.go('/dev/components')
                            : null,
                        child: const AuthLogo(size: 96, letter: 'A'),
                      ),
                      const SizedBox(height: AxoSpacing.md),
                      Text(
                        l10n.appTitle,
                        textAlign: TextAlign.center,
                        style: AxoType.brand.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: AxoSpacing.lg),
                      Text(
                        l10n.welcomeTagline,
                        textAlign: TextAlign.center,
                        style: AxoType.bodyReading.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AxoButton(
                label: l10n.welcomeCreateAccount,
                expand: true,
                size: AxoButtonSize.lg,
                onPressed: () => context.go('/register'),
              ),
              const SizedBox(height: AxoSpacing.md),
              AxoButton(
                label: l10n.welcomeHaveAccount,
                variant: AxoButtonVariant.outline,
                expand: true,
                size: AxoButtonSize.lg,
                onPressed: () => context.go('/login'),
              ),
              const SizedBox(height: AxoSpacing.md),
              Text(
                l10n.welcomeTerms,
                textAlign: TextAlign.center,
                style: AxoType.caption.copyWith(color: c.textTertiary),
              ),
              const SizedBox(height: AxoSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
