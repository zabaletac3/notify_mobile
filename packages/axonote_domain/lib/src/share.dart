import 'ids.dart';

/// Enlace público de solo lectura a una nota, ya reconstruido en el cliente (con su URL completa,
/// que lleva la clave en el fragmento). Referencia: `src/lib/domain/share.ts` de `notify_web`.
class ShareLink {
  const ShareLink({
    required this.id,
    required this.noteId,
    required this.url,
    required this.createdAt,
  });

  final Id id;
  final Id noteId;

  /// URL completa (`<origen>/n/<slug>#k=<clave>`).
  final String url;
  final DateTime createdAt;
}

/// Lo que guarda el servidor de un enlace público.
class SharedNote {
  const SharedNote({
    required this.id,
    required this.noteId,
    required this.slug,
    required this.wrappedShareKey,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
  });

  final Id id;
  final Id noteId;

  /// Parte pública de la URL (16 bytes aleatorios en base64url).
  final String slug;

  /// Clave del enlace, cifrada con la clave maestra del dueño.
  final String wrappedShareKey;

  /// `{ title, content }` rellenado y cifrado con la clave del enlace.
  final String payload;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// Lo que manda el cliente al crear un enlace.
class ShareInput {
  const ShareInput({
    required this.slug,
    required this.wrappedShareKey,
    required this.payload,
  });

  final String slug;
  final String wrappedShareKey;
  final String payload;
}

/// Lo que devuelve el servidor a quien abre el enlace (sin sesión).
class PublicNote {
  const PublicNote({required this.payload, required this.updatedAt});

  final String payload;
  final DateTime updatedAt;
}

/// La nota compartida, ya descifrada, para la página pública.
class SharedNoteContent {
  const SharedNoteContent({
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String title;
  final String content;
  final DateTime updatedAt;
}
