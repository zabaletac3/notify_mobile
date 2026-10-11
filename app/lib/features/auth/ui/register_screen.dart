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

/// Registro (tablero «2 · Autenticación — Registro», leído por el MCP; verificado en su variante
/// oscura). El tablero incluye Google, que es **fuera de v1** (D5): se omite el botón y su divisor.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .register(
          RegisterInput(
            fullName: _name.text,
            email: _email.text,
            password: _password.text,
            acceptedTerms: _acceptedTerms,
          ),
        );
    if (ok.isOk && mounted) context.go('/verify');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    final state = ref.watch(authControllerProvider);
    final strength = passwordStrength(_password.text);

    String? errorOf(String field) =>
        validationMessage(l10n, state.fieldErrors[field]);

    return Scaffold(
      backgroundColor: c.bgApp,
      body: AuthBody(
        children: [
          AuthBackButton(onPressed: () => context.go('/welcome')),
          const SizedBox(height: AxoSpacing.md),
          AuthCard(
            children: [
              const Center(child: AuthLogo(size: 48, letter: 'a')),
              const SizedBox(height: AxoSpacing.lg),
              Text(
                l10n.registerTitle,
                textAlign: TextAlign.center,
                style: AxoType.screenTitle.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AxoSpacing.sm),
              Text(
                l10n.registerSubtitle,
                textAlign: TextAlign.center,
                style: AxoType.body.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AxoSpacing.xl),
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
                label: l10n.fieldName,
                hint: l10n.fieldNameHint,
                controller: _name,
                error: errorOf('fullName'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AxoSpacing.lg),
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
                hint: l10n.fieldPasswordHintMin,
                controller: _password,
                obscure: true,
                error: errorOf('password'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AxoSpacing.sm),
              AxoPasswordStrength(score: strength.score),
              const SizedBox(height: AxoSpacing.xs),
              Text(
                l10n.passwordHelper,
                style: AxoType.caption.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AxoSpacing.lg),
              AxoCheckbox(
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v),
                label: l10n.termsAccept,
              ),
              if (errorOf('acceptedTerms') != null)
                Padding(
                  padding: const EdgeInsets.only(top: AxoSpacing.xs),
                  child: Text(
                    errorOf('acceptedTerms')!,
                    style: AxoType.caption.copyWith(color: c.statusDanger),
                  ),
                ),
              const SizedBox(height: AxoSpacing.xl),
              AxoButton(
                label: state.deriving
                    ? l10n.derivingPassword
                    : l10n.createAccountButton,
                expand: true,
                size: AxoButtonSize.lg,
                onPressed: state.busy ? null : _submit,
              ),
            ],
          ),
          const SizedBox(height: AxoSpacing.lg),
          AuthFooterPrompt(
            prompt: l10n.haveAccountPrompt,
            action: l10n.logIn,
            onTap: () => context.go('/login'),
          ),
          const SizedBox(height: AxoSpacing.lg),
        ],
      ),
    );
  }
}
