import 'auth.dart';
import 'folder.dart';
import 'note_text.dart';

/// Códigos de validación. El texto en español vive en la capa de interfaz.
typedef ValidationCode = String;

/// Errores por campo.
typedef FieldErrors = Map<String, ValidationCode>;

/// Resultado de una validación: válida o con errores por campo.
sealed class Validation {
  const Validation();
}

final class Valid extends Validation {
  const Valid();
}

final class Invalid extends Validation {
  const Invalid(this.errors);

  final FieldErrors errors;
}

Validation _done(FieldErrors errors) =>
    errors.isEmpty ? const Valid() : Invalid(errors);

/// Longitud mínima de una contraseña.
const int passwordMinLength = 8;

/// ¿Es un correo con forma válida? (Portado de `isValidEmail` de `validation.ts`.)
bool isValidEmail(String email) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(email.trim());

/// Fuerza de una contraseña: [score] de 0 (muy débil) a 4 (fuerte) y su etiqueta en español.
class PasswordStrength {
  const PasswordStrength({required this.score, required this.label});

  /// 0 = muy débil … 4 = fuerte. Son los 4 segmentos del medidor del diseño.
  final int score;
  final String label;
}

/// Calcula la fuerza de la contraseña (portado de `passwordStrength`).
PasswordStrength passwordStrength(String password) {
  if (password.isEmpty) {
    return const PasswordStrength(score: 0, label: 'Muy débil');
  }
  var score = 0;
  if (password.length >= passwordMinLength) score++;
  if (RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'[A-Z]').hasMatch(password)) {
    score++;
  }
  if (RegExp(r'\d').hasMatch(password)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
  final s = score > 4 ? 4 : score;
  const labels = ['Muy débil', 'Débil', 'Aceptable', 'Buena', 'Fuerte'];
  return PasswordStrength(score: s, label: labels[s]);
}

/// Validación del formulario de registro (portado de `validateRegister`).
Validation validateRegister(RegisterInput input) {
  final errors = <String, ValidationCode>{};
  if (input.fullName.trim().length < 2) errors['fullName'] = 'name-too-short';
  if (input.email.trim().isEmpty) {
    errors['email'] = 'required';
  } else if (!isValidEmail(input.email)) {
    errors['email'] = 'invalid-email';
  }
  if (input.password.length < passwordMinLength) {
    errors['password'] = 'password-too-short';
  }
  if (!input.acceptedTerms) errors['acceptedTerms'] = 'terms-required';
  return _done(errors);
}

/// Validación del formulario de inicio de sesión (portado de `validateLogin`).
Validation validateLogin(LoginInput input) {
  final errors = <String, ValidationCode>{};
  if (input.email.trim().isEmpty) {
    errors['email'] = 'required';
  } else if (!isValidEmail(input.email)) {
    errors['email'] = 'invalid-email';
  }
  if (input.password.isEmpty) errors['password'] = 'required';
  return _done(errors);
}

/// Validación de un correo suelto (portado de `validateEmail`).
Validation validateEmail(String email) {
  if (email.trim().isEmpty) return const Invalid({'email': 'required'});
  return _done(
    isValidEmail(email) ? const {} : const {'email': 'invalid-email'},
  );
}

/// Contraseña nueva + confirmación (portado de `validateNewPassword`).
Validation validateNewPassword(String password, String confirmation) {
  final errors = <String, ValidationCode>{};
  if (password.length < passwordMinLength) {
    errors['password'] = 'password-too-short';
  }
  if (confirmation != password) errors['confirmation'] = 'passwords-dont-match';
  return _done(errors);
}

/// Código de verificación de correo: exactamente [verificationCodeLength] dígitos.
Validation validateVerificationCode(String code) => _done(
  RegExp('^\\d{$verificationCodeLength}\$').hasMatch(code)
      ? const {}
      : const {'code': 'invalid-code'},
);

/// Código del segundo paso: 6 dígitos (TOTP) o un código de respaldo (`XXXXX-XXXXX`).
Validation validateMfaCode(String code) =>
    _done(isMfaCode(code) ? const {} : const {'code': 'invalid-code'});

/// Nombre de perfil (portado de `validateProfileName`).
Validation validateProfileName(String fullName) => _done(
  fullName.trim().length < 2 ? const {'fullName': 'name-too-short'} : const {},
);

/// Cambio de correo: correo nuevo válido y contraseña actual (portado de `validateEmailChange`).
Validation validateEmailChange(String email, String password) {
  final errors = <String, ValidationCode>{};
  if (email.trim().isEmpty) {
    errors['email'] = 'required';
  } else if (!isValidEmail(email)) {
    errors['email'] = 'invalid-email';
  }
  if (password.isEmpty) errors['password'] = 'required';
  return _done(errors);
}

/// Cambio de contraseña desde ajustes (portado de `validateChangePassword`).
Validation validateChangePassword(
  String currentPassword,
  String newPassword,
  String confirmation,
) {
  final errors = <String, ValidationCode>{};
  if (currentPassword.isEmpty) errors['currentPassword'] = 'required';
  if (newPassword.length < passwordMinLength) {
    errors['password'] = 'password-too-short';
  } else if (newPassword == currentPassword) {
    errors['password'] = 'same-password';
  }
  if (confirmation != newPassword) {
    errors['confirmation'] = 'passwords-dont-match';
  }
  return _done(errors);
}

/// Restablecer la contraseña: contraseña nueva y, según la opción, la clave de recuperación o la
/// confirmación de borrado (portado de `validatePasswordReset`).
Validation validatePasswordReset(
  String password,
  String confirmation,
  ({String? recoveryKey, bool? wipeConfirmed}) choice,
) {
  final errors = <String, ValidationCode>{};
  if (password.length < passwordMinLength) {
    errors['password'] = 'password-too-short';
  }
  if (confirmation != password) errors['confirmation'] = 'passwords-dont-match';
  if (choice.recoveryKey != null && choice.recoveryKey!.trim().isEmpty) {
    errors['recoveryKey'] = 'required';
  }
  if (choice.wipeConfirmed == false) errors['wipe'] = 'wipe-not-confirmed';
  return _done(errors);
}

/// Nombre de carpeta: 1–30 caracteres y único (sin distinguir mayúsculas ni tildes).
/// Portado de `validateFolderName` de `notify_web/src/lib/domain/validation.ts`.
Validation validateFolderName(String name, List<String> existing) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return const Invalid({'name': 'required'});
  if (trimmed.length > folderNameMaxLength) {
    return const Invalid({'name': 'name-too-long'});
  }
  final folded = foldText(trimmed);
  if (existing.any((e) => foldText(e) == folded)) {
    return const Invalid({'name': 'name-taken'});
  }
  return const Valid();
}
