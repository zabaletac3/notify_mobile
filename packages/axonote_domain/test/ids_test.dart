import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

void main() {
  group('newId (UUID v7)', () {
    test('tiene formato UUID con versión 7 y variante RFC 4122', () {
      expect(
        newId(),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('ordena por hora de creación', () {
      final ids = [
        1000,
        5000,
        2000,
        9000,
        3000,
      ].map((t) => (t: t, id: newId(t))).toList();
      ids.sort((a, b) => a.id.compareTo(b.id));
      expect(ids.map((x) => x.t).toList(), [1000, 2000, 3000, 5000, 9000]);
    });

    test('no repite identificadores', () {
      expect({for (var i = 0; i < 1000; i++) newId()}.length, 1000);
    });
  });

  group('fechas ISO', () {
    test('isoFromDateTime usa milisegundos UTC y sufijo Z', () {
      final d = DateTime.utc(2026, 10, 7, 8, 54, 0, 0);
      expect(isoFromDateTime(d), '2026-10-07T08:54:00.000Z');
    });

    test('isoFromDateTime descarta microsegundos (igual que la web)', () {
      final d = DateTime.utc(
        2026,
        1,
        2,
        3,
        4,
        5,
        6,
      ).add(const Duration(microseconds: 789));
      expect(isoFromDateTime(d), '2026-01-02T03:04:05.006Z');
    });

    test('parseIsoDate interpreta el valor del contrato', () {
      expect(
        parseIsoDate('2026-10-07T08:54:00.000Z'),
        DateTime.utc(2026, 10, 7, 8, 54),
      );
    });
  });
}
