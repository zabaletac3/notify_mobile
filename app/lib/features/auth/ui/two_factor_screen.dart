import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/error_messages.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';

/// Segundo paso del login (sin tablero propio; se compone con los tokens base): código TOTP de 6
/// dígitos o un código de respaldo.
class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .verifyMfa(_code.text);
    if (ok.isOk && mounted) context.go('/notes');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    final state = ref.watch(authControllerProvider);
    if (!state.mfaPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/login');
      });
    }
    final codeError = validationMessage(l10n, state.fieldErrors['code']);

    return Scaffold(
      backgroundColor: c.bgApp,
      body: AuthBody(
        children: [
          const SizedBox(height: AxoSpacing.sm),
          const AuthIconBadge(icon: 'lock'),
          const SizedBox(height: AxoSpacing.xl),
          Text(
            l10n.twoFactorTitle,
            style: AxoType.title.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: AxoSpacing.md),
          Text(
            l10n.twoFactorBody,
            style: AxoType.body.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: AxoSpacing.xl),
          AxoField(
            label: l10n.fieldMfaCode,
            hint: l10n.fieldMfaCodeHint,
            controller: _code,
            error: codeError,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AxoSpacing.xxl),
          AxoButton(
            label: l10n.twoFactorButton,
            expand: true,
            size: AxoButtonSize.lg,
            onPressed: state.busy || _code.text.trim().isEmpty ? null : _submit,
          ),
          const SizedBox(height: AxoSpacing.lg),
          Center(
            child: AuthLink(
              text: l10n.twoFactorBackToLogin,
              onTap: () => context.go('/login'),
            ),
          ),
        ],
      ),
    );
  }
}
