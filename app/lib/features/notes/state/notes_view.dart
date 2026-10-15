import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Qué lista se está viendo y cómo se ordena (la «vista» de la pantalla de notas). La papelera y
/// las búsquedas no se guardan aquí: cada pantalla pide su propia consulta.
class NotesView {
  const NotesView({
    this.filter = const NotesFilterAll(),
    this.sort = NoteSort.updated,
  });

  final NotesFilter filter;
  final NoteSort sort;

  NotesView copyWith({NotesFilter? filter, NoteSort? sort}) =>
      NotesView(filter: filter ?? this.filter, sort: sort ?? this.sort);
}

/// Filtro y orden actuales de la lista de notas.
class NotesViewController extends Notifier<NotesView> {
  @override
  NotesView build() => const NotesView();

  void setFilter(NotesFilter filter) => state = state.copyWith(filter: filter);

  void setSort(NoteSort sort) => state = state.copyWith(sort: sort);
}

final notesViewProvider = NotifierProvider<NotesViewController, NotesView>(
  NotesViewController.new,
);

/// Consulta guardada de la pantalla de la lista (`/notes`), para que `view` y la lista usen el
/// mismo filtro/orden.
final notesQueryProvider = Provider<NoteQuery>((ref) {
  final view = ref.watch(notesViewProvider);
  return NoteQuery(filter: view.filter, sort: view.sort);
});
