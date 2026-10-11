import 'note.dart';
import 'note_text.dart';

/// Aplica filtro y orden de una consulta. La papelera solo sale con [NotesFilterTrash].
/// Portado de `notify_web/src/lib/domain/note-query.ts`.
List<Note> queryNotes(List<Note> notes, [NoteQuery query = const NoteQuery()]) {
  final filter = query.filter ?? const NotesFilterAll();
  final items = notes.where((n) {
    if (filter is NotesFilterTrash) return n.deletedAt != null;
    if (n.deletedAt != null) return false;
    return switch (filter) {
      NotesFilterPinned() => n.pinned,
      NotesFilterFolder(folderId: final folderId) => n.folderId == folderId,
      NotesFilterTag(tag: final tag) => n.tags.contains(tag),
      _ => true,
    };
  }).toList();

  final sort = query.sort ?? NoteSort.updated;
  items.sort((a, b) {
    return switch (sort) {
      NoteSort.title => _compareTitle(a.title, b.title),
      NoteSort.created => b.createdAt.compareTo(a.createdAt),
      NoteSort.updated => b.updatedAt.compareTo(a.updatedAt),
    };
  });
  return items;
}

/// Compara títulos como `localeCompare(b, 'es', { sensitivity: 'base' })`: sin distinguir
/// mayúsculas ni tildes. Dart no trae `localeCompare`, así que se comparan las formas plegadas.
int _compareTitle(String a, String b) {
  final folded = foldText(a).compareTo(foldText(b));
  return folded != 0 ? folded : a.compareTo(b);
}
