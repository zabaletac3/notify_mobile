import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr/qr.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/error_messages.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../auth/state/auth_controller.dart';
import '../state/mfa_status_controller.dart';
import 'settings_widgets.dart';

/// Verificación en dos pasos (`/settings/two-factor`; sin tablero en «Movil v2», se sigue la web):
/// activar (contraseña → QR + secreto → código), desactivar y regenerar códigos de respaldo. Las
/// operaciones sensibles piden la contraseña y un código.
class TwoFactorSettingsScreen extends ConsumerStatefulWidget {
  const TwoFactorSettingsScreen({super.key});

  @override
  ConsumerState<TwoFactorSettingsScreen> createState() =>
      _TwoFactorSettingsScreenState();
}

class _TwoFactorSettingsScreenState
    extends ConsumerState<TwoFactorSettingsScreen> {
  MfaSetup? _setup;
  List<String>? _codes;
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final password = await _askPassword('Activar verificación en dos pasos');
    if (password == null) return;
    final result = await ref
        .read(authControllerProvider.notifier)
        .mfaSetup(password);
    if (!mounted) return;
    switch (result) {
      case Ok(value: final setup):
        setState(() => _setup = setup);
      case Err(error: final error):
        _toast(error);
    }
  }

  Future<void> _enable() async {
    final result = await ref
        .read(authControllerProvider.notifier)
        .mfaEnable(_code.text.trim());
    if (!mounted) return;
    switch (result) {
      case Ok(value: final codes):
        _code.clear();
        setState(() {
          _setup = null;
          _codes = codes;
        });
        ref.invalidate(mfaStatusProvider);
      case Err(error: final error):
        _toast(error);
    }
  }

  Future<void> _disable() async {
    final input = await _askPasswordCode(
      'Desactivar verificación en dos pasos',
    );
    if (input == null) return;
    final result = await ref
        .read(authControllerProvider.notifier)
        .mfaDisable(input.$1, input.$2);
    if (!mounted) return;
    switch (result) {
      case Ok():
        ref.invalidate(mfaStatusProvider);
      case Err(error: final error):
        _toast(error);
    }
  }

  Future<void> _regenerate() async {
    final input = await _askPasswordCode('Regenerar códigos de respaldo');
    if (input == null) return;
    final result = await ref
        .read(authControllerProvider.notifier)
        .mfaRegenerateCodes(input.$1, input.$2);
    if (!mounted) return;
    switch (result) {
      case Ok(value: final codes):
        setState(() => _codes = codes);
      case Err(error: final error):
        _toast(error);
    }
  }

  void _toast(AppError error) {
    showAxoToast(
      context,
      message: errorMessageFor(context.l10n, error),
      variant: AxoToastVariant.error,
    );
  }

  Future<String?> _askPassword(String title) => showDialog<String>(
    context: context,
    builder: (_) => _PasswordDialog(title: title),
  );

  Future<(String, String)?> _askPasswordCode(String title) =>
      showDialog<(String, String)>(
        context: context,
        builder: (_) => _PasswordCodeDialog(title: title),
      );

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    if (_codes != null) {
      return _CodesView(
        codes: _codes!,
        onDone: () => setState(() => _codes = null),
      );
    }
    if (_setup != null) {
      return SettingsScaffold(
        title: 'Verificación en dos pasos',
        children: [
          AxoSettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escanea el código con tu autenticador o escribe el secreto.',
                      style: AxoType.settingsRowDescription.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AxoSpacing.lg),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.white,
                        child: _Qr(data: _setup!.otpauthUri, size: 180),
                      ),
                    ),
                    const SizedBox(height: AxoSpacing.md),
                    Center(
                      child: SelectableText(
                        _setup!.secret,
                        style: AxoType.bodyUi.copyWith(color: c.textPrimary),
                      ),
                    ),
                    const SizedBox(height: AxoSpacing.lg),
                    AxoField(
                      label: 'Código',
                      hint: '123456',
                      controller: _code,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AxoSpacing.xl),
          Row(
            children: [
              Expanded(
                child: AxoButton(
                  label: 'Cancelar',
                  variant: AxoButtonVariant.outline,
                  size: AxoButtonSize.lg,
                  onPressed: () => setState(() => _setup = null),
                ),
              ),
              const SizedBox(width: AxoSpacing.md),
              Expanded(
                child: AxoButton(
                  label: 'Activar',
                  size: AxoButtonSize.lg,
                  onPressed: _enable,
                ),
              ),
            ],
          ),
        ],
      );
    }
    final status = ref.watch(mfaStatusProvider);
    return SettingsScaffold(
      title: 'Verificación en dos pasos',
      children: [
        AxoSettingsGroup(
          children: [
            AxoSettingRow(
              label: 'Estado',
              value: status.value == null
                  ? 'Cargando…'
                  : (status.value!.enabled ? 'Activada' : 'Desactivada'),
            ),
          ],
        ),
        if (status.value?.enabled ?? false) ...[
          AxoSettingRow(
            label: 'Regenerar códigos de respaldo',
            chevron: true,
            onTap: _regenerate,
          ),
          AxoSettingsGroup(
            children: [
              AxoSettingRow(
                label: 'Desactivar verificación en dos pasos',
                danger: true,
                onTap: _disable,
              ),
            ],
          ),
        ] else
          AxoSettingsGroup(
            children: [
              AxoSettingRow(
                label: 'Activar verificación en dos pasos',
                chevron: true,
                onTap: _activate,
              ),
            ],
          ),
      ],
    );
  }
}

class _CodesView extends StatelessWidget {
  const _CodesView({required this.codes, required this.onDone});

  final List<String> codes;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return SettingsScaffold(
      title: 'Códigos de respaldo',
      children: [
        Text(
          'Guarda estos códigos en un lugar seguro. Se muestran una sola vez.',
          style: AxoType.bodySmall.copyWith(color: c.textSecondary),
        ),
        AxoSettingsGroup(
          children: [
            for (final code in codes)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SelectableText(
                  code,
                  style: AxoType.bodyUi.copyWith(color: c.textPrimary),
                ),
              ),
          ],
        ),
        AxoButton(
          label: 'Copiar los códigos',
          variant: AxoButtonVariant.outline,
          size: AxoButtonSize.lg,
          expand: true,
          onPressed: () =>
              AxonotePlatform.instance.copySensitive(codes.join('\n')),
        ),
        const SizedBox(height: AxoSpacing.md),
        AxoButton(
          label: 'Ya los guardé',
          size: AxoButtonSize.lg,
          expand: true,
          onPressed: onDone,
        ),
      ],
    );
  }
}

/// QR sin dependencia de `qr_flutter`: se pinta la matriz del paquete `qr`.
class _Qr extends StatelessWidget {
  const _Qr({required this.data, required this.size});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final image = QrImage(code);
    return CustomPaint(size: Size.square(size), painter: _QrPainter(image));
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final cell = size.width / n;
    final dark = Paint()..color = const Color(0xFF000000);
    final light = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Offset.zero & size, light);
    for (var r = 0; r < n; r++) {
      for (var col = 0; col < n; col++) {
        if (image.isDark(r, col)) {
          canvas.drawRect(
            Rect.fromLTWH(col * cell, r * cell, cell, cell),
            dark,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) => false;
}

/// Diálogo que pide la contraseña (para el paso que la exige). El controlador vive en el `State`.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.title});

  final String title;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
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
      title: widget.title,
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
          label: 'Continuar',
          labelStyle: AxoType.buttonSm,
          onPressed: () => Navigator.of(context).pop(_password.text),
        ),
      ],
    ),
  );
}

/// Diálogo que pide contraseña + código (desactivar / regenerar).
class _PasswordCodeDialog extends StatefulWidget {
  const _PasswordCodeDialog({required this.title});

  final String title;

  @override
  State<_PasswordCodeDialog> createState() => _PasswordCodeDialogState();
}

class _PasswordCodeDialogState extends State<_PasswordCodeDialog> {
  final _password = TextEditingController();
  final _code = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: AxoDialog(
      title: widget.title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AxoField(label: 'Contraseña', controller: _password, obscure: true),
          const SizedBox(height: AxoSpacing.lg),
          AxoField(label: 'Código', hint: '123456', controller: _code),
        ],
      ),
      actions: [
        AxoButton(
          label: 'Cancelar',
          labelStyle: AxoType.buttonSm,
          variant: AxoButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AxoButton(
          label: 'Confirmar',
          labelStyle: AxoType.buttonSm,
          onPressed: () =>
              Navigator.of(context).pop((_password.text, _code.text.trim())),
        ),
      ],
    ),
  );
}

extension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
