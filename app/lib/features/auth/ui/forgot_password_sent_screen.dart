import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';

/// Restablecimiento «enviado» (tablero «2 · Autenticación — Recuperar contraseña (enviado)»).
class ForgotPasswordSentScreen extends ConsumerStatefulWidget {
  const ForgotPasswordSentScreen({super.key});

  @override
  ConsumerState<ForgotPasswordSentScreen> createState() =>
      _ForgotPasswordSentScreenState();
}

class _ForgotPasswordSentScreenState
    extends ConsumerState<ForgotPasswordSentScreen> {
  Future<void> _resend() async {
    final controller = ref.read(authControllerProvider.notifier);
    final email = ref.read(authControllerProvider).resetEmail;
    if (email == null) return;
    final ok = await controller.forgotPassword(email);
    if (ok.isOk && mounted) context.go('/forgot-password/sent');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    final email = ref.watch(authControllerProvider).resetEmail ?? '';

    return Scaffold(
      backgroundColor: c.bgApp,
      body: AuthBody(
        children: [
          const SizedBox(height: AxoSpacing.xxxl),
          const Center(child: AuthIconBadge(icon: 'mail', size: 96)),
          const SizedBox(height: AxoSpacing.xl),
          Text(
            l10n.forgotSentTitle,
            textAlign: TextAlign.center,
            style: AxoType.title.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AxoSpacing.md),
          Text.rich(
            TextSpan(
              style: AxoType.body.copyWith(color: c.textSecondary),
              children: [
                TextSpan(text: l10n.forgotSentPrefix),
                TextSpan(
                  text: email,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: l10n.forgotSentSuffix),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AxoSpacing.xxxl),
          AxoButton(
            label: l10n.forgotBackToLogin,
            expand: true,
            size: AxoButtonSize.lg,
            onPressed: () => context.go('/login'),
          ),
          const SizedBox(height: AxoSpacing.md),
          Center(
            child: AuthFooterPrompt(
              prompt: l10n.forgotSentResend,
              action: l10n.forgotSentResendLink,
              onTap: _resend,
            ),
          ),
        ],
      ),
    );
  }
}
