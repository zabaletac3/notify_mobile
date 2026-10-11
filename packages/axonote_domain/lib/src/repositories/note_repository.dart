import '../ids.dart';
import '../note.dart';

/// Acceso a las notas guardadas en local. Lo implementa `app/lib/data` (drift). El estado y la
/// interfaz solo conocen esta interfaz (plan §4.2). Los métodos lanzan `AppFailure`.
abstract interface class NoteRepository {
  /// Lista según [query] (filtro y orden). La papelera solo sale con [NotesFilterTrash].
  Future<List<Note>> list([NoteQuery query]);

  /// Igual que [list], pero reactivo: emite cada vez que cambian las notas.
  Stream<List<Note>> watch([NoteQuery query]);

  Future<Note> get(Id id);

  /// Búsqueda local (FTS5, prefijos, sin distinguir tildes) aplicando [query].
  Future<List<Note>> search(String term, [NoteQuery query]);

  Future<Note> create([NoteDraft draft]);

  Future<Note> update(Id id, NoteDraft patch);

  Future<Note> duplicate(Id id);

  Future<Note> moveToTrash(Id id);

  Future<Note> restore(Id id);

  Future<void> deleteForever(Id id);

  /// Vacía la papelera y devuelve cuántas notas se borraron.
  Future<int> emptyTrash();

  /// Conteos para la barra lateral.
  Future<NoteCounts> counts();
}
