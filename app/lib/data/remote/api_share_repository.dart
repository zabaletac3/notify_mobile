import 'package:axonote_api/axonote_api.dart' as api;
import 'package:axonote_domain/axonote_domain.dart';

/// Implementación de [ShareRepository] sobre `axonote_api` (plan §4.2: nadie fuera de
/// `app/lib/data` importa `dio`).
class ApiShareRepository implements ShareRepository {
  ApiShareRepository(api.HttpClient http) : _api = api.ShareApi(http);

  final api.ShareApi _api;

  @override
  Future<SharedNote> createLink(Id noteId, ShareInput input) async {
    final dto = await _api.createLink(
      noteId,
      api.ShareInputDto(
        slug: input.slug,
        wrappedShareKey: input.wrappedShareKey,
        payload: input.payload,
      ),
    );
    return _fromDto(dto);
  }

  @override
  Future<void> updateLinkPayload(Id noteId, String payload) =>
      _api.updateLinkPayload(noteId, payload);

  @override
  Future<void> revokeLink(Id noteId) => _api.revokeLink(noteId);

  @override
  Future<SharedNote?> getLink(Id noteId) async {
    final dto = await _api.getLink(noteId);
    return dto == null ? null : _fromDto(dto);
  }

  @override
  Future<PublicNote> readPublic(String slug) async {
    final dto = await _api.readPublic(slug);
    return PublicNote(payload: dto.payload, updatedAt: dto.updatedAt);
  }

  static SharedNote _fromDto(api.SharedNoteDto dto) => SharedNote(
    id: dto.id,
    noteId: dto.noteId,
    slug: dto.slug,
    wrappedShareKey: dto.wrappedShareKey,
    payload: dto.payload,
    createdAt: dto.createdAt,
    updatedAt: dto.updatedAt,
  );
}
