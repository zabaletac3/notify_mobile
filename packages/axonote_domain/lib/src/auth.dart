/// Tipos de cuenta y sesión (plan §10, Fase 8). Dart puro: los usan el estado y la capa de datos;
/// la interfaz solo ve sus campos no sensibles. Referencia: `notify_web/src/lib/domain/auth.ts`.
library;

/// Cuenta autenticada.
class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.emailVerified,
    required this.hasGoogle,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String fullName;
  final bool emailVerified;
  final bool hasGoogle;
  final DateTime createdAt;

  User copyWith({String? fullName, String? email, bool? hasGoogle}) => User(
    id: id,
    email: email ?? this.email,
    fullName: fullName ?? this.fullName,
    emailVerified: emailVerified,
    hasGoogle: hasGoogle ?? this.hasGoogle,
    createdAt: createdAt,
  );
}

/// Estado de autenticación visible para la interfaz.
enum AuthStatus { unknown, anonymous, authenticated, expired }

/// Datos del formulario de registro.
class RegisterInput {
  const RegisterInput({
    required this.fullName,
    required this.email,
    required this.password,
    required this.acceptedTerms,
  });

  final String fullName;
  final String email;
  final String password;
  final bool acceptedTerms;
}

/// Datos del formulario de inicio de sesión.
class LoginInput {
  const LoginInput({required this.email, required this.password});

  final String email;
  final String password;
}

/// Parámetros de derivación Argon2id de una cuenta (copia de `KdfParams` del contrato, sin depender
/// de `axonote_crypto`: `axonote_domain` es puro y no puede importarlo).
class KdfParams {
  const KdfParams({
    required this.alg,
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.salt,
  });

  final String alg;
  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final String salt;
}

/// Claves cifradas de una cuenta, tal como las sirve el servidor. Nada de esto permite descifrar
/// sin la contraseña o la clave de recuperación.
class KeyBundle {
  const KeyBundle({
    required this.kdf,
    required this.wrappedMasterKey,
    required this.recoveryWrappedMasterKey,
    required this.keysVersion,
  });

  final KdfParams kdf;

  /// Clave maestra cifrada con la clave derivada de la contraseña (`a1.…`).
  final String wrappedMasterKey;

  /// La misma clave maestra, cifrada con la clave de recuperación.
  final String recoveryWrappedMasterKey;

  final int keysVersion;
}

/// Cuerpo de `POST /auth/register`: pruebas derivadas y claves ya cifradas (nunca la contraseña).
class RegisterRequest {
  const RegisterRequest({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.acceptedTerms,
    required this.authKey,
    required this.recoveryAuth,
    required this.keys,
  });

  final String userId;
  final String fullName;
  final String email;
  final bool acceptedTerms;
  final String authKey;
  final String recoveryAuth;
  final KeyBundle keys;
}

/// `POST /auth/register` responde el correo con el que se creó la cuenta.
class RegisterResult {
  const RegisterResult(this.email);

  final String email;
}

/// Reto de segundo paso: el primer factor fue correcto pero falta el código. No es una sesión.
class MfaChallenge {
  const MfaChallenge({required this.mfaToken, required this.expiresAt});

  /// Ticket de un solo uso y corta vida (5 minutos).
  final String mfaToken;
  final DateTime expiresAt;
}

/// Sesión iniciada con las claves cifradas de la cuenta.
class LoginResult {
  const LoginResult({
    required this.user,
    required this.expiresAt,
    required this.keys,
  });

  final User user;
  final DateTime expiresAt;
  final KeyBundle keys;
}

/// Respuesta de inicio de sesión: sesión completa o reto de segundo paso.
sealed class LoginOutcome {
  const LoginOutcome();
}

/// El inicio de sesión terminó: hay sesión y claves.
final class LoginSucceeded extends LoginOutcome {
  const LoginSucceeded(this.result);

  final LoginResult result;
}

/// Falta el segundo factor (código TOTP o de respaldo).
final class LoginMfaRequired extends LoginOutcome {
  const LoginMfaRequired(this.challenge);

  final MfaChallenge challenge;
}

/// Por qué se cerró la sesión sin que la persona lo pidiera (la pantalla de inicio lo explica).
enum AuthNotice { deviceRevoked, signedOutElsewhere, mfaExpired }

/// Estado de la verificación en dos pasos de la cuenta.
class MfaStatus {
  const MfaStatus({
    required this.enabled,
    required this.enabledAt,
    required this.recoveryCodesLeft,
  });

  final bool enabled;
  final DateTime? enabledAt;
  final int recoveryCodesLeft;
}

/// Lo que se muestra una sola vez al configurar el autenticador.
class MfaSetupResult {
  const MfaSetupResult({required this.secret, required this.otpauthUri});

  final String secret;
  final String otpauthUri;
}

/// Códigos de respaldo (se devuelven en claro una sola vez).
class MfaRecoveryCodes {
  const MfaRecoveryCodes(this.recoveryCodes);

  final List<String> recoveryCodes;
}

/// Longitud del código de verificación de correo.
const int verificationCodeLength = 6;

/// Longitud del código TOTP.
const int mfaCodeLength = 6;

/// Alfabeto y forma de un código de respaldo (`XXXXX-XXXXX`).
final RegExp mfaRecoveryCodeRegex = RegExp(r'^[A-Z2-9]{5}-[A-Z2-9]{5}$');

/// Un código MFA es de 6 dígitos (TOTP) o con forma de código de respaldo (`XXXXX-XXXXX`).
bool isMfaCode(String code) {
  final trimmed = code.trim();
  return RegExp('^\\d{$mfaCodeLength}\$').hasMatch(trimmed) ||
      mfaRecoveryCodeRegex.hasMatch(trimmed);
}
