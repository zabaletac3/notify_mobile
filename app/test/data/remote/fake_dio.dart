import 'dart:convert';
import 'dart:typed_data';

import 'package:axonote_api/axonote_api.dart';
import 'package:dio/dio.dart';

/// Adaptador de dio guionizado para las pruebas (copia mínima de
/// `packages/axonote_api/test/support/fake_dio.dart`: ese archivo vive en `test/` y no se puede
/// importar desde `app/test`). Cada petición la responde [handler] y queda registrada en
/// [requests] para poder comprobarla.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  int status,
  Object? body, {
  Map<String, List<String>> headers = const {},
}) {
  return ResponseBody.fromString(
    body == null ? '' : jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: const ['application/json'],
      ...headers,
    },
  );
}

Dio dioWith(FakeAdapter adapter) => Dio()..httpClientAdapter = adapter;

/// `SyncApi` con una sesión ya guardada (token de acceso que no vence) y el adaptador
/// guionizado [adapter], para probar `RemoteSyncTransport` sin red real.
Future<SyncApi> apiWith(FakeAdapter adapter) async {
  final tokens = MemoryTokenStore();
  await tokens.write(
    const StoredTokens(
      accessToken: 'at',
      refreshToken: 'rt',
      expiresAt: '2099-01-01T00:00:00.000Z',
    ),
  );
  final http = HttpClient(
    HttpClientOptions(
      baseUrl: 'http://localhost:8080/v1',
      tokens: tokens,
      dio: dioWith(adapter),
    ),
  );
  return SyncApi(http);
}
