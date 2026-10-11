import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/error_messages.dart';
import '../../../ui/app_icon.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';

/// Verificación de correo (tablero «2 · Autenticación — Verificación de correo», leído por el
/// MCP): vuelta atrás, ilustración circular 72, título 28/700, cuerpo con el correo en negrita,
/// 6 casillas OTP 53×60, fila de reenvío y botón primario 362×54 con «Cambiar correo».
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key});

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  String _code = '';
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Refresca el contador del enfriamiento cada segundo.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    final ok = await ref.read(authControllerProvider.notifier).verify(_code);
    if (ok.isOk && mounted) context.go('/recovery-key');
  }

  Future<void> _resend() async {
    final controller = ref.read(authControllerProvider.notifier);
    if (controller.resendRemaining() > 0) return;
    final ok = await controller.resendCode();
    if (ok.isOk && mounted) {
      showAxoToast(
        context,
        message: AppLocalizations.of(context).verifyResendLink,
        variant: AxoToastVariant.success,
      );
    }
  }

  String _counter(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    final state = ref.watch(authControllerProvider);
    final email = state.pendingEmail ?? '';
    final remaining = ref
        .read(authControllerProvider.notifier)
        .resendRemaining();
    final canResend = remaining == 0;
    final codeError = validationMessage(l10n, state.fieldErrors['code']);

    return Scaffold(
      backgroundColor: c.bgApp,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AxoSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthBackButton(
                onPressed: () {
                  ref.read(authControllerProvider.notifier).changeEmail();
                  context.go('/register');
                },
              ),
              const SizedBox(height: AxoSpacing.sm),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: c.bgSelected,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AppIcon('mail', size: 32, color: c.accentDefault),
                ),
              ),
              const SizedBox(height: AxoSpacing.xl),
              Text(
                l10n.verifyTitle,
                style: AxoType.title.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: AxoSpacing.sm),
              Text.rich(
                TextSpan(
                  style: AxoType.body.copyWith(color: c.textSecondary),
                  children: [
                    TextSpan(text: l10n.verifySentPrefix),
                    TextSpan(
                      text: email,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: l10n.verifySentSuffix),
                  ],
                ),
              ),
              const SizedBox(height: AxoSpacing.xl),
              AxoOtpInput(onChanged: (value) => setState(() => _code = value)),
              if (codeError != null) ...[
                const SizedBox(height: AxoSpacing.sm),
                Text(
                  codeError,
                  style: AxoType.caption.copyWith(color: c.statusDanger),
                ),
              ],
              const SizedBox(height: AxoSpacing.lg),
              Row(
                children: [
                  Text(
                    l10n.verifyNoCodeQuestion,
                    style: AxoType.bodyUi.copyWith(color: c.textSecondary),
                  ),
                  const SizedBox(width: AxoSpacing.sm),
                  if (canResend)
                    AuthLink(text: l10n.verifyResendLink, onTap: _resend)
                  else
                    Text(
                      l10n.verifyResendCounter(_counter(remaining)),
                      style: AxoType.bodyUi.copyWith(
                        color: c.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              AxoButton(
                label: l10n.verifyButton,
                expand: true,
                size: AxoButtonSize.lg,
                onPressed: state.busy || _code.length != 6 ? null : _verify,
              ),
              const SizedBox(height: AxoSpacing.lg),
              Center(
                child: AuthLink(
                  text: l10n.verifyChangeEmail,
                  onTap: () {
                    ref.read(authControllerProvider.notifier).changeEmail();
                    context.go('/register');
                  },
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
