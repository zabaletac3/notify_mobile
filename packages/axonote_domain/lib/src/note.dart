import 'ids.dart';

/// Estado de sincronización de una nota respecto al servidor.
enum NoteSyncStatus {
  synced('synced'),
  pending('pending'),
  conflict('conflict');

  const NoteSyncStatus(this.wire);

  /// Valor tal cual viaja en el contrato.
  final String wire;
}

/// Días que una nota permanece en la papelera antes de eliminarse definitivamente.
const int trashRetentionDays = 30;

/// Una nota tal como la ve la aplicación (contenido en claro). El contenido solo existe cifrado
/// mientras la app está bloqueada o en la base local (plan §6).
class Note {
  const Note({
    required this.id,
    required this.folderId,
    required this.title,
    required this.content,
    required this.tags,
    required this.pinned,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.revision,
    required this.syncStatus,
    required this.lastEditedDeviceId,
    this.unreadable = false,
  });

  static const Object _unset = Object();

  final Id id;

  /// `null` = sin carpeta.
  final Id? folderId;
  final String title;

  /// Cuerpo en Markdown (CommonMark + GFM, ADR 0002).
  final String content;

  /// Etiquetas sin `#`, en minúsculas.
  final List<String> tags;
  final bool pinned;
  final IsoDate createdAt;
  final IsoDate updatedAt;

  /// `null` = activa; con fecha = en la papelera.
  final IsoDate? deletedAt;

  /// Revisión conocida del servidor. Base para detectar conflictos.
  final int revision;
  final NoteSyncStatus syncStatus;
  final Id lastEditedDeviceId;

  /// `true` si el texto cifrado no se pudo descifrar (dañado o alterado): solo hay un marcador,
  /// sin contenido, y no se puede editar para no pisar lo guardado.
  final bool unreadable;

  Note copyWith({
    Id? id,
    Object? folderId = _unset,
    String? title,
    String? content,
    List<String>? tags,
    bool? pinned,
    IsoDate? createdAt,
    IsoDate? updatedAt,
    Object? deletedAt = _unset,
    int? revision,
    NoteSyncStatus? syncStatus,
    Id? lastEditedDeviceId,
    bool? unreadable,
  }) {
    return Note(
      id: id ?? this.id,
      folderId: identical(folderId, _unset) ? this.folderId : folderId as Id?,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      pinned: pinned ?? this.pinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as IsoDate?,
      revision: revision ?? this.revision,
      syncStatus: syncStatus ?? this.syncStatus,
      lastEditedDeviceId: lastEditedDeviceId ?? this.lastEditedDeviceId,
      unreadable: unreadable ?? this.unreadable,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.id == id &&
      other.folderId == folderId &&
      other.title == title &&
      other.content == content &&
      _sameTags(other.tags, tags) &&
      other.pinned == pinned &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.deletedAt == deletedAt &&
      other.revision == revision &&
      other.syncStatus == syncStatus &&
      other.lastEditedDeviceId == lastEditedDeviceId &&
      other.unreadable == unreadable;

  @override
  int get hashCode => Object.hash(
    id,
    folderId,
    title,
    content,
    Object.hashAll(tags),
    pinned,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
    lastEditedDeviceId,
    unreadable,
  );

  static bool _sameTags(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Campos que la persona puede editar. Para [folderId] hay que distinguir «no se toca» de
/// «se pone a null (sin carpeta)»: [folderIdPresent] indica si viene en el parche.
class NoteDraft {
  const NoteDraft({
    this.title,
    this.content,
    this.tags,
    this.pinned,
    this.folderId,
    this.folderIdPresent = false,
  });

  final String? title;
  final String? content;
  final List<String>? tags;
  final bool? pinned;
  final Id? folderId;
  final bool folderIdPresent;
}

/// Orden de las notas.
enum NoteSort {
  updated('updated'),
  created('created'),
  title('title');

  const NoteSort(this.wire);

  final String wire;
}

/// Qué lista se está viendo. La papelera solo sale con [NotesFilterTrash].
sealed class NotesFilter {
  const NotesFilter();
}

final class NotesFilterAll extends NotesFilter {
  const NotesFilterAll();
}

final class NotesFilterPinned extends NotesFilter {
  const NotesFilterPinned();
}

final class NotesFilterFolder extends NotesFilter {
  const NotesFilterFolder(this.folderId);

  final Id? folderId;
}

final class NotesFilterTag extends NotesFilter {
  const NotesFilterTag(this.tag);

  final String tag;
}

final class NotesFilterTrash extends NotesFilter {
  const NotesFilterTrash();
}

/// Consulta de la lista: filtro y orden.
class NoteQuery {
  const NoteQuery({this.filter, this.sort});

  final NotesFilter? filter;
  final NoteSort? sort;
}

/// Conteos para la barra lateral.
class NoteCounts {
  const NoteCounts({
    required this.all,
    required this.pinned,
    required this.trash,
    required this.unfiled,
    required this.byFolder,
    required this.byTag,
  });

  /// Notas activas (sin papelera).
  final int all;
  final int pinned;
  final int trash;

  /// Notas activas sin carpeta.
  final int unfiled;
  final Map<Id, int> byFolder;
  final Map<String, int> byTag;
}
