import 'dart:convert';

import 'package:axonote_domain/axonote_domain.dart';

/// Serializa una nota cifrada a JSON (para la tabla `conflicts`, §6: `remote_json`).
String encodeEncryptedNote(EncryptedNote note) => jsonEncode({
  'id': note.id,
  'folderId': note.folderId,
  'createdAt': note.createdAt,
  'updatedAt': note.updatedAt,
  'deletedAt': note.deletedAt,
  'revision': note.revision,
  'lastEditedDeviceId': note.lastEditedDeviceId,
  'wrappedKey': note.wrappedKey,
  'payload': note.payload,
});

EncryptedNote decodeEncryptedNote(String value) {
  final json = jsonDecode(value);
  if (json is! Map<String, Object?>) {
    throw const FormatException('conflicto remoto inválido');
  }
  return EncryptedNote(
    id: json['id']! as String,
    folderId: json['folderId'] as String?,
    createdAt: json['createdAt']! as String,
    updatedAt: json['updatedAt']! as String,
    deletedAt: json['deletedAt'] as String?,
    revision: json['revision']! as int,
    lastEditedDeviceId: json['lastEditedDeviceId']! as String,
    wrappedKey: json['wrappedKey']! as String,
    payload: json['payload']! as String,
  );
}
