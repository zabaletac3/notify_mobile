import 'package:axonote_app/data/local/test_data_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_harness.dart';

void main() {
  test('el generador llena notas, carpetas y búsqueda', () async {
    final h = LocalHarness(now: () => DateTime.utc(2026, 10, 7, 12));
    addTearDown(h.close);

    await TestDataGenerator(h.local.deps).generate(notes: 200, folders: 4);

    expect((await h.local.notes.list()).length, 199);
    expect((await h.local.folders.list()).length, 4);
    final found = await h.local.notes.search('lorem');
    expect(found, isNotEmpty);
    expect(found.length, lessThanOrEqualTo(199));
    final counts = await h.local.notes.counts();
    expect(counts.trash, 1);
    expect(counts.pinned, greaterThan(0));
  });
}
