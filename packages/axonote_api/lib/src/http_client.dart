import 'dart:async';
import 'dart:convert';

import 'package:axonote_domain/axonote_domain.dart';
import 'package:dio/dio.dart';

import 'json.dart';
import 'routes.dart';
import 'to_failure.dart';
import 'token_store.dart';

/// Cuánta autenticación exige una petición.
enum AuthMode {
  /// Con sesión: exige token de acceso y renueva si venció (por defecto).
  required,

  /// Envía el token si lo hay, pero no falla sin él ni renueva.
  optional,

  /// Ruta pública: no lleva `Authorization`.
  none,
}

/// Opciones del [HttpClient].
class HttpClientOptions {
  const HttpClientOptions({
    required this.baseUrl,
    required this.tokens,
    this.timeout = const Duration(seconds: 30),
    this.cloudflareAccessId,
    this.cloudflareAccessSecret,
    this.dio,
  });

  /// Origen de la API sin barra final, **con** el prefijo `/v1` (§4.5: `API_URL`).
  final String baseUrl;

  /// Almacén de tokens inyectado por la app.
  final TokenStore tokens;

  /// Tiempo máximo de cada petición.
  final Duration timeout;

  /// `CF-Access-Client-Id`: solo se envía si está definido (QA con token de servicio).
  final String? cloudflareAccessId;

  /// `CF-Access-Client-Secret`: solo se envía si está definido.
  final String? cloudflareAccessSecret;

  /// `Dio` ya construido (pruebas). Si falta, el cliente crea el suyo.
  final Dio? dio;
}

/// Cliente HTTP de la API. Añade el token de acceso, renueva la sesión **una sola vez** cuando vence
/// (de vuelo único: una única petición a `/auth/refresh` aunque fallen varias a la vez) y traduce los
/// errores a [AppFailure].
///
/// El móvil usa el modo de sesión **en cuerpo**: el `refreshToken` viaja en el JSON y **nunca** se
/// envía la cabecera `X-AxoNote-Session` (ver §3 del plan y `handler.go` del backend).
///
/// **El vuelo único es por instancia.** Crea **un solo** `HttpClient` por cuenta: dos instancias
/// mantendrían cada una su propia renovación en curso y podrían gastar dos veces el token de
/// renovación (que es de un solo uso), con lo que el servidor cerraría la sesión por reutilización.
/// Quien necesite varios clientes de recurso, que compartan el mismo `HttpClient`.
class HttpClient {
  HttpClient(this.options)
    : _dio = options.dio ?? Dio(),
      _baseUrl = _normalizeBaseUrl(options.baseUrl),
      _timeout = options.timeout {
    _dio.options
      ..baseUrl = _baseUrl
      ..connectTimeout = _timeout
      ..receiveTimeout = _timeout
      ..sendTimeout = _timeout
      ..validateStatus = (_) => true;
  }

  final HttpClientOptions options;
  final Dio _dio;
  final String _baseUrl;
  final Duration _timeout;

  /// Renovación en curso (de vuelo único). Mientras vive, todas las peticiones que reciban
  /// `session-expired` esperan a esta misma operación en vez de lanzar otra.
  Future<String?>? _refreshing;

  /// `true` si hay tokens guardados.
  Future<bool> get hasSession async => (await options.tokens.read()) != null;

  /// Guarda los tokens de una respuesta de inicio de sesión o de renovación. En modo cuerpo hacen
  /// falta los dos; si falta alguno, no se guarda nada (como en la web).
  Future<void> saveTokens({
    required DateTime expiresAt,
    String? accessToken,
    String? refreshToken,
  }) async {
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      return;
    }
    await options.tokens.write(
      StoredTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresAt: expiresAt.toUtc().toIso8601String(),
      ),
    );
  }

  /// Borra los tokens de la sesión actual.
  Future<void> clearSession() => options.tokens.clear();

  static String _normalizeBaseUrl(String baseUrl) {
    if (baseUrl.isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'no puede estar vacío');
    }
    return baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
  }

  /// Ejecuta una petición. [decode] convierte el cuerpo ya deserializado (un `Map` o `List`) en el
  /// DTO correspondiente; si el cuerpo no encaja, se lanza un fallo `server` (fallo de formato).
  Future<T> request<T>(
    String method,
    String path, {
    Object? body,
    AuthMode auth = AuthMode.required,
    T Function(Object? json)? decode,
  }) async {
    final decodeFn = decode ?? (Object? json) => json as T;
    if (auth == AuthMode.none) {
      return _once<T>(method, path, body, null, decodeFn);
    }
    final sent = (await options.tokens.read())?.accessToken;
    if (sent == null) {
      if (auth == AuthMode.optional) {
        return _once<T>(method, path, body, null, decodeFn);
      }
      throw const AppFailure(SessionExpiredError());
    }
    try {
      return await _once<T>(method, path, body, sent, decodeFn);
    } on AppFailure catch (e) {
      // Token de acceso vencido: se renueva una vez y se reintenta (un solo reintento, sin bucles).
      if (auth != AuthMode.optional && e.error is SessionExpiredError) {
        final fresh = await _refresh(sent);
        if (fresh == null) throw const AppFailure(SessionExpiredError());
        return _once<T>(method, path, body, fresh, decodeFn);
      }
      if (e.error is DeviceRevokedError) await options.tokens.clear();
      rethrow;
    }
  }

  Future<T> _once<T>(
    String method,
    String path,
    Object? body,
    String? token,
    T Function(Object? json) decode,
  ) async {
    final response = await _send(method, path, body, token);
    final status = response.statusCode ?? 0;
    final parsed = _parseBody(response.data);
    if (status < 200 || status >= 300) {
      // Con estado de error se decide por el estado, como la web (aunque el cuerpo no sea JSON).
      throw toFailure(
        status,
        parsed.body,
        response.headers.value('retry-after'),
      );
    }
    // 2xx: si el cuerpo no es JSON, o no encaja con el DTO, es un fallo del servidor (no de red).
    if (parsed.parseFailed) throw const AppFailure(ServerError());
    try {
      return decode(parsed.body);
    } on JsonFormatException {
      throw const AppFailure(ServerError());
    } on TypeError {
      // El `decode` por defecto (`json as T`) y cualquier cast de un DTO.
      throw const AppFailure(ServerError());
    }
  }

  /// Interpreta el cuerpo crudo como JSON. Un cuerpo que no es JSON válido se marca con
  /// `parseFailed` (no se lanza aquí: con estado de error manda el estado, y en 2xx lo decide quien
  /// llama). Un cuerpo vacío es `null`.
  ({Object? body, bool parseFailed}) _parseBody(Object? raw) {
    if (raw == null) return (body: null, parseFailed: false);
    if (raw is String) {
      if (raw.isEmpty) return (body: null, parseFailed: false);
      try {
        return (body: jsonDecode(raw), parseFailed: false);
      } on FormatException {
        return (body: null, parseFailed: true);
      }
    }
    return (body: raw, parseFailed: false);
  }

  Future<Response<dynamic>> _send(
    String method,
    String path,
    Object? body,
    String? token,
  ) async {
    // El cuerpo se lee en crudo (`plain`) y se interpreta aquí: así un HTML de Cloudflare Access con
    // 200 no lo intenta parsear dio y no se confunde con un fallo de red.
    final cancelToken = CancelToken();
    final requestOptions = RequestOptions(
      path: path,
      method: method,
      baseUrl: _baseUrl,
      data: body,
      cancelToken: cancelToken,
      headers: <String, Object>{
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        ..._cloudflareHeaders,
      },
      validateStatus: (_) => true,
      responseType: ResponseType.plain,
    );
    final future = _dio.fetch<dynamic>(requestOptions);
    // Si vence el tiempo máximo, se cancela la petición para liberar la conexión; se ignora su
    // resultado tardío.
    future.ignore();
    try {
      return await future.timeout(
        _timeout,
        onTimeout: () {
          cancelToken.cancel('tiempo máximo de la petición');
          throw const AppFailure(NetworkError());
        },
      );
    } on DioException catch (e) {
      final response = e.response;
      // Con `validateStatus` permisivo no debería llegar aquí con respuesta; si llega, se mapea.
      if (response != null) return response;
      throw const AppFailure(NetworkError());
    }
  }

  Map<String, Object> get _cloudflareHeaders {
    final id = options.cloudflareAccessId;
    final secret = options.cloudflareAccessSecret;
    return <String, Object>{
      if (id != null && id.isNotEmpty) 'CF-Access-Client-Id': id,
      if (secret != null && secret.isNotEmpty)
        'CF-Access-Client-Secret': secret,
    };
  }

  /// Renueva la sesión de forma serializada. La primera petición que falla lanza la operación; las
  /// demás se cuelgan de la misma `Future`. El token nuevo se guarda **antes** de devolverlo, así que
  /// el reintento (y cualquier petición posterior) ya lo usa.
  Future<String?> _refresh(String failedAccess) {
    return _refreshing ??= _doRefresh(failedAccess)
        .whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh(String failedAccess) async {
    final current = await options.tokens.read();
    if (current == null) return null;
    // Otra petición (o una pestaña en la web) ya renovó mientras esperábamos: se reutiliza su token
    // en vez de gastar el de renovación, que es de un solo uso.
    if (current.accessToken != failedAccess) return current.accessToken;

    final Response<dynamic> response;
    try {
      response = await _send(
        'POST',
        ApiRoutes.refresh.pathTemplate,
        <String, Object?>{'refreshToken': current.refreshToken},
        null,
      );
    } on AppFailure {
      // Sin red o tiempo máximo: la sesión puede seguir siendo válida; se propaga el fallo tal cual.
      rethrow;
    }

    final status = response.statusCode ?? 0;
    final parsed = _parseBody(response.data);
    if (status < 200 || status >= 300) {
      final failure = toFailure(
        status,
        parsed.body,
        response.headers.value('retry-after'),
      );
      final error = failure.error;
      if (error is NetworkError ||
          error is ServerError ||
          error is RateLimitedError) {
        // Transitorio: la sesión sigue siendo válida; no se borran los tokens.
        throw failure;
      }
      await options.tokens.clear();
      if (error is DeviceRevokedError) throw failure;
      return null;
    }

    final data = parsed.body;
    final map = data is Map
        ? data.cast<String, Object?>()
        : const <String, Object?>{};
    final access = map['accessToken'];
    final refresh = map['refreshToken'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      await options.tokens.clear();
      return null;
    }
    final expiresAt = map['expiresAt'];
    await options.tokens.write(
      StoredTokens(
        accessToken: access,
        refreshToken: refresh,
        expiresAt: expiresAt is String ? expiresAt : '',
      ),
    );
    return access;
  }
}
