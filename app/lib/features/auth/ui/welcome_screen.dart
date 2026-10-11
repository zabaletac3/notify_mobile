import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import 'auth_widgets.dart';

/// Pantalla de bienvenida (tablero «1 · Onboarding — Bienvenida»): logotipo, eslogan y los dos
/// accesos (crear cuenta / ya tengo cuenta). Sin botones de demostración.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    return Scaffold(
      backgroundColor: c.bgApp,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AxoSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 3),
              const Center(child: AuthLogo(size: 96, letter: 'A')),
              const SizedBox(height: AxoSpacing.xxl),
              Text(
                l10n.appTitle,
                textAlign: TextAlign.center,
                style: AxoType.brand.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AxoSpacing.sm),
              Text(
                l10n.welcomeTagline,
                textAlign: TextAlign.center,
                style: AxoType.body.copyWith(color: c.textSecondary),
              ),
              const Spacer(flex: 4),
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
              const SizedBox(height: AxoSpacing.lg),
              Text(
                l10n.welcomeTerms,
                textAlign: TextAlign.center,
                style: AxoType.caption.copyWith(color: c.textTertiary),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: AxoSpacing.md),
                Center(
                  child: AuthLink(
                    text: 'Ver componentes (dev)',
                    onTap: () => context.go('/dev/components'),
                  ),
                ),
              ],
              const SizedBox(height: AxoSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
