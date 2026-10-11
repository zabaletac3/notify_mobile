import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/error_messages.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';

/// Solicitud de restablecimiento (tablero «2 · Autenticación — Recuperar contraseña (correo)»,
/// leído por el MCP): fondo `bgEditor`, título 28/700, campo y acciones al pie (botón 362×54 y
/// enlace 14/600).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .forgotPassword(_email.text);
    if (ok.isOk && mounted) context.go('/forgot-password/sent');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    final state = ref.watch(authControllerProvider);
    final emailError = validationMessage(l10n, state.fieldErrors['email']);

    return Scaffold(
      backgroundColor: c.bgEditor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AxoSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 48,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AuthBackButton(onPressed: () => context.go('/login')),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                l10n.forgotTitle,
                style: AxoType.title.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AxoSpacing.sm),
              Text(
                l10n.forgotSubtitle,
                style: AxoType.body.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: AxoSpacing.xxl),
              if (state.error != null && state.fieldErrors.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AxoSpacing.lg),
                  child: AxoBanner(
                    message: errorMessage(l10n, kind: state.error!.kind),
                    variant: AxoBannerVariant.danger,
                  ),
                ),
              AxoField(
                label: l10n.fieldEmail,
                hint: l10n.fieldEmailHint,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                error: emailError,
                onChanged: (_) => setState(() {}),
              ),
              const Spacer(),
              AxoButton(
                label: l10n.forgotSend,
                expand: true,
                size: AxoButtonSize.lg,
                onPressed: state.busy ? null : _submit,
              ),
              const SizedBox(height: AxoSpacing.lg),
              Center(
                child: AuthLink(
                  text: l10n.forgotBackToLogin,
                  onTap: () => context.go('/login'),
                ),
              ),
              const SizedBox(height: AxoSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
