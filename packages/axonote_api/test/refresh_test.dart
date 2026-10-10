import 'package:axonote_api/axonote_api.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

import 'support/fake_dio.dart';

const String _oldAccess = 'access-old';
const String _oldRefresh = 'refresh-old';
const String _newAccess = 'access-new';
const String _newRefresh = 'refresh-new';

Map<String, Object?> _userJson() => <String, Object?>{
  'id': 'u_1',
  'email': 'persona@example.com',
  'fullName': 'Persona',
  'emailVerified': true,
  'hasGoogle': false,
  'createdAt': '2026-10-10T10:00:00.000Z',
};

Map<String, Object?> _refreshJson() => <String, Object?>{
  'accessToken': _newAccess,
  'refreshToken': _newRefresh,
  'expiresAt': '2026-10-10T10:30:00.000Z',
};

MemoryTokenStore _store() {
  final store = MemoryTokenStore();
  store.write(
    const StoredTokens(
      accessToken: _oldAccess,
      refreshToken: _oldRefresh,
      expiresAt: '2026-10-10T10:15:00.000Z',
    ),
  );
  return store;
}

HttpClient _client(FakeAdapter adapter, TokenStore store) => HttpClient(
  HttpClientOptions(
    baseUrl: 'http://localhost:8080/v1',
    tokens: store,
    dio: dioWith(adapter),
  ),
);

Future<UserDto> _me(HttpClient client) =>
    client.request<UserDto>('GET', '/me', decode: UserDto.fromJson);

void main() {
  group('renovación de vuelo único', () {
    test(
      'N peticiones concurrentes con 401 -> exactamente 1 refresh',
      () async {
        var refreshes = 0;
        final store = _store();
        var storeHadNewBeforeRetry = false;
        final adapter = FakeAdapter((options) async {
          switch (options.uri.path) {
            case '/v1/auth/refresh':
              refreshes++;
              final body = options.data as Map?;
              expect(body?['refreshToken'], _oldRefresh);
              return jsonResponse(200, _refreshJson());
            case '/v1/me':
              final auth = options.headers['Authorization'];
              if (auth == 'Bearer $_oldAccess') {
                return jsonResponse(401, <String, Object?>{
                  'kind': 'session-expired',
                });
              }
              if (auth == 'Bearer $_newAccess') {
                storeHadNewBeforeRetry =
                    (await store.read())?.accessToken == _newAccess;
                return jsonResponse(200, _userJson());
              }
              return jsonResponse(500, <String, Object?>{'kind': 'server'});
            default:
              return jsonResponse(404, <String, Object?>{'kind': 'not-found'});
          }
        });
        final client = _client(adapter, store);

        final users = await Future.wait(<Future<UserDto>>[
          for (var i = 0; i < 6; i++) _me(client),
        ]);

        expect(users.every((user) => user.id == 'u_1'), isTrue);
        expect(refreshes, 1, reason: 'solo una petición a /auth/refresh');
        expect(
          storeHadNewBeforeRetry,
          isTrue,
          reason: 'el token nuevo se persiste antes de reintentar',
        );
        expect((await store.read())!.refreshToken, _newRefresh);
      },
    );

    test(
      'refresh fallido: todas las pendientes fallan con session-expired',
      () async {
        var refreshes = 0;
        final store = _store();
        final adapter = FakeAdapter((options) async {
          if (options.uri.path == '/v1/auth/refresh') {
            refreshes++;
            return jsonResponse(401, <String, Object?>{
              'kind': 'session-expired',
            });
          }
          return jsonResponse(401, <String, Object?>{
            'kind': 'session-expired',
          });
        });
        final client = _client(adapter, store);

        var failures = 0;
        await Future.wait(<Future<void>>[
          for (var i = 0; i < 5; i++)
            _me(client).then(
              (_) => fail('no debería resolver'),
              onError: (Object error) {
                expect(error, isA<AppFailure>());
                expect((error as AppFailure).error, isA<SessionExpiredError>());
                failures++;
              },
            ),
        ]);

        expect(failures, 5);
        expect(refreshes, 1);
        expect(await store.read(), isNull, reason: 'se borran los tokens');
      },
    );

    test('un solo reintento: si el reintento vuelve a fallar, no hay segundo refresh', () async {
      var refreshes = 0;
      final store = _store();
      final adapter = FakeAdapter((options) async {
        if (options.uri.path == '/v1/auth/refresh') {
          refreshes++;
          return jsonResponse(200, _refreshJson());
        }
        // Tanto con el token viejo como con el nuevo: 401.
        return jsonResponse(401, <String, Object?>{'kind': 'session-expired'});
      });
      final client = _client(adapter, store);

      await expectLater(
        _me(client),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.error,
            'error',
            isA<SessionExpiredError>(),
          ),
        ),
      );
      expect(refreshes, 1);
    });

    test(
      'device-revoked en el refresh se propaga y limpia la sesión',
      () async {
        var refreshes = 0;
        final store = _store();
        final adapter = FakeAdapter((options) async {
          if (options.uri.path == '/v1/auth/refresh') {
            refreshes++;
            return jsonResponse(401, <String, Object?>{
              'kind': 'device-revoked',
            });
          }
          return jsonResponse(401, <String, Object?>{
            'kind': 'session-expired',
          });
        });
        final client = _client(adapter, store);

        await expectLater(
          _me(client),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.error,
              'error',
              isA<DeviceRevokedError>(),
            ),
          ),
        );
        expect(refreshes, 1);
        expect(await store.read(), isNull);
      },
    );

    test('device-revoked en una petición normal no dispara refresh', () async {
      var refreshes = 0;
      final store = _store();
      final adapter = FakeAdapter((options) async {
        if (options.uri.path == '/v1/auth/refresh') {
          refreshes++;
          return jsonResponse(500, <String, Object?>{});
        }
        return jsonResponse(401, <String, Object?>{'kind': 'device-revoked'});
      });
      final client = _client(adapter, store);

      await expectLater(
        _me(client),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.error,
            'error',
            isA<DeviceRevokedError>(),
          ),
        ),
      );
      expect(refreshes, 0);
      expect(await store.read(), isNull);
    });

    test(
      'un fallo de red al renovar se propaga sin borrar los tokens',
      () async {
        var refreshes = 0;
        final store = _store();
        final adapter = FakeAdapter((options) async {
          if (options.uri.path == '/v1/auth/refresh') {
            refreshes++;
            throw connectionError(options);
          }
          return jsonResponse(401, <String, Object?>{
            'kind': 'session-expired',
          });
        });
        final client = _client(adapter, store);

        await expectLater(
          _me(client),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.error,
              'error',
              isA<NetworkError>(),
            ),
          ),
        );
        expect(refreshes, 1);
        expect(
          (await store.read())!.accessToken,
          _oldAccess,
          reason: 'sin red la sesión sigue siendo válida',
        );
      },
    );

    test(
      'un refresh sin tokens en el cuerpo es sesión expirada y limpia',
      () async {
        var refreshes = 0;
        final store = _store();
        final adapter = FakeAdapter((options) async {
          if (options.uri.path == '/v1/auth/refresh') {
            refreshes++;
            return jsonResponse(200, <String, Object?>{});
          }
          return jsonResponse(401, <String, Object?>{
            'kind': 'session-expired',
          });
        });
        final client = _client(adapter, store);

        await expectLater(
          _me(client),
          throwsA(
            isA<AppFailure>().having(
              (e) => e.error,
              'error',
              isA<SessionExpiredError>(),
            ),
          ),
        );
        expect(refreshes, 1);
        expect(await store.read(), isNull);
      },
    );
  });
}
