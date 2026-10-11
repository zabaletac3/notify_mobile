import 'package:axonote_app/data/local/local_item_codec.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'local_harness.dart';

void main() {
  late LocalHarness h;
  late LocalItemCodec codec;

  setUp(() {
    h = LocalHarness(now: () => DateTime.utc(2026, 10, 11, 12));
    codec = LocalItemCodec(h.local.deps);
  });
  tearDown(() => h.close());

  test('cifra una nota desde su fila actual (A4)', () async {
    final note = await h.local.notes.create(
      const NoteDraft(title: 'T', content: 'cuerpo', folderId: null),
    );
    final fields = await codec.sealNote(note.id);
    expect(fields.folderId, isNull);
    expect(fields.createdAt, isNotEmpty);
    expect(fields.wrappedKey, isNotEmpty);
    expect(fields.payload, isNotEmpty);

    // El cifrado refleja el contenido actual, no uno congelado al encolar.
    await h.local.notes.update(
      note.id,
      const NoteDraft(content: 'cuerpo nuevo'),
    );
    final after = await codec.sealNote(note.id);
    expect(after.payload, isNot(fields.payload));
  });

  test('cifra una carpeta desde su fila actual', () async {
    final folder = await h.local.folders.create('Carpeta');
    final fields = await codec.sealFolder(folder.id);
    expect(fields.wrappedKey, isNotEmpty);
    expect(fields.payload, isNotEmpty);
  });

  test('una nota que ya no existe falla con not-found', () async {
    await expectLater(
      codec.sealNote('no-existe'),
      throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', 'not-found')),
    );
  });

  test('una carpeta que ya no existe falla con not-found', () async {
    await expectLater(
      codec.sealFolder('no-existe'),
      throwsA(isA<AppFailure>().having((f) => f.kind, 'kind', 'not-found')),
    );
  });
}
