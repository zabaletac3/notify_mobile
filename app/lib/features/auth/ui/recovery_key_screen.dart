import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../ui/components.dart';
import '../../../ui/secure_screen.dart';
import '../../../ui/tokens.dart';
import '../state/auth_controller.dart';
import 'auth_widgets.dart';

/// Clave de recuperación (sin tablero propio en Penpot; se compone con los tokens y componentes
/// base). Se muestra **una sola vez**, con `FLAG_SECURE`, y hay que confirmar que se guardó.
class RecoveryKeyScreen extends ConsumerStatefulWidget {
  const RecoveryKeyScreen({super.key});

  @override
  ConsumerState<RecoveryKeyScreen> createState() => _RecoveryKeyScreenState();
}

class _RecoveryKeyScreenState extends ConsumerState<RecoveryKeyScreen> {
  bool _confirmed = false;

  Future<void> _copy(String key) async {
    await AxonotePlatform.instance.copySensitive(key).catchError((_) {});
    if (!mounted) return;
    showAxoToast(
      context,
      message: AppLocalizations.of(context).recoveryKeyCopied,
      variant: AxoToastVariant.success,
    );
  }

  void _finish() {
    ref.read(authControllerProvider.notifier).acknowledgeRecoveryKey();
    context.go('/notes');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = Theme.of(context).extension<AxoColors>()!;
    final key = ref.watch(authControllerProvider).pendingRecoveryKey ?? '';

    return SecureScreen(
      child: Scaffold(
        backgroundColor: c.bgApp,
        body: AuthBody(
          children: [
            const SizedBox(height: AxoSpacing.sm),
            const AuthIconBadge(icon: 'lock-open'),
            const SizedBox(height: AxoSpacing.xl),
            Text(
              l10n.recoveryKeyTitle,
              style: AxoType.title.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AxoSpacing.md),
            Text(
              l10n.recoveryKeyIntro,
              style: AxoType.body.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: AxoSpacing.xl),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AxoSpacing.lg),
              decoration: BoxDecoration(
                color: c.bgInput,
                borderRadius: BorderRadius.circular(AxoRadii.lg),
              ),
              child: SelectableText(
                key,
                textAlign: TextAlign.center,
                style: AxoType.bodyUi.copyWith(
                  color: c.textPrimary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: AxoSpacing.md),
            AxoButton(
              label: l10n.recoveryKeyCopy,
              variant: AxoButtonVariant.outline,
              icon: 'copy',
              expand: true,
              onPressed: key.isEmpty ? null : () => _copy(key),
            ),
            const SizedBox(height: AxoSpacing.lg),
            AxoCheckbox(
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v),
              label: l10n.recoveryKeyConfirmLabel,
            ),
            const SizedBox(height: AxoSpacing.xxl),
            AxoButton(
              label: l10n.recoveryKeyContinue,
              expand: true,
              size: AxoButtonSize.lg,
              onPressed: _confirmed ? _finish : null,
            ),
          ],
        ),
      ),
    );
  }
}
