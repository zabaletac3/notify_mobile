import '../http_client.dart';
import '../json.dart';
import '../models/misc.dart';
import '../models/sync.dart';
import '../routes.dart';

/// Cliente de lectura de notas cifradas (`/notes`). La escritura va solo por `POST /sync`.
class NotesApi {
  const NotesApi(this._http);

  final HttpClient _http;

  /// Lista notas cifradas, paginadas por cursor.
  Future<EncryptedNotePageDto> list({
    bool? trashed,
    DateTime? updatedSince,
    String? cursor,
    int? limit,
  }) {
    final query = <String, Object?>{
      'trashed': ?trashed,
      if (updatedSince != null)
        'updatedSince': updatedSince.toUtc().toIso8601String(),
      'cursor': ?cursor,
      'limit': ?limit,
    };
    final path = query.isEmpty
        ? ApiRoutes.notes.pathTemplate
        : '${ApiRoutes.notes.pathTemplate}?${Uri(queryParameters: _stringify(query)).query}';
    return _http.request<EncryptedNotePageDto>(
      ApiRoutes.notes.method,
      path,
      decode: EncryptedNotePageDto.fromJson,
    );
  }

  /// Obtiene una nota cifrada.
  Future<EncryptedNoteDto> get(String noteId) {
    return _http.request<EncryptedNoteDto>(
      ApiRoutes.note.method,
      ApiRoutes.note.resolve({'noteId': Uri.encodeComponent(noteId)}),
      decode: EncryptedNoteDto.fromJson,
    );
  }

  static Map<String, String> _stringify(Map<String, Object?> query) => {
    for (final entry in query.entries) entry.key: '${entry.value}',
  };
}

/// Cliente de lectura de carpetas cifradas (`/folders`).
class FoldersApi {
  const FoldersApi(this._http);

  final HttpClient _http;

  /// Lista las carpetas cifradas.
  Future<List<EncryptedFolderDto>> list() {
    return _http.request<List<EncryptedFolderDto>>(
      ApiRoutes.folders.method,
      ApiRoutes.folders.pathTemplate,
      decode: (json) => [
        for (final item in JsonReader(json).asList())
          EncryptedFolderDto.fromJson(item.asMap()),
      ],
    );
  }
}

/// Cliente de los enlaces públicos (`/notes/{noteId}/share` y `/public/notes/{slug}`).
class ShareApi {
  const ShareApi(this._http);

  final HttpClient _http;

  /// Crea el enlace público de solo lectura (o devuelve el existente).
  Future<SharedNoteDto> createLink(String noteId, ShareInputDto input) {
    return _http.request<SharedNoteDto>(
      ApiRoutes.createShare.method,
      ApiRoutes.createShare.resolve({'noteId': Uri.encodeComponent(noteId)}),
      body: input.toJson(),
      decode: SharedNoteDto.fromJson,
    );
  }

  /// Actualiza la copia cifrada del enlace (al editar la nota).
  Future<void> updateLinkPayload(String noteId, String payload) {
    return _http.request<void>(
      ApiRoutes.updateSharePayload.method,
      ApiRoutes.updateSharePayload.resolve({
        'noteId': Uri.encodeComponent(noteId),
      }),
      body: <String, Object?>{'payload': payload},
      decode: (_) {},
    );
  }

  /// Revoca el enlace.
  Future<void> revokeLink(String noteId) {
    return _http.request<void>(
      ApiRoutes.revokeShare.method,
      ApiRoutes.revokeShare.resolve({'noteId': Uri.encodeComponent(noteId)}),
      decode: (_) {},
    );
  }

  /// Enlace público actual, o `null` si no hay.
  Future<SharedNoteDto?> getLink(String noteId) {
    return _http.request<SharedNoteDto?>(
      ApiRoutes.share.method,
      ApiRoutes.share.resolve({'noteId': Uri.encodeComponent(noteId)}),
      decode: (json) => json == null ? null : SharedNoteDto.fromJson(json),
    );
  }

  /// Lee la copia cifrada por la parte pública del enlace (sin sesión).
  Future<PublicNoteDto> readPublic(String slug) {
    return _http.request<PublicNoteDto>(
      ApiRoutes.publicNote.method,
      ApiRoutes.publicNote.resolve({'slug': Uri.encodeComponent(slug)}),
      auth: AuthMode.none,
      decode: PublicNoteDto.fromJson,
    );
  }
}
