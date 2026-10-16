import '../ids.dart';
import '../share.dart';

/// Enlaces públicos de una nota (`/notes/{noteId}/share` y `/public/notes/{slug}`). Lo implementa
/// `app/lib/data`. Todos los métodos lanzan `AppFailure`.
abstract interface class ShareRepository {
  /// Crea el enlace público de solo lectura (o devuelve el existente).
  Future<SharedNote> createLink(Id noteId, ShareInput input);

  /// Actualiza la copia cifrada del enlace (al editar la nota).
  Future<void> updateLinkPayload(Id noteId, String payload);

  /// Revoca el enlace.
  Future<void> revokeLink(Id noteId);

  /// Enlace público actual, o `null` si no hay.
  Future<SharedNote?> getLink(Id noteId);

  /// Lee la copia cifrada por la parte pública del enlace (sin sesión).
  Future<PublicNote> readPublic(String slug);
}
