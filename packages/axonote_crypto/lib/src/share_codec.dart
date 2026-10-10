// Cifrado de los enlaces públicos. La copia de la nota se cifra con una clave propia del enlace;
// esa clave va en el fragmento de la URL (que no llega al servidor) y, cifrada con la clave
// maestra, en el servidor para que el dueño pueda reconstruir el enlace. Construir la URL en sí
// (origen + ruta) no es cosa de este paquete: depende de `SHARE_ORIGIN` (plan §4.5), que es
// configuración de la app.

import 'dart:convert';
import 'dart:typed_data';

import 'bytes.dart';
import 'padding.dart';
import 'sealed.dart';

/// Lo que va dentro del texto cifrado de un enlace público: solo título y texto (ni etiquetas ni
/// carpeta).
class LinkPayload {
  const LinkPayload({required this.title, required this.content});

  final String title;
  final String content;
}

const int slugBytes = 16;

final RegExp _slugPattern = RegExp(r'^[A-Za-z0-9_-]{22}$');
final RegExp _keyFragmentPattern = RegExp(r'^#?k=([A-Za-z0-9_-]{43})$');

bool isValidSlug(String slug) => _slugPattern.hasMatch(slug);

String newSlug() => toB64u(randomBytes(slugBytes));

/// Datos asociados de la copia cifrada: la ligan a la parte pública de la URL que se comparte.
String shareContentAad(String slug) => 'apunte/v1/share/$slug';

/// Datos asociados de la clave del enlace, ligada a la cuenta y a la nota.
String shareKeyAad(String userId, String noteId) =>
    'apunte/v1/sharekey/$userId/$noteId';

Uint8List encodeLinkPayload(LinkPayload payload) => pad(
  utf8Encode(jsonEncode({'title': payload.title, 'content': payload.content})),
);

LinkPayload decodeLinkPayload(Uint8List bytes) {
  Object? value;
  try {
    value = jsonDecode(unpadJson(bytes));
  } on FormatException {
    throw const DecryptError();
  }
  if (value is! Map<String, Object?>) throw const DecryptError();
  final title = value['title'];
  final content = value['content'];
  if (title is! String || content is! String) throw const DecryptError();
  return LinkPayload(title: title, content: content);
}

/// Cifra la copia compartida (solo título y texto; ni etiquetas ni carpeta).
Future<Sealed> sealLinkPayload(
  SecretKeyBytes shareKey,
  String slug,
  LinkPayload payload,
) => seal(shareKey, encodeLinkPayload(payload), shareContentAad(slug));

/// Lanza [DecryptError] o [CryptoFormatError] si la clave no corresponde al enlace o el
/// contenido no es válido.
Future<LinkPayload> openLinkPayload(
  SecretKeyBytes shareKey,
  String slug,
  Sealed payload,
) async {
  final bytes = await open(shareKey, payload, shareContentAad(slug));
  return decodeLinkPayload(bytes);
}

/// Saca la clave del fragmento de una URL (`#k=…`), o `null` si no hay o está mal formada.
String? shareKeyFromFragment(String fragment) =>
    _keyFragmentPattern.firstMatch(fragment)?.group(1);
