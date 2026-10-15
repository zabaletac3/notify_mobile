import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_session.dart';
import '../../../bootstrap/providers.dart';
import 'notes_view.dart';

/// Una fila de la lista: cabecera de grupo o nota. La lista se aplana para poder pintarla con
/// `ListView.builder` (perezoso) y para no reagrupar en cada reconstrucción de la interfaz.
class NoteListRow {
  const NoteListRow.header(this.header) : note = null;

  const NoteListRow.note(this.note) : header = null;

  final String? header;
  final Note? note;
}

/// Aplana las notas agrupadas (Fijadas · Hoy · Esta semana · mes) a filas.
List<NoteListRow> groupRows(List<Note> notes, DateTime now) {
  final rows = <NoteListRow>[];
  for (final group in groupNotes(notes, now)) {
    rows.add(NoteListRow.header(group.label));
    for (final note in group.notes) {
      rows.add(NoteListRow.note(note));
    }
  }
  return rows;
}

/// Notas que se piden de una vez (plan §4.4: la lista no materializa toda la colección; la interfaz
/// carga por páginas). Mismo tamaño que la medición de la fase 6.
const int notesPageSize = 200;

/// Ventana cargada de la lista actual (páginas acumuladas). Se reinicia al cambiar el filtro o el
/// orden, porque depende de [notesViewProvider].
class NotesWindowController extends Notifier<int> {
  @override
  int build() {
    ref.watch(notesViewProvider);
    return notesPageSize;
  }

  void loadMore() => state = state + notesPageSize;
}

final notesWindowProvider = NotifierProvider<NotesWindowController, int>(
  NotesWindowController.new,
);

/// Lista de notas de la vista actual (filtro, orden y ventana de [notesWindowProvider]), reactiva.
/// Mientras el cofre está bloqueado (`NoteRepository` nulo) queda en carga; los fallos llegan como
/// `AsyncError`.
final notesListProvider = StreamProvider<List<Note>>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  final query = ref.watch(notesQueryProvider);
  final limit = ref.watch(notesWindowProvider);
  if (repo == null) return const Stream<List<Note>>.empty();
  return repo.watch(
    NoteQuery(filter: query.filter, sort: query.sort, limit: limit),
  );
});

/// Filas ya agrupadas de la lista. Se calculan una sola vez por cambio de datos (no en cada
/// reconstrucción de la interfaz): con 10 000 notas, reagrupar cuesta y provoca cuadros perdidos
/// durante el desplazamiento (§11). El reloj se lee, no se observa, para no recalcular por cada
/// segundo.
final notesRowsProvider = Provider<List<NoteListRow>>((ref) {
  final notes = ref.watch(notesListProvider).value ?? const <Note>[];
  final now = ref.read(clockProvider).now();
  return groupRows(notes, now);
});

/// Notas de una carpeta concreta (pantalla `/folders/:id`).
final folderNotesProvider = StreamProvider.family<List<Note>, Id>((ref, id) {
  final repo = ref.watch(noteRepositoryProvider);
  final view = ref.watch(notesViewProvider);
  final limit = ref.watch(notesWindowProvider);
  if (repo == null) return const Stream<List<Note>>.empty();
  return repo.watch(
    NoteQuery(filter: NotesFilterFolder(id), sort: view.sort, limit: limit),
  );
});

/// Notas de la papelera (pantalla `/trash`), más antiguas primero.
final trashNotesProvider = StreamProvider<List<Note>>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  final limit = ref.watch(notesWindowProvider);
  if (repo == null) return const Stream<List<Note>>.empty();
  return repo.watch(
    NoteQuery(
      filter: const NotesFilterTrash(),
      sort: NoteSort.updated,
      limit: limit,
    ),
  );
});

/// Carpetas de la cuenta, reactivas.
final foldersProvider = StreamProvider<List<Folder>>((ref) {
  final repo = ref.watch(folderRepositoryProvider);
  if (repo == null) return const Stream<List<Folder>>.empty();
  return repo.watch();
});

/// Conteos para el menú lateral (barra lateral con el total de cada carpeta y etiqueta).
///
/// Se recalcula solo cuando **cambian los datos**, no cada vez que crece la ventana de la lista: se
/// apoya en [notesChangedProvider] (una consulta fija y barata) en vez de en la lista paginada. Con
/// 10 000 notas, reagregar en cada página provocaba cuadros perdidos al desplazar (§11).
final noteCountsProvider = FutureProvider<NoteCounts?>((ref) async {
  final repo = ref.watch(noteRepositoryProvider);
  ref.watch(notesChangedProvider);
  if (repo == null) return null;
  return repo.counts();
});

/// Señal que cambia cuando cambian las notas (altas, ediciones, borrados), sin depender de la
/// ventana ni del filtro de la lista.
final notesChangedProvider = StreamProvider<void>((ref) {
  final repo = ref.watch(noteRepositoryProvider);
  if (repo == null) return const Stream<void>.empty();
  return repo.watch(const NoteQuery(limit: 1)).map((_) {});
});

/// Término de búsqueda actual de la pantalla `/search`.
class SearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;

  void clear() => state = '';
}

final searchQueryProvider = NotifierProvider<SearchQueryController, String>(
  SearchQueryController.new,
);

/// Resultados de la búsqueda local (FTS5). Vacía si no hay término.
final searchResultsProvider = FutureProvider<List<Note>>((ref) async {
  final repo = ref.watch(noteRepositoryProvider);
  final term = ref.watch(searchQueryProvider).trim();
  if (repo == null || term.isEmpty) return const [];
  return repo.search(term);
});
