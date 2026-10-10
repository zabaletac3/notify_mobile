import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/l10n/error_messages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('es'));

  test('mensajes de validación', () {
    expect(validationMessage(l10n, 'required'), 'Este campo es obligatorio.');
    expect(validationMessage(l10n, 'invalid-recovery-key'), contains('recuperación'));
    expect(validationMessage(l10n, 'codigo-desconocido'), 'codigo-desconocido');
    expect(validationMessage(l10n, null), isNull);
  });

  test('mensajes de error', () {
    expect(errorMessage(l10n, kind: 'network'), contains('Sin conexión'));
    expect(errorMessage(l10n, kind: 'session-expired'), contains('sesión expiró'));
    expect(
      errorMessage(l10n, kind: 'conflict', code: 'mfa-not-enabled'),
      'La verificación en dos pasos no está activada.',
    );
    expect(errorMessage(l10n, kind: 'desconocido'), contains('Algo salió mal'));
  });
}
