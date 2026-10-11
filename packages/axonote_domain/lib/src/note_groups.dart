import 'note.dart';

/// Un grupo de la lista de notas (Fijadas · Hoy · Esta semana · mes…).
class NoteGroup {
  const NoteGroup({
    required this.key,
    required this.label,
    required this.notes,
  });

  /// Clave estable: `pinned`, `today`, `week`, `2026-09`, `2025`…
  final String key;

  /// Etiqueta para mostrar: "Fijadas", "Hoy", "Esta semana", "Septiembre", "Septiembre 2025".
  final String label;
  final List<Note> notes;
}

const int _dayMs = 24 * 60 * 60 * 1000;

const List<String> _months = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

/// Agrupa las notas como la lista del diseño: Fijadas · Hoy · Esta semana · mes (· mes y año).
/// El orden de las notas dentro de cada grupo es el que traiga [notes]; el de los grupos es fijo.
/// Portado de `notify_web/src/lib/domain/note-groups.ts`.
List<NoteGroup> groupNotes(List<Note> notes, DateTime now) {
  final groups = <String, NoteGroup>{};
  void push(String key, String label, Note note) {
    final g = groups[key] ?? NoteGroup(key: key, label: label, notes: []);
    g.notes.add(note);
    groups[key] = g;
  }

  final localNow = now.toLocal();
  final startOfToday = DateTime(
    localNow.year,
    localNow.month,
    localNow.day,
  ).millisecondsSinceEpoch;

  for (final note in notes) {
    if (note.pinned) {
      push('pinned', 'Fijadas', note);
      continue;
    }
    final d = DateTime.parse(note.updatedAt).toLocal();
    final t = d.millisecondsSinceEpoch;
    if (t >= startOfToday) {
      push('today', 'Hoy', note);
    } else if (t >= startOfToday - 6 * _dayMs) {
      push('week', 'Esta semana', note);
    } else {
      final sameYear = d.year == localNow.year;
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      push(
        key,
        sameYear ? _months[d.month - 1] : '${_months[d.month - 1]} ${d.year}',
        note,
      );
    }
  }

  int rank(String key) => switch (key) {
    'pinned' => 0,
    'today' => 1,
    'week' => 2,
    _ => 3,
  };

  final result = groups.values.toList();
  result.sort((a, b) {
    final byRank = rank(a.key) - rank(b.key);
    if (byRank != 0) return byRank;
    return rank(a.key) == 3 ? b.key.compareTo(a.key) : 0;
  });
  return result;
}

/// Días que faltan para que una nota de la papelera se elimine definitivamente (mínimo 0).
int daysUntilPurge(String deletedAt, DateTime now, int retentionDays) {
  final elapsed =
      ((now.millisecondsSinceEpoch -
                  DateTime.parse(deletedAt).millisecondsSinceEpoch) /
              _dayMs)
          .floor();
  final remaining = retentionDays - elapsed;
  return remaining > 0 ? remaining : 0;
}
