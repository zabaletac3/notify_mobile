import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/error_messages.dart';
import '../../../router/navigation.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../auth/state/auth_controller.dart';
import 'settings_widgets.dart';

/// Eliminar cuenta (`/settings/delete-account`, tablero «Android — Eliminar cuenta»). Exige la
/// contraseña actual (contrato `POST /me/delete`, prueba `authKey`); los datos se conservan 30 días
/// y se cierran todas las sesiones. Al terminar, la sesión local se cierra y se vuelve a la
/// bienvenida.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final result = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount(_password.text);
    if (!mounted) return;
    switch (result) {
      case Ok():
        // La sesión local ya se cerró; el router lleva a la bienvenida.
        break;
      case Err(error: final error):
        showAxoToast(
          context,
          message: errorMessageFor(l10n, error),
          variant: AxoToastVariant.error,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(authControllerProvider);
    return SettingsScaffold(
      title: 'Eliminar cuenta',
      children: [
        Material(
          color: c.statusDangerBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AxoRadii.xl),
            side: BorderSide(color: c.statusDanger),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esta acción no se puede deshacer',
                  style: AxoType.button.copyWith(color: c.statusDanger),
                ),
                const SizedBox(height: AxoSpacing.sm),
                Text(
                  '• Se borrarán todas tus notas y carpetas.\n'
                  '• Se cerrará tu sesión en todos los dispositivos.\n'
                  '• No podremos recuperar tus datos después de 30\ndías.',
                  style: AxoType.body.copyWith(color: c.textPrimary),
                ),
              ],
            ),
          ),
        ),
        AxoField(
          label: 'Escribe tu contraseña para confirmar',
          controller: _password,
          obscure: true,
          onChanged: (_) => setState(() {}),
          error: validationMessage(l10n, state.fieldErrors['password']),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AxoButton(
              label: state.busy ? 'Eliminando…' : 'Eliminar mi cuenta',
              variant: AxoButtonVariant.destructive,
              size: AxoButtonSize.lg,
              expand: true,
              onPressed: _password.text.isEmpty || state.busy ? null : _delete,
            ),
            const SizedBox(height: AxoSpacing.md),
            AxoButton(
              label: 'Cancelar',
              variant: AxoButtonVariant.outline,
              size: AxoButtonSize.lg,
              expand: true,
              onPressed: () => goBack(context),
            ),
          ],
        ),
      ],
    );
  }
}
