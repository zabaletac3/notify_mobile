import 'dart:convert';

import 'package:axonote_domain/axonote_domain.dart';

/// Fila de `notes`: contenido en claro dentro de la base cifrada, más la clave del elemento y los
/// datos de sincronización. Se corresponde uno a uno con las columnas de la §6.
class NoteRow {
  const NoteRow({
    required this.id,
    required this.folderId,
    required this.title,
    required this.content,
    required this.preview,
    required this.tagsJson,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.revision,
    required this.syncStatus,
    required this.lastEditedDeviceId,
    required this.wrappedKey,
    required this.unreadable,
    required this.rawPayload,
  });

  final String id;
  final String? folderId;
  final String title;
  final String content;
  final String preview;
  final String tagsJson;
  final bool pinned;
  final String createdAt;
  final String updatedAt;
  final String? deletedAt;
  final int revision;
  final NoteSyncStatus syncStatus;
  final String lastEditedDeviceId;
  final String wrappedKey;
  final bool unreadable;
  final String? rawPayload;

  List<String> get tags => tagsFromJson(tagsJson);

  Note toNote() => Note(
    id: id,
    folderId: folderId,
    title: title,
    content: content,
    tags: tags,
    pinned: pinned,
    createdAt: createdAt,
    updatedAt: updatedAt,
    deletedAt: deletedAt,
    revision: revision,
    syncStatus: syncStatus,
    lastEditedDeviceId: lastEditedDeviceId,
    unreadable: unreadable,
    preview: preview,
  );

  NoteRow copyWith({
    String? folderId,
    bool clearFolderId = false,
    String? title,
    String? content,
    String? preview,
    String? tagsJson,
    bool? pinned,
    String? createdAt,
    String? updatedAt,
    String? deletedAt,
    bool clearDeletedAt = false,
    int? revision,
    NoteSyncStatus? syncStatus,
    String? lastEditedDeviceId,
    String? wrappedKey,
    bool? unreadable,
    String? rawPayload,
    bool clearRawPayload = false,
  }) {
    return NoteRow(
      id: id,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
      title: title ?? this.title,
      content: content ?? this.content,
      preview: preview ?? this.preview,
      tagsJson: tagsJson ?? this.tagsJson,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      revision: revision ?? this.revision,
      syncStatus: syncStatus ?? this.syncStatus,
      lastEditedDeviceId: lastEditedDeviceId ?? this.lastEditedDeviceId,
      wrappedKey: wrappedKey ?? this.wrappedKey,
      unreadable: unreadable ?? this.unreadable,
      rawPayload: clearRawPayload ? null : (rawPayload ?? this.rawPayload),
    );
  }
}

/// Fila de `folders`.
class FolderRow {
  const FolderRow({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
    required this.wrappedKey,
    required this.unreadable,
    required this.rawPayload,
  });

  final String id;
  final String name;
  final String createdAt;
  final String updatedAt;
  final int revision;
  final String wrappedKey;
  final bool unreadable;
  final String? rawPayload;

  Folder toFolder() =>
      Folder(id: id, name: name, createdAt: createdAt, updatedAt: updatedAt);

  FolderRow copyWith({
    String? name,
    String? createdAt,
    String? updatedAt,
    int? revision,
    String? wrappedKey,
    bool? unreadable,
    String? rawPayload,
    bool clearRawPayload = false,
  }) {
    return FolderRow(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
      wrappedKey: wrappedKey ?? this.wrappedKey,
      unreadable: unreadable ?? this.unreadable,
      rawPayload: clearRawPayload ? null : (rawPayload ?? this.rawPayload),
    );
  }
}

/// JSON de etiquetas, como en el `payload` (`["x","y"]`).
String tagsToJson(List<String> tags) => jsonEncode(tags);

List<String> tagsFromJson(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! List) return const [];
  return [
    for (final tag in decoded)
      if (tag is String) tag,
  ];
}
