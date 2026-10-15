import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/error_messages.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../auth/state/auth_controller.dart';
import '../state/devices_controller.dart';
import '../state/lock_settings_controller.dart';
import '../state/mfa_status_controller.dart';
import 'settings_labels.dart';
import 'settings_widgets.dart';

/// Privacidad y seguridad (`/settings/privacy`, tablero «Android — Privacidad y seguridad»):
/// bloqueo del cofre (§5.3), cifrado (informativo: la base siempre va cifrada) y cuenta
/// (verificación en dos pasos y sesiones activas, reales).
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(lockSettingsProvider).value ?? const LockSettings();
    final lockCtrl = ref.read(lockSettingsProvider.notifier);
    final mfa = ref.watch(mfaStatusProvider).value;
    final devices = ref.watch(devicesProvider).value;
    void setLock(LockSettings next) => lockCtrl.save(next);
    return SettingsScaffold(
      title: 'Privacidad y seguridad',
      children: [
        AxoSettingsGroup(
          title: 'Bloqueo',
          children: [
            AxoSettingRow(
              label: 'Bloqueo con huella',
              control: AxoSwitch(
                value: lock.biometricLock,
                onChanged: (v) => setLock(lock.copyWith(biometricLock: v)),
              ),
            ),
            AxoSettingRow(
              label: 'Bloquear al salir de la app',
              control: AxoSwitch(
                value: lock.lockOnExit,
                onChanged: (v) => setLock(lock.copyWith(lockOnExit: v)),
              ),
            ),
            AxoSettingRow(
              label: 'Tiempo de bloqueo',
              value: settingsLockTimeoutLabel(lock.lockTimeout.wire),
              chevron: true,
              onTap: () => showSettingsChoice(
                context,
                title: 'Tiempo de bloqueo',
                value: lock.lockTimeout.wire,
                options: const [
                  ('immediately', 'Inmediatamente'),
                  ('1m', '1 minuto'),
                  ('5m', '5 minutos'),
                  ('15m', '15 minutos'),
                  ('never', 'Nunca'),
                ],
                onSelected: (v) => setLock(
                  lock.copyWith(
                    lockTimeout: LockTimeout.values.firstWhere(
                      (t) => t.wire == v,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        AxoSettingsGroup(
          title: 'Datos',
          children: [
            // Informativo: la base local va cifrada siempre (§6, fases 5/6); no es un ajuste.
            const AxoSettingRow(
              label: 'Cifrar notas en este dispositivo',
              description:
                  'Protege tus notas si pierdes el equipo. Siempre activo.',
            ),
            AxoSettingRow(
              label: 'Clave de recuperación',
              action: 'Crear nueva',
              onAction: () => _rotateRecoveryKey(context, ref),
            ),
          ],
        ),
        AxoSettingsGroup(
          title: 'Cuenta',
          children: [
            AxoSettingRow(
              label: 'Verificación en dos pasos',
              value: (mfa?.enabled ?? false) ? 'Activada' : 'Desactivada',
              chevron: true,
              onTap: () => context.push('/settings/two-factor'),
            ),
            AxoSettingRow(
              label: 'Sesiones activas',
              value: devices == null
                  ? '—'
                  : (devices.length == 1
                        ? '1 dispositivo'
                        : '${devices.length} dispositivos'),
              chevron: true,
              onTap: () => context.push('/settings/sync'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Rota la clave de recuperación: pide la contraseña, la sustituye y muestra la nueva (una sola vez).
Future<void> _rotateRecoveryKey(BuildContext context, WidgetRef ref) async {
  final password = await showDialog<String>(
    context: context,
    builder: (_) => const _RecoveryPasswordDialog(),
  );
  if (password == null || password.isEmpty || !context.mounted) return;
  final result = await ref
      .read(authControllerProvider.notifier)
      .rotateRecoveryKey(password);
  if (!context.mounted) return;
  switch (result) {
    case Ok(value: final key):
      await showDialog<void>(
        context: context,
        builder: (_) => _RecoveryKeyDialog(recoveryKey: key),
      );
    case Err(error: final error):
      showAxoToast(
        context,
        message: errorMessageFor(AppLocalizations.of(context), error),
        variant: AxoToastVariant.error,
      );
  }
}

class _RecoveryPasswordDialog extends StatefulWidget {
  const _RecoveryPasswordDialog();

  @override
  State<_RecoveryPasswordDialog> createState() =>
      _RecoveryPasswordDialogState();
}

class _RecoveryPasswordDialogState extends State<_RecoveryPasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: AxoDialog(
      title: 'Nueva clave de recuperación',
      content: AxoField(
        label: 'Contraseña',
        controller: _password,
        obscure: true,
        autofocus: true,
      ),
      actions: [
        AxoButton(
          label: 'Cancelar',
          labelStyle: AxoType.buttonSm,
          variant: AxoButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AxoButton(
          label: 'Crear nueva',
          labelStyle: AxoType.buttonSm,
          onPressed: () => Navigator.of(context).pop(_password.text),
        ),
      ],
    ),
  );
}

class _RecoveryKeyDialog extends StatelessWidget {
  const _RecoveryKeyDialog({required this.recoveryKey});

  final String recoveryKey;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: AxoDialog(
      title: 'Tu clave de recuperación',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Guárdala en un lugar seguro. Es la única forma de recuperar tus notas si olvidas la '
            'contraseña, y no se vuelve a mostrar.',
            style: AxoType.bodySmall.copyWith(
              color: Theme.of(context).extension<AxoColors>()!.textSecondary,
            ),
          ),
          const SizedBox(height: AxoSpacing.lg),
          SelectableText(
            recoveryKey,
            style: AxoType.bodyUi.copyWith(
              color: Theme.of(context).extension<AxoColors>()!.textPrimary,
            ),
          ),
        ],
      ),
      actions: [
        AxoButton(
          label: 'Copiar',
          labelStyle: AxoType.buttonSm,
          variant: AxoButtonVariant.outline,
          onPressed: () => AxonotePlatform.instance.copySensitive(recoveryKey),
        ),
        AxoButton(
          label: 'Ya la guardé',
          labelStyle: AxoType.buttonSm,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
