import 'package:axonote_api/axonote_api.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

/// Réplica de `toFailure` de `notify_web/src/lib/data/remote/http-client.ts`: mismas decisiones,
/// mismo `kind` y mismos códigos.
void main() {
  group('toFailure', () {
    test('unauthorized distingue invalid-credentials', () {
      final failure = toFailure(401, <String, Object?>{
        'kind': 'unauthorized',
        'code': 'invalid-credentials',
      }, null);
      expect(failure.error, isA<UnauthorizedError>());
      expect((failure.error as UnauthorizedError).code, 'invalid-credentials');
    });

    test('unauthorized descarta cualquier otro código', () {
      final failure = toFailure(401, <String, Object?>{
        'kind': 'unauthorized',
        'code': 'otro',
      }, null);
      expect((failure.error as UnauthorizedError).code, isNull);
    });

    test('forbidden conserva solo los cuatro códigos de la web', () {
      expect(
        (toFailure(403, <String, Object?>{
                  'kind': 'forbidden',
                  'code': 'email-not-verified',
                }, null).error
                as ForbiddenError)
            .code,
        ForbiddenCode.emailNotVerified,
      );
      expect(
        (toFailure(403, <String, Object?>{
                  'kind': 'forbidden',
                  'code': 'account-deleted',
                }, null).error
                as ForbiddenError)
            .code,
        ForbiddenCode.accountDeleted,
      );
      // `limit-reached` y `google-not-linked` los descarta `toFailure` en la web: misma paridad.
      expect(
        (toFailure(403, <String, Object?>{
                  'kind': 'forbidden',
                  'code': 'limit-reached',
                }, null).error
                as ForbiddenError)
            .code,
        isNull,
      );
      expect(
        (toFailure(403, <String, Object?>{
                  'kind': 'forbidden',
                  'code': 'google-not-linked',
                }, null).error
                as ForbiddenError)
            .code,
        isNull,
      );
    });

    test('session-expired y device-revoked', () {
      expect(
        toFailure(401, <String, Object?>{
          'kind': 'session-expired',
        }, null).error,
        isA<SessionExpiredError>(),
      );
      expect(
        toFailure(401, <String, Object?>{'kind': 'device-revoked'}, null).error,
        isA<DeviceRevokedError>(),
      );
    });

    test('not-found lleva la entidad', () {
      final failure = toFailure(404, <String, Object?>{
        'kind': 'not-found',
        'entity': 'device',
      }, null);
      expect((failure.error as NotFoundError).entity, 'device');
    });

    test('validation lleva los campos', () {
      final failure = toFailure(422, <String, Object?>{
        'kind': 'validation',
        'fields': <String, Object?>{'email': 'invalid-email'},
      }, null);
      expect((failure.error as ValidationError).fields, <String, String>{
        'email': 'invalid-email',
      });
    });

    test('conflict lleva nota y código', () {
      final failure = toFailure(409, <String, Object?>{
        'kind': 'conflict',
        'noteId': 'n_1',
        'code': 'mfa-not-enabled',
      }, null);
      final error = failure.error as ConflictError;
      expect(error.noteId, 'n_1');
      expect(error.code, 'mfa-not-enabled');
    });

    test(
      'rate-limited usa retryAfterSec del cuerpo y, si falta, la cabecera',
      () {
        expect(
          (toFailure(429, <String, Object?>{
                    'kind': 'rate-limited',
                    'retryAfterSec': 30,
                  }, null).error
                  as RateLimitedError)
              .retryAfterSec,
          30,
        );
        expect(
          (toFailure(429, <String, Object?>{'kind': 'rate-limited'}, '12').error
                  as RateLimitedError)
              .retryAfterSec,
          12,
        );
        // Cabecera 0 no aporta dato (la web la descarta también).
        expect(
          (toFailure(429, <String, Object?>{'kind': 'rate-limited'}, '0').error
                  as RateLimitedError)
              .retryAfterSec,
          isNull,
        );
      },
    );

    test('cae al estado HTTP cuando el cuerpo no es reconocible', () {
      expect(toFailure(429, null, null).error, isA<RateLimitedError>());
      expect(toFailure(401, null, null).error, isA<SessionExpiredError>());
      expect((toFailure(500, null, null).error as ServerError).status, 500);
      expect(toFailure(502, 'texto plano', null).error, isA<ServerError>());
    });

    test('un kind desconocido se decide por el estado', () {
      expect(
        (toFailure(503, <String, Object?>{'kind': 'raro'}, null).error
                as ServerError)
            .status,
        503,
      );
    });
  });
}
