import 'package:axonote_domain/axonote_domain.dart';

/// Estado visible de la cuenta (plan §10, Fase 8). Inmutable: cada acción produce una copia.
class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.busy = false,
    this.deriving = false,
    this.error,
    this.fieldErrors = const {},
    this.pendingEmail,
    this.resendAvailableAt,
    this.notice,
    this.mfaPending = false,
    this.resetRequested = false,
    this.resetEmail,
    this.pendingRecoveryKey,
    this.unlockFailures = 0,
  });

  final AuthStatus status;
  final User? user;

  /// Hay una acción en curso.
  final bool busy;

  /// Se está derivando la contraseña (Argon2id en isolate). La interfaz muestra progreso.
  final bool deriving;

  /// Error general de la última acción.
  final AppError? error;

  /// Códigos de validación por campo de la última acción (el texto sale de `validationMessage`).
  final FieldErrors fieldErrors;

  /// Correo pendiente de verificar (entre «registro» y «verificación»).
  final String? pendingEmail;

  /// Instante desde el que se puede reenviar el código.
  final DateTime? resendAvailableAt;

  /// Por qué se cerró la sesión sin que la persona lo pidiera.
  final AuthNotice? notice;

  /// `true` cuando un login quedó a la espera del segundo paso (código MFA).
  final bool mfaPending;

  /// `true` cuando ya se pidió el enlace de restablecimiento.
  final bool resetRequested;

  /// Correo al que se pidió el enlace de restablecimiento (para la pantalla «enviado»).
  final String? resetEmail;

  /// Clave de recuperación recién creada, pendiente de mostrar. Se enseña una sola vez.
  final String? pendingRecoveryKey;

  /// Intentos fallidos seguidos de desbloquear la app.
  final int unlockFailures;

  AuthState copyWith({
    AuthStatus? status,
    User? Function()? user,
    bool? busy,
    bool? deriving,
    AppError? Function()? error,
    FieldErrors? fieldErrors,
    String? Function()? pendingEmail,
    DateTime? Function()? resendAvailableAt,
    AuthNotice? Function()? notice,
    bool? mfaPending,
    bool? resetRequested,
    String? Function()? resetEmail,
    String? Function()? pendingRecoveryKey,
    int? unlockFailures,
  }) => AuthState(
    status: status ?? this.status,
    user: user == null ? this.user : user(),
    busy: busy ?? this.busy,
    deriving: deriving ?? this.deriving,
    error: error == null ? this.error : error(),
    fieldErrors: fieldErrors ?? this.fieldErrors,
    pendingEmail: pendingEmail == null ? this.pendingEmail : pendingEmail(),
    resendAvailableAt: resendAvailableAt == null
        ? this.resendAvailableAt
        : resendAvailableAt(),
    notice: notice == null ? this.notice : notice(),
    mfaPending: mfaPending ?? this.mfaPending,
    resetRequested: resetRequested ?? this.resetRequested,
    resetEmail: resetEmail == null ? this.resetEmail : resetEmail(),
    pendingRecoveryKey: pendingRecoveryKey == null
        ? this.pendingRecoveryKey
        : pendingRecoveryKey(),
    unlockFailures: unlockFailures ?? this.unlockFailures,
  );

  /// Olvida todo lo de la sesión que vive en memoria (no toca la sesión guardada).
  AuthState cleared() => const AuthState(status: AuthStatus.anonymous);
}

/// Resultado sin valor de una acción del estado.
typedef ActionResult = Result<bool>;

/// `Ok(true)` para acciones que no devuelven datos.
const ActionResult actionOk = Ok<bool>(true);

/// `Err` a partir de un [AppError].
ActionResult actionErr(AppError error) => Err<bool>(error);
