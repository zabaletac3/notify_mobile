import 'package:axonote_api/axonote_api.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

import 'support/fake_dio.dart';

HttpClient buildClient(
  FakeAdapter adapter, {
  TokenStore? tokens,
  Duration timeout = const Duration(seconds: 5),
  String? cloudflareAccessId,
  String? cloudflareAccessSecret,
}) {
  return HttpClient(
    HttpClientOptions(
      baseUrl: 'http://localhost:8080/v1',
      tokens: tokens ?? MemoryTokenStore(),
      dio: dioWith(adapter),
      timeout: timeout,
      cloudflareAccessId: cloudflareAccessId,
      cloudflareAccessSecret: cloudflareAccessSecret,
    ),
  );
}

void main() {
  group('cabeceras', () {
    test('una ruta pública no lleva Authorization', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse(200, <String, Object?>{}),
      );
      final client = buildClient(adapter);
      await client.request<void>(
        'POST',
        '/auth/prelogin',
        auth: AuthMode.none,
        body: <String, Object?>{'email': 'persona@example.com'},
        decode: (_) {},
      );
      final headers = adapter.requests.single.headers;
      expect(headers.containsKey('Authorization'), isFalse);
      expect(headers['Accept'], 'application/json');
    });

    test(
      'con sesión envía Bearer y nunca la cabecera de modo cookie',
      () async {
        final adapter = FakeAdapter(
          (_) async => jsonResponse(200, <String, Object?>{}),
        );
        final client = buildClient(
          adapter,
          tokens: await _storeWith('access-1', 'refresh-1'),
        );
        await client.request<void>('GET', '/me', decode: (_) {});
        final headers = adapter.requests.single.headers;
        expect(headers['Authorization'], 'Bearer access-1');
        expect(headers.containsKey('X-AxoNote-Session'), isFalse);
      },
    );

    test('Cloudflare Access solo si está definido', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse(200, <String, Object?>{}),
      );
      final client = buildClient(
        adapter,
        tokens: await _storeWith('a', 'r'),
        cloudflareAccessId: 'id-qa',
        cloudflareAccessSecret: 'secreto-qa',
      );
      await client.request<void>('GET', '/me', decode: (_) {});
      expect(adapter.requests.single.headers['CF-Access-Client-Id'], 'id-qa');
      expect(
        adapter.requests.single.headers['CF-Access-Client-Secret'],
        'secreto-qa',
      );

      final sinCf = FakeAdapter(
        (_) async => jsonResponse(200, <String, Object?>{}),
      );
      await buildClient(
        sinCf,
        tokens: await _storeWith('a', 'r'),
      ).request<void>('GET', '/me', decode: (_) {});
      expect(
        sinCf.requests.single.headers.containsKey('CF-Access-Client-Id'),
        isFalse,
      );
      expect(
        sinCf.requests.single.headers.containsKey('CF-Access-Client-Secret'),
        isFalse,
      );
    });

    test('cuerpo JSON con Content-Type en las escrituras', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse(200, <String, Object?>{}),
      );
      final client = buildClient(adapter);
      await client.request<void>(
        'POST',
        '/auth/prelogin',
        auth: AuthMode.none,
        body: <String, Object?>{'email': 'persona@example.com'},
        decode: (_) {},
      );
      expect(
        adapter.requests.single.headers['Content-Type'],
        contains('application/json'),
      );
      expect(adapter.requests.single.data, <String, Object?>{
        'email': 'persona@example.com',
      });
    });
  });

  group('errores', () {
    test('mapea una respuesta HTTP a AppFailure', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse(422, <String, Object?>{
          'kind': 'validation',
          'fields': <String, Object?>{'email': 'invalid-email'},
        }),
      );
      final client = buildClient(adapter, tokens: await _storeWith('a', 'r'));
      await expectLater(
        client.request<void>('GET', '/me', decode: (_) {}),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.error,
            'error',
            isA<ValidationError>(),
          ),
        ),
      );
    });

    test('un cuerpo válido a nivel HTTP pero mal formado es fallo de formato (server)', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse(200, <String, Object?>{'inesperado': true}),
      );
      final client = buildClient(adapter, tokens: await _storeWith('a', 'r'));
      await expectLater(
        client.request<UserDto>('GET', '/me', decode: UserDto.fromJson),
        throwsA(
          isA<AppFailure>().having((e) => e.error, 'error', isA<ServerError>()),
        ),
      );
    });

    test('sin conexión es network', () async {
      final adapter = FakeAdapter(
        (options) async => throw connectionError(options),
      );
      final client = buildClient(adapter, tokens: await _storeWith('a', 'r'));
      await expectLater(
        client.request<void>('GET', '/me', decode: (_) {}),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.error,
            'error',
            isA<NetworkError>(),
          ),
        ),
      );
    });

    test('el tiempo máximo corta la petición', () async {
      final adapter = FakeAdapter((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return jsonResponse(200, <String, Object?>{});
      });
      final client = buildClient(
        adapter,
        tokens: await _storeWith('a', 'r'),
        timeout: const Duration(milliseconds: 30),
      );
      await expectLater(
        client.request<void>('GET', '/me', decode: (_) {}),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.error,
            'error',
            isA<NetworkError>(),
          ),
        ),
      );
    });

    test('sin tokens y con sesión exigida falla sin enviar nada', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse(200, <String, Object?>{}),
      );
      final client = buildClient(adapter);
      await expectLater(
        client.request<void>('GET', '/me', decode: (_) {}),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.error,
            'error',
            isA<SessionExpiredError>(),
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    });

    test('auth opcional sin tokens no falla ni envía Bearer', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse(200, <String, Object?>{}),
      );
      final client = buildClient(adapter);
      await client.request<void>(
        'GET',
        '/me',
        auth: AuthMode.optional,
        decode: (_) {},
      );
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });

  group('sesión local', () {
    test('saveTokens guarda, hasSession y clearSession borran', () async {
      final store = MemoryTokenStore();
      final client = buildClient(
        FakeAdapter((_) async => jsonResponse(200, <String, Object?>{})),
        tokens: store,
      );
      expect(await client.hasSession, isFalse);
      await client.saveTokens(
        expiresAt: DateTime.utc(2026, 10, 10, 10, 15),
        accessToken: 'a',
        refreshToken: 'r',
      );
      expect(await client.hasSession, isTrue);
      expect((await store.read())!.accessToken, 'a');
      await client.clearSession();
      expect(await client.hasSession, isFalse);
    });

    test('saveTokens no guarda si falta algún token (modo cuerpo)', () async {
      final store = MemoryTokenStore();
      final client = buildClient(
        FakeAdapter((_) async => jsonResponse(200, <String, Object?>{})),
        tokens: store,
      );
      await client.saveTokens(expiresAt: DateTime.utc(2026), accessToken: 'a');
      expect(await store.read(), isNull);
    });
  });

  group('opciones', () {
    test('baseUrl vacío es un error de programación', () {
      expect(
        () => HttpClient(
          HttpClientOptions(baseUrl: '', tokens: MemoryTokenStore()),
        ),
        throwsArgumentError,
      );
    });

    test('normaliza la barra final de baseUrl', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse(200, <String, Object?>{}),
      );
      final client = HttpClient(
        HttpClientOptions(
          baseUrl: 'http://localhost:8080/v1/',
          tokens: MemoryTokenStore(),
          dio: dioWith(adapter),
        ),
      );
      await client.request<void>(
        'POST',
        '/auth/prelogin',
        auth: AuthMode.none,
        body: <String, Object?>{'email': 'persona@example.com'},
        decode: (_) {},
      );
      expect(adapter.requests.single.uri.path, '/v1/auth/prelogin');
    });

    test('sin decodificador devuelve el JSON tal cual', () async {
      final adapter = FakeAdapter(
        (_) async => jsonResponse(200, <String, Object?>{'kdf': 'valor'}),
      );
      final client = buildClient(adapter);
      final json = await client.request<Map<String, Object?>>(
        'POST',
        '/auth/prelogin',
        auth: AuthMode.none,
        body: <String, Object?>{'email': 'persona@example.com'},
      );
      expect(json['kdf'], 'valor');
    });
  });
}

Future<MemoryTokenStore> _storeWith(String access, String refresh) async {
  final store = MemoryTokenStore();
  await store.write(
    StoredTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: '2026-10-10T10:15:00.000Z',
    ),
  );
  return store;
}
