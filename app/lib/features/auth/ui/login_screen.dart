import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/error_messages.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';

/// Inicio de sesión (tablero «2 · Autenticación — Inicio de sesión», leído por el MCP). El tablero
/// incluye Google, fuera de v1 (D5): se omite el botón y su divisor. Con MFA, el primer paso lleva
/// al segundo factor.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(authControllerProvider.notifier);
    final ok = await controller.login(
      LoginInput(email: _email.text, password: _password.text),
    );
    if (!ok.isOk || !mounted) return;
    if (ref.read(authControllerProvider).mfaPending) {
      context.go('/two-factor');
    }
    // Si no hay MFA, el cofre queda desbloqueado y la guarda lleva a /notes.
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    final state = ref.watch(authControllerProvider);

    String? errorOf(String field) =>
        validationMessage(l10n, state.fieldErrors[field]);

    final notice = switch (state.notice) {
      AuthNotice.deviceRevoked => l10n.signedOutNotice,
      AuthNotice.signedOutElsewhere => l10n.sessionExpiredBody,
      AuthNotice.mfaExpired => l10n.mfaExpiredNotice,
      null => null,
    };

    return Scaffold(
      backgroundColor: c.bgApp,
      body: AuthBody(
        children: [
          AuthBackButton(onPressed: () => context.go('/welcome')),
          const SizedBox(height: AxoSpacing.xl),
          AuthCard(
            children: [
              const Center(child: AuthLogo(size: 48, letter: 'a')),
              const SizedBox(height: AxoSpacing.lg),
              Text(
                l10n.loginTitle,
                textAlign: TextAlign.center,
                style: AxoType.screenTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AxoSpacing.xl),
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AxoSpacing.lg),
                  child: AxoBanner(message: notice),
                ),
              if (state.error != null && state.fieldErrors.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AxoSpacing.lg),
                  child: AxoBanner(
                    message: errorMessage(
                      l10n,
                      kind: state.error!.kind,
                      code: state.error is ForbiddenError
                          ? (state.error! as ForbiddenError).code?.wire
                          : null,
                    ),
                    variant: AxoBannerVariant.danger,
                  ),
                ),
              AxoField(
                label: l10n.fieldEmail,
                hint: l10n.fieldEmailHint,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                error: errorOf('email'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AxoSpacing.lg),
              AxoField(
                label: l10n.fieldPassword,
                hint: l10n.fieldPasswordHint,
                controller: _password,
                obscure: true,
                error: errorOf('password'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AxoSpacing.xl),
              AxoButton(
                label: state.deriving
                    ? l10n.derivingPassword
                    : l10n.loginButton,
                expand: true,
                size: AxoButtonSize.lg,
                onPressed: state.busy ? null : _submit,
              ),
              const SizedBox(height: AxoSpacing.md),
              Center(
                child: AuthLink(
                  text: l10n.forgotPasswordLink,
                  onTap: () => context.go('/forgot-password'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AxoSpacing.lg),
          AuthFooterPrompt(
            prompt: l10n.newHerePrompt,
            action: l10n.createAnAccount,
            onTap: () => context.go('/register'),
          ),
          const SizedBox(height: AxoSpacing.lg),
        ],
      ),
    );
  }
}
