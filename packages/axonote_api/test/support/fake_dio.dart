import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adaptador de dio guionizado para las pruebas: cada petición la responde [handler] y queda
/// registrada en [requests] (con método, ruta, cabeceras y cuerpo) para poder comprobarla.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  /// Todas las peticiones recibidas, en orden.
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

/// Respuesta JSON con estado [status].
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

/// Respuesta sin cuerpo (p. ej. 204).
ResponseBody emptyResponse(int status) {
  return ResponseBody.fromString('', status);
}

/// `Dio` con el adaptador guionizado ya montado.
Dio dioWith(FakeAdapter adapter) {
  return Dio()..httpClientAdapter = adapter;
}

/// Error de conexión, como el que lanza dio cuando no hay red.
DioException connectionError(RequestOptions options) {
  return DioException.connectionError(
    requestOptions: options,
    reason: 'sin conexión',
  );
}
