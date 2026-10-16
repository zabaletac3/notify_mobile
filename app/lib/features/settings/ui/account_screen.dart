import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/error_messages.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../auth/state/auth_controller.dart';
import 'settings_labels.dart';
import 'settings_widgets.dart';

/// Mi cuenta (`/settings/account`, tablero «Android — Mi cuenta»): perfil, datos editables y cerrar
/// sesión. Los datos salen de la sesión; los diálogos llaman a los servicios de la fase 11.2.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final name = (user?.fullName.isNotEmpty ?? false)
        ? user!.fullName
        : settingsSampleName;
    final email = (user?.email.isNotEmpty ?? false)
        ? user!.email
        : settingsSampleEmail;
    return SettingsScaffold(
      title: 'Mi cuenta',
      children: [
        _ProfileCard(name: name, email: email),
        AxoSettingsGroup(
          title: 'Datos',
          children: [
            AxoSettingRow(
              label: 'Nombre',
              value: name,
              chevron: true,
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => _NameDialog(initial: name),
              ),
            ),
            AxoSettingRow(
              label: 'Correo electrónico',
              value: email,
              chevron: true,
              onTap: () => showDialog<void>(
                context: context,
                builder: (_) => const _EmailDialog(),
              ),
            ),
            AxoSettingRow(
              label: 'Contraseña',
              action: 'Cambiar',
              onAction: () => showDialog<void>(
                context: context,
                builder: (_) => const _PasswordDialog(),
              ),
            ),
          ],
        ),
        AxoSettingsGroup(
          children: [
            AxoSettingRow(
              label: 'Cerrar sesión',
              danger: true,
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.email});

  final String name;
  final String email;

  String get _initials {
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return words.take(2).map((w) => w.characters.first.toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Material(
      color: c.bgApp,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AxoRadii.xl),
        side: BorderSide(color: c.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: AxoSizes.settingsAvatar,
              height: AxoSizes.settingsAvatar,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.bgSelected,
                shape: BoxShape.circle,
              ),
              child: Text(
                _initials.isEmpty ? settingsSampleInitials : _initials,
                style: AxoType.dialogTitle.copyWith(
                  color: c.accentDefault,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AxoSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AxoType.sheetTitle.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AxoType.settingsRowValue.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo «Cambiar nombre». El controlador vive en el `State`.
class _NameDialog extends ConsumerStatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  ConsumerState<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends ConsumerState<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(_controller.text);
    if (!mounted) return;
    if (ok.isOk) {
      Navigator.of(context).pop();
      showAxoToast(
        context,
        message: 'Nombre actualizado',
        variant: AxoToastVariant.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final error = validationMessage(
      AppLocalizations.of(context),
      state.fieldErrors['fullName'],
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AxoDialog(
        title: 'Cambiar nombre',
        content: AxoField(
          label: 'Nombre',
          controller: _controller,
          error: error,
        ),
        actions: [
          _CancelButton(),
          AxoButton(
            label: 'Guardar',
            labelStyle: AxoType.buttonSm,
            onPressed: state.busy ? null : _save,
          ),
        ],
      ),
    );
  }
}

/// Diálogo «Cambiar correo» en dos pasos (correo+contraseña → código).
class _EmailDialog extends ConsumerStatefulWidget {
  const _EmailDialog();

  @override
  ConsumerState<_EmailDialog> createState() => _EmailDialogState();
}

class _EmailDialogState extends ConsumerState<_EmailDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    await ref
        .read(authControllerProvider.notifier)
        .requestEmailChange(_email.text, _password.text);
  }

  Future<void> _confirm() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .confirmEmailChange(_code.text);
    if (!mounted) return;
    if (ok.isOk) {
      Navigator.of(context).pop();
      showAxoToast(
        context,
        message: 'Correo actualizado',
        variant: AxoToastVariant.success,
      );
    }
  }

  void _cancel() {
    ref.read(authControllerProvider.notifier).cancelEmailChange();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context);
    final pending = state.pendingEmailChange;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AxoDialog(
        title: 'Cambiar correo',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pending == null) ...[
              AxoField(
                label: 'Correo nuevo',
                hint: 'nombre@correo.com',
                controller: _email,
                error: validationMessage(l10n, state.fieldErrors['email']),
              ),
              const SizedBox(height: AxoSpacing.lg),
              AxoField(
                label: 'Contraseña actual',
                controller: _password,
                obscure: true,
                error: validationMessage(l10n, state.fieldErrors['password']),
              ),
            ] else ...[
              Text(
                'Enviamos un código de 6 dígitos a $pending. Ingrésalo para confirmar el cambio.',
                style: AxoType.bodySmall.copyWith(
                  color: Theme.of(context)
                      .extension<AxoColors>()!
                      .textSecondary,
                ),
              ),
              const SizedBox(height: AxoSpacing.lg),
              AxoField(
                label: 'Código',
                hint: '123456',
                controller: _code,
                error: validationMessage(l10n, state.fieldErrors['code']),
              ),
            ],
          ],
        ),
        actions: [
          AxoButton(
            label: 'Cancelar',
            labelStyle: AxoType.buttonSm,
            variant: AxoButtonVariant.outline,
            onPressed: _cancel,
          ),
          AxoButton(
            label: pending == null ? 'Enviar código' : 'Confirmar',
            labelStyle: AxoType.buttonSm,
            onPressed: state.busy
                ? null
                : (pending == null ? _request : _confirm),
          ),
        ],
      ),
    );
  }
}

/// Diálogo «Cambiar contraseña»: actual + nueva + confirmación.
class _PasswordDialog extends ConsumerStatefulWidget {
  const _PasswordDialog();

  @override
  ConsumerState<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends ConsumerState<_PasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await ref
        .read(authControllerProvider.notifier)
        .changePassword(_current.text, _next.text, _confirm.text);
    if (!mounted) return;
    if (ok.isOk) {
      Navigator.of(context).pop();
      showAxoToast(
        context,
        message: 'Contraseña actualizada',
        variant: AxoToastVariant.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: AxoDialog(
        title: 'Cambiar contraseña',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AxoField(
              label: 'Contraseña actual',
              controller: _current,
              obscure: true,
              error: validationMessage(
                l10n,
                state.fieldErrors['currentPassword'],
              ),
            ),
            const SizedBox(height: AxoSpacing.lg),
            AxoField(
              label: 'Contraseña nueva',
              hint: 'Mínimo 8 caracteres',
              controller: _next,
              obscure: true,
              error: validationMessage(l10n, state.fieldErrors['password']),
            ),
            const SizedBox(height: AxoSpacing.lg),
            AxoField(
              label: 'Confirmar contraseña',
              controller: _confirm,
              obscure: true,
              error: validationMessage(l10n, state.fieldErrors['confirmation']),
            ),
          ],
        ),
        actions: [
          _CancelButton(),
          AxoButton(
            label: 'Guardar',
            labelStyle: AxoType.buttonSm,
            onPressed: state.busy ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AxoButton(
    label: 'Cancelar',
    labelStyle: AxoType.buttonSm,
    variant: AxoButtonVariant.outline,
    onPressed: () => Navigator.of(context).pop(),
  );
}
