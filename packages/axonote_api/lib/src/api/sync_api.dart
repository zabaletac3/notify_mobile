import '../http_client.dart';
import '../models/sync.dart';
import '../routes.dart';

/// Cliente del canal de sincronización (`POST /sync`): única vía de escritura de notas y carpetas.
class SyncApi {
  const SyncApi(this._http);

  final HttpClient _http;

  /// Sube los cambios locales y baja los remotos.
  Future<SyncResponseDto> sync(SyncRequestDto request) {
    return _http.request<SyncResponseDto>(
      ApiRoutes.sync.method,
      ApiRoutes.sync.pathTemplate,
      body: request.toJson(),
      decode: SyncResponseDto.fromJson,
    );
  }
}
