import 'package:axonote_crypto/axonote_crypto.dart' hide DecryptError;
import 'package:axonote_domain/axonote_domain.dart';

import 'vault.dart';

/// Cifrado de los enlaces públicos sobre el [Vault] de la sesión. Portado de
/// `notify_web/src/lib/data/crypto/share-codec.ts`. La clave del enlace se envuelve con la clave
/// maestra (`Vault.requireKey()`): es el único uso previsto de la maestra fuera de las claves de
/// item, igual que hace la web con `vault.requireKey()` (plan §5.1, decisión en `docs/decisions.md`).

/// Prepara un enlace nuevo: clave propia, copia cifrada y la clave envuelta con la maestra.
Future<ShareInput> createShare(
  Vault vault, {
  required Id noteId,
  required String title,
  required String content,
}) async {
  final slug = newSlug();
  final shareKey = generateKeyBytes();
  return ShareInput(
    slug: slug,
    payload: await sealSharedNote(
      shareKey,
      slug,
      title: title,
      content: content,
    ),
    wrappedShareKey: await wrap(
      vault.requireKey(),
      shareKey,
      shareKeyAad(vault.userId, noteId),
    ),
  );
}

/// Cifra la copia pública (solo título y texto) con la clave del enlace.
Future<Sealed> sealSharedNote(
  SecretKeyBytes shareKey,
  String slug, {
  required String title,
  required String content,
}) => sealLinkPayload(
  shareKey,
  slug,
  LinkPayload(title: title, content: content),
);

/// La clave de un enlace ya creado, para actualizar la copia o reconstruir la URL.
Future<SecretKeyBytes> openShareKey(Vault vault, SharedNote shared) => unwrap(
  vault.requireKey(),
  shared.wrappedShareKey,
  shareKeyAad(vault.userId, shared.noteId),
);

/// La URL que se comparte: la clave va en el fragmento, que el navegador no envía al servidor.
String shareUrl(String origin, SharedNote shared, SecretKeyBytes shareKey) =>
    '$origin/n/${shared.slug}#k=${exportKeyRaw(shareKey)}';

/// Lee una nota compartida con la clave del fragmento (`#k=…` o `k=…`). Lanza [DecryptError] o
/// [CryptoFormatError] si la clave no corresponde al enlace o el contenido no es válido.
Future<SharedNoteContent> openSharedNote(
  String slug,
  String keyFragment,
  String payload,
  DateTime updatedAt,
) async {
  final raw = shareKeyFromFragment(keyFragment);
  if (raw == null) throw const CryptoFormatError('fragmento inválido');
  final link = await openLinkPayload(importKeyRaw(raw), slug, payload);
  return SharedNoteContent(
    title: link.title,
    content: link.content,
    updatedAt: updatedAt,
  );
}
