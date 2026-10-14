import 'package:axonote_app/features/notes/state/note_dates.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fechas y días restantes de la papelera. El texto y la regla son los mismos que en
/// `notify_web` (`daysUntilPurge` + `formatCount(days, 'día', 'días')` en
/// `src/routes/(app)/notes/+page.svelte`).
void main() {
  group('días restantes en la papelera', () {
    final now = DateTime(2026, 10, 14, 12);
    String at(int ago) => isoFromDateTime(now.subtract(Duration(days: ago)));

    test('misma regla que la web (30 días, mínimo 0)', () {
      int days(int ago) => daysUntilPurge(at(ago), now, trashRetentionDays);
      expect(days(1), 29);
      expect(days(14), 16);
      expect(days(21), 9);
      expect(days(45), 0);
    });

    test('mismo texto que la web («Se elimina en N día(s)»)', () {
      expect(purgeLabel(1), 'Se elimina en 1 día');
      expect(purgeLabel(9), 'Se elimina en 9 días');
      expect(purgeLabel(29), 'Se elimina en 29 días');
      expect(purgeLabel(0), 'Se elimina en 0 días');
    });

    test('la fecha de la papelera es relativa («Ayer», «Hace N sem.»)', () {
      expect(trashDate(at(1), now), 'Ayer');
      expect(trashDate(at(0), now), 'Hoy');
      expect(trashDate(at(14), now), 'Hace 2 sem.');
      expect(trashDate(at(21), now), 'Hace 3 sem.');
    });
  });
}
