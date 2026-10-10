import 'dart:convert';
import 'dart:typed_data';

import 'bytes.dart';
import 'padding.dart';
import 'sealed.dart';

/// Lo que va dentro del texto cifrado de una nota.
class NotePayload {
  const NotePayload({
    required this.title,
    required this.content,
    required this.tags,
    required this.pinned,
  });

  final String title;
  final String content;
  final List<String> tags;
  final bool pinned;
}

/// Lo que va dentro del texto cifrado de una carpeta.
class FolderPayload {
  const FolderPayload({required this.name});

  final String name;
}

/// Serializa y rellena el contenido de una nota tal y como se cifra: JSON
/// `{title, content, tags, pinned}` (en ese orden) rellenado a múltiplos de 256. Es la forma
/// canónica del `payload`.
Uint8List encodeNotePayload(NotePayload payload) => pad(
  utf8Encode(
    jsonEncode({
      'title': payload.title,
      'content': payload.content,
      'tags': payload.tags,
      'pinned': payload.pinned,
    }),
  ),
);

/// Lanza [DecryptError] si el JSON no tiene la forma esperada; nunca acepta un payload a medias.
NotePayload decodeNotePayload(Uint8List bytes) {
  Object? value;
  try {
    value = jsonDecode(unpadJson(bytes));
  } on FormatException {
    throw const DecryptError();
  }
  if (value is! Map<String, Object?>) throw const DecryptError();
  final title = value['title'];
  final content = value['content'];
  final tags = value['tags'];
  final pinned = value['pinned'];
  if (title is! String ||
      content is! String ||
      pinned is! bool ||
      tags is! List ||
      tags.any((tag) => tag is! String)) {
    throw const DecryptError();
  }
  return NotePayload(title: title, content: content, tags: tags.cast<String>(), pinned: pinned);
}

/// Serializa y rellena el nombre de una carpeta: JSON `{name}` rellenado a múltiplos de 256.
Uint8List encodeFolderPayload(FolderPayload payload) =>
    pad(utf8Encode(jsonEncode({'name': payload.name})));

FolderPayload decodeFolderPayload(Uint8List bytes) {
  Object? value;
  try {
    value = jsonDecode(unpadJson(bytes));
  } on FormatException {
    throw const DecryptError();
  }
  if (value is! Map<String, Object?> || value['name'] is! String) throw const DecryptError();
  return FolderPayload(name: value['name']! as String);
}

/// Cifra el contenido de una nota con la clave del elemento ya repartida (ver [wrap]/[unwrap]
/// para obtenerla a partir de la clave maestra).
Future<Sealed> sealNotePayload(SecretKeyBytes itemKey, NotePayload payload, String aad) =>
    seal(itemKey, encodeNotePayload(payload), aad);

/// Lanza [DecryptError] o [CryptoFormatError] si la clave, el AAD o el texto no corresponden.
Future<NotePayload> openNotePayload(SecretKeyBytes itemKey, Sealed payload, String aad) async {
  final bytes = await open(itemKey, payload, aad);
  return decodeNotePayload(bytes);
}

Future<Sealed> sealFolderPayload(SecretKeyBytes itemKey, FolderPayload payload, String aad) =>
    seal(itemKey, encodeFolderPayload(payload), aad);

Future<FolderPayload> openFolderPayload(SecretKeyBytes itemKey, Sealed payload, String aad) async {
  final bytes = await open(itemKey, payload, aad);
  return decodeFolderPayload(bytes);
}
