/// Errores de la aplicación como datos. La interfaz decide qué pantalla o aviso mostrar según la
/// clase (y su [AppError.kind], que coincide con el `kind` del contrato HTTP y con el `AppError` de
/// la web). Los repositorios los lanzan envueltos en [AppFailure].
///
/// Los subtipos solo guardan datos **no sensibles** (códigos, nombre de campo, instante de
/// reintento). Nunca texto de notas, tokens ni contraseñas: [AppFailure.toString] solo imprime el
/// `kind`, para que un registro accidental no filtre nada.
sealed class AppError {
  const AppError();

  /// Categoría del error, idéntica a la del contrato (`network`, `server`, `unauthorized`…).
  String get kind;
}

/// Sin red o servidor inalcanzable (pantalla «sin conexión»).
final class NetworkError extends AppError {
  const NetworkError();

  @override
  String get kind => 'network';
}

/// El servidor falló (pantalla «error de servidor»). [status] es el estado HTTP si se conoce.
final class ServerError extends AppError {
  const ServerError({this.status});

  final int? status;

  @override
  String get kind => 'server';
}

/// Credenciales incorrectas. Mismo error para correo inexistente y contraseña errónea.
final class UnauthorizedError extends AppError {
  const UnauthorizedError({this.code});

  /// Solo `invalid-credentials` está definido hoy en el contrato.
  final String? code;

  @override
  String get kind => 'unauthorized';
}

/// Códigos de `forbidden` que la interfaz distingue (el resto se trata como un 403 genérico).
enum ForbiddenCode {
  emailNotVerified('email-not-verified'),
  googleDisabled('google-disabled'),
  googleEmailUnverified('google-email-unverified'),
  accountDeleted('account-deleted'),
  googleNotLinked('google-not-linked'),
  limitReached('limit-reached');

  const ForbiddenCode(this.wire);

  /// Valor tal como viaja en el contrato.
  final String wire;
}

/// Acción no permitida (p. ej. iniciar sesión con el correo sin verificar).
final class ForbiddenError extends AppError {
  const ForbiddenError({this.code});

  final ForbiddenCode? code;

  @override
  String get kind => 'forbidden';
}

/// La sesión expiró (diálogo «sesión expirada»).
final class SessionExpiredError extends AppError {
  const SessionExpiredError();

  @override
  String get kind => 'session-expired';
}

/// La app está bloqueada: hace falta la contraseña para leer las notas.
final class LockedError extends AppError {
  const LockedError();

  @override
  String get kind => 'locked';
}

/// No se pudo descifrar un dato (clave incorrecta o datos alterados).
final class DecryptError extends AppError {
  const DecryptError();

  @override
  String get kind => 'decrypt';
}

/// Este dispositivo fue eliminado de la cuenta desde otro: hay que borrar la copia local.
final class DeviceRevokedError extends AppError {
  const DeviceRevokedError();

  @override
  String get kind => 'device-revoked';
}

/// No existe el recurso. [entity] lo nombra (`device`, `note`…).
final class NotFoundError extends AppError {
  const NotFoundError({this.entity});

  final String? entity;

  @override
  String get kind => 'not-found';
}

/// Datos inválidos: campo → código de validación.
final class ValidationError extends AppError {
  const ValidationError(this.fields);

  final Map<String, String> fields;

  @override
  String get kind => 'validation';
}

/// La nota cambió en otro dispositivo (pantalla de conflicto).
final class ConflictError extends AppError {
  const ConflictError({this.noteId, this.code});

  final String? noteId;
  final String? code;

  @override
  String get kind => 'conflict';
}

/// Demasiados intentos. [retryAfterSec] indica cuánto esperar.
final class RateLimitedError extends AppError {
  const RateLimitedError({this.retryAfterSec});

  final int? retryAfterSec;

  @override
  String get kind => 'rate-limited';
}

/// Error no clasificado. El [message] es un texto de diagnóstico del cliente, nunca del servidor.
final class UnknownError extends AppError {
  const UnknownError({this.message});

  final String? message;

  @override
  String get kind => 'unknown';
}

/// Excepción que transporta un [AppError]. Es lo único que lanzan los repositorios.
class AppFailure implements Exception {
  const AppFailure(this.error);

  final AppError error;

  /// Atajo del `kind` del error, para comparar sin conocer el subtipo.
  String get kind => error.kind;

  /// Solo el `kind`. A propósito **no** incluye campos ni mensajes: un registro accidental de la
  /// excepción no puede filtrar datos de la persona.
  @override
  String toString() => 'AppFailure(${error.kind})';
}
