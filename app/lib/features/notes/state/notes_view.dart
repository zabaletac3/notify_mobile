import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/state/settings_controller.dart';

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

NoteSort _sortOf(NoteOrder order) => switch (order) {
  NoteOrder.created => NoteSort.created,
  NoteOrder.title => NoteSort.title,
  NoteOrder.updated => NoteSort.updated,
};

/// Filtro y orden actuales de la lista de notas. El orden inicial es el de los ajustes («Orden de
/// las notas»); cambiarlo en la lista no toca el ajuste, pero cambiar el ajuste sí lo aplica.
class NotesViewController extends Notifier<NotesView> {
  @override
  NotesView build() {
    ref.listen(settingsProvider, (previous, next) {
      if (previous?.noteOrder != next.noteOrder) {
        state = state.copyWith(sort: _sortOf(next.noteOrder));
      }
    });
    return NotesView(sort: _sortOf(ref.read(settingsProvider).noteOrder));
  }

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
