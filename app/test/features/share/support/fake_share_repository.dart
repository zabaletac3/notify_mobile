import 'package:axonote_domain/axonote_domain.dart';

/// Repositorio de enlaces falso: guarda en memoria, sin red. Registra las llamadas.
class FakeShareRepository implements ShareRepository {
  final Map<Id, SharedNote> links = {};
  final List<String> updatedPayloads = [];
  final List<Id> revoked = [];
  PublicNote? publicNote;
  AppError? error;
  int _seq = 0;

  @override
  Future<SharedNote> createLink(Id noteId, ShareInput input) async {
    if (error != null) throw AppFailure(error!);
    final now = DateTime.utc(2026, 10, 15, 9);
    final stored = SharedNote(
      id: 'share_${_seq++}',
      noteId: noteId,
      slug: input.slug,
      wrappedShareKey: input.wrappedShareKey,
      payload: input.payload,
      createdAt: now,
      updatedAt: now,
    );
    links[noteId] = stored;
    return stored;
  }

  @override
  Future<void> updateLinkPayload(Id noteId, String payload) async {
    if (error != null) throw AppFailure(error!);
    updatedPayloads.add(payload);
    final current = links[noteId];
    if (current != null) {
      links[noteId] = SharedNote(
        id: current.id,
        noteId: current.noteId,
        slug: current.slug,
        wrappedShareKey: current.wrappedShareKey,
        payload: payload,
        createdAt: current.createdAt,
        updatedAt: DateTime.utc(2026, 10, 15, 10),
      );
    }
  }

  @override
  Future<void> revokeLink(Id noteId) async {
    if (error != null) throw AppFailure(error!);
    revoked.add(noteId);
    links.remove(noteId);
  }

  @override
  Future<SharedNote?> getLink(Id noteId) async {
    if (error != null) throw AppFailure(error!);
    return links[noteId];
  }

  @override
  Future<PublicNote> readPublic(String slug) async {
    if (error != null) throw AppFailure(error!);
    return publicNote ??
        PublicNote(payload: '', updatedAt: DateTime.utc(2026, 10, 15, 9));
  }
}
