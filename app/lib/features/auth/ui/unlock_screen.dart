import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/error_messages.dart';
import '../../../ui/components.dart';
import '../../../ui/secure_screen.dart';
import '../../../ui/tokens.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';

/// Desbloqueo del cofre (sin tablero propio; se compone con los tokens base). Contraseña y, si hay
/// clave recordada, biometría o el bloqueo del teléfono (plan §5.3, D4). `FLAG_SECURE` activo.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _password = TextEditingController();
  bool _biometricFailed = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    await ref.read(authControllerProvider.notifier).unlock(_password.text);
  }

  Future<void> _biometric() async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .unlockWithStoredKey(l10n.unlockBiometricPrompt);
    if (!ok.isOk) setState(() => _biometricFailed = true);
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    final state = ref.watch(authControllerProvider);
    final passwordError = validationMessage(
      l10n,
      state.fieldErrors['password'],
    );

    return SecureScreen(
      child: Scaffold(
        backgroundColor: c.bgApp,
        body: AuthBody(
          children: [
            const SizedBox(height: AxoSpacing.xxl),
            const Center(child: AuthLogo(size: 64, letter: 'A')),
            const SizedBox(height: AxoSpacing.xxl),
            Text(
              l10n.unlockTitle,
              style: AxoType.title.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AxoSpacing.sm),
            Text(
              l10n.unlockPasswordBody,
              style: AxoType.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: AxoSpacing.xl),
            if (state.notice == AuthNotice.mfaExpired)
              Padding(
                padding: const EdgeInsets.only(bottom: AxoSpacing.lg),
                child: AxoBanner(message: l10n.mfaExpiredNotice),
              ),
            AxoField(
              label: l10n.fieldPassword,
              hint: l10n.fieldPasswordHint,
              controller: _password,
              obscure: true,
              error: passwordError,
              onChanged: (_) => setState(() {}),
            ),
            if (_biometricFailed && state.fieldErrors.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AxoSpacing.sm),
                child: Text(
                  l10n.errorLocked,
                  style: AxoType.caption.copyWith(color: c.textSecondary),
                ),
              ),
            const SizedBox(height: AxoSpacing.xxl),
            AxoButton(
              label: state.deriving ? l10n.derivingPassword : l10n.unlockButton,
              expand: true,
              size: AxoButtonSize.lg,
              onPressed: state.busy ? null : _unlock,
            ),
            const SizedBox(height: AxoSpacing.md),
            AxoButton(
              label: l10n.unlockBiometric,
              variant: AxoButtonVariant.outline,
              expand: true,
              onPressed: state.busy ? null : _biometric,
            ),
            const SizedBox(height: AxoSpacing.md),
            Center(
              child: AuthLink(
                text: l10n.forgotPasswordLink,
                onTap: () => context.go('/forgot-password'),
              ),
            ),
            Center(
              child: AuthLink(text: l10n.unlockSignOut, onTap: _signOut),
            ),
          ],
        ),
      ),
    );
  }
}
