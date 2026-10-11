import 'dart:async';
import 'dart:io';

import 'package:axonote_api/axonote_api.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'support/fake_dio.dart';

/// El paquete nunca registra nada: ni cuerpos, ni cabeceras, ni tokens. Se comprueba de tres formas:
/// análisis estático del código, captura de `print` en el flujo real y revisión de los `toString` y
/// de los interceptores de dio.
void main() {
  test('el código no usa ninguna API de registro', () {
    final forbidden = <RegExp>[
      RegExp(r'\b(print|debugPrint)\s*\('),
      RegExp(r'\bLogInterceptor\b'),
      RegExp(r'\bdeveloper\s*\.\s*log\b'),
      RegExp(r"""['"]dart:(developer|io)['"]"""),
    ];
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final pattern in forbidden) {
        if (pattern.hasMatch(content)) {
          offenders.add('${entity.path}: ${pattern.pattern}');
        }
      }
    }
    expect(offenders, isEmpty);
  });

  test('el flujo real no imprime nada (print capturado por zona)', () async {
    final captured = <String>[];
    final store = MemoryTokenStore();
    await store.write(
      const StoredTokens(
        accessToken: 'token-secreto',
        refreshToken: 'renovacion-secreta',
        expiresAt: '2026-10-10T10:15:00.000Z',
      ),
    );
    final adapter = FakeAdapter((options) async {
      if (options.uri.path == '/v1/auth/refresh') {
        return jsonResponse(200, <String, Object?>{
          'accessToken': 'nuevo-token',
          'refreshToken': 'nueva-renovacion',
          'expiresAt': '2026-10-10T10:30:00.000Z',
        });
      }
      final auth = options.headers['Authorization'];
      if (auth == 'Bearer token-secreto') {
        return jsonResponse(401, <String, Object?>{'kind': 'session-expired'});
      }
      return jsonResponse(200, <String, Object?>{
        'id': 'u_1',
        'email': 'persona@example.com',
        'fullName': 'Persona',
        'emailVerified': true,
        'hasGoogle': false,
        'createdAt': '2026-10-10T10:00:00.000Z',
      });
    });
    final client = HttpClient(
      HttpClientOptions(
        baseUrl: 'http://localhost:8080/v1',
        tokens: store,
        dio: dioWith(adapter),
      ),
    );

    await runZoned(
      () async {
        await client.request<UserDto>('GET', '/me', decode: UserDto.fromJson);
      },
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, String line) => captured.add(line),
      ),
    );

    expect(captured, isEmpty, reason: 'nada debe salir por print');
  });

  test('el cliente no añade interceptores de registro a dio', () async {
    final adapter = FakeAdapter(
      (_) async => jsonResponse(200, <String, Object?>{}),
    );
    final dio = dioWith(adapter);
    final propio = _CountingInterceptor();
    dio.interceptors.add(propio);
    final antes = List<Interceptor>.of(dio.interceptors);
    final client = HttpClient(
      HttpClientOptions(
        baseUrl: 'http://localhost:8080/v1',
        tokens: MemoryTokenStore(),
        dio: dio,
      ),
    );
    await client.request<void>(
      'POST',
      '/auth/prelogin',
      auth: AuthMode.none,
      body: <String, Object?>{'email': 'persona@example.com'},
      decode: (_) {},
    );
    expect(dio.interceptors.toList(), antes, reason: 'no añade interceptores');
    expect(dio.interceptors.whereType<LogInterceptor>(), isEmpty);
    expect(propio.calls, greaterThan(0));
  });

  test('toString no filtra datos sensibles', () {
    expect(const AppFailure(ServerError()).toString(), 'AppFailure(server)');
    final failure = toFailure(422, <String, Object?>{
      'kind': 'validation',
      'fields': <String, Object?>{'x': 'SECRETO-abc123'},
    }, null);
    expect(failure.toString(), isNot(contains('SECRETO')));
    expect(failure.toString(), 'AppFailure(validation)');
  });

  test('la excepción de formato no incluye el valor', () {
    // `createdAt` con un valor que parece un secreto: la excepción solo nombra la ruta.
    try {
      UserDto.fromJson(<String, Object?>{
        'id': 'u_1',
        'email': 'persona@example.com',
        'fullName': 'Persona',
        'emailVerified': true,
        'hasGoogle': false,
        'createdAt': 'TOKEN-SECRETO-xyz',
      });
      fail('debería lanzar');
    } on JsonFormatException catch (e) {
      expect(e.toString(), isNot(contains('TOKEN-SECRETO')));
      expect(e.path, contains('createdAt'));
    }
  });
}

class _CountingInterceptor extends Interceptor {
  int calls = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    calls++;
    handler.next(options);
  }
}
