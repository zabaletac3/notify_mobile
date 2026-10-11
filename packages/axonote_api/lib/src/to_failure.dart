import 'package:axonote_domain/axonote_domain.dart';

/// Códigos de `forbidden` que la interfaz distingue, **idénticos** a `FORBIDDEN_CODES` de
/// `notify_web/src/lib/data/remote/http-client.ts`. El resto se trata como un 403 genérico (la web
/// también descarta `google-not-linked` y `limit-reached` en `toFailure`).
const Set<String> _forbiddenCodes = {
  'email-not-verified',
  'google-disabled',
  'google-email-unverified',
  'account-deleted',
};

ForbiddenCode? _forbiddenCode(Object? value) {
  if (value is! String || !_forbiddenCodes.contains(value)) return null;
  for (final code in ForbiddenCode.values) {
    if (code.wire == value) return code;
  }
  return null;
}

/// Convierte la respuesta de error de la API (forma `AppError`) en un [AppFailure]. Réplica de
/// `toFailure` de `http-client.ts`: mismos `kind`, mismos códigos, misma decisión por estado HTTP
/// cuando el cuerpo no es reconocible.
AppFailure toFailure(int status, Object? body, String? retryAfterHeader) {
  final map = body is Map
      ? body.cast<String, Object?>()
      : const <String, Object?>{};
  final retry = _retryAfterSec(map, retryAfterHeader);
  switch (map['kind']) {
    case 'unauthorized':
      return AppFailure(
        UnauthorizedError(
          code: map['code'] == 'invalid-credentials'
              ? 'invalid-credentials'
              : null,
        ),
      );
    case 'forbidden':
      return AppFailure(ForbiddenError(code: _forbiddenCode(map['code'])));
    case 'session-expired':
      return const AppFailure(SessionExpiredError());
    case 'device-revoked':
      return const AppFailure(DeviceRevokedError());
    case 'not-found':
      return AppFailure(NotFoundError(entity: _asString(map['entity'])));
    case 'validation':
      return AppFailure(ValidationError(_fields(map['fields'])));
    case 'conflict':
      return AppFailure(
        ConflictError(
          noteId: _asString(map['noteId']),
          code: _asString(map['code']),
        ),
      );
    case 'rate-limited':
      return AppFailure(RateLimitedError(retryAfterSec: retry));
    default:
      // Sin cuerpo reconocible: se decide por el estado HTTP. Nunca se muestra el texto del servidor.
      if (status == 429) {
        return AppFailure(RateLimitedError(retryAfterSec: retry));
      }
      if (status == 401) return const AppFailure(SessionExpiredError());
      return AppFailure(ServerError(status: status));
  }
}

int? _retryAfterSec(Map<String, Object?> body, String? header) {
  final value = body['retryAfterSec'];
  if (value is int) return value;
  if (header != null) {
    final parsed = int.tryParse(header);
    if (parsed != null && parsed != 0) return parsed;
  }
  return null;
}

String? _asString(Object? value) => value is String ? value : null;

Map<String, String> _fields(Object? value) {
  if (value is! Map) return const {};
  return {for (final entry in value.entries) '${entry.key}': '${entry.value}'};
}
