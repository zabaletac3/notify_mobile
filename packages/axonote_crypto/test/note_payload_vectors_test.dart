// Vector: contract/vectors/note-payload.json.
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

void main() {
  final vector = loadVector('note-payload');
  final masterKey = SecretKeyBytes(fromB64u(vector['masterKey']! as String));

  test('note-payload.json · note', () async {
    final note = vector['note']! as Map<String, Object?>;
    final decrypted = note['decrypted']! as Map<String, Object?>;

    final itemKey = await unwrap(
      masterKey,
      note['wrappedKey']! as String,
      note['keyAad']! as String,
    );
    try {
      expect(itemKey.bytes, equals(fromB64u(note['itemKey']! as String)));

      final bytes = await open(
        itemKey,
        note['payload']! as String,
        note['dataAad']! as String,
      );
      expect(unpadJson(bytes), note['plaintextJson']);

      final payload = await openNotePayload(
        itemKey,
        note['payload']! as String,
        note['dataAad']! as String,
      );
      expect(payload.title, decrypted['title']);
      expect(payload.content, decrypted['content']);
      expect(payload.tags, equals(decrypted['tags']));
      expect(payload.pinned, decrypted['pinned']);
    } finally {
      itemKey.dispose();
    }
  });

  test('note-payload.json · folder', () async {
    final folder = vector['folder']! as Map<String, Object?>;
    final decrypted = folder['decrypted']! as Map<String, Object?>;

    final itemKey = await unwrap(
      masterKey,
      folder['wrappedKey']! as String,
      folder['keyAad']! as String,
    );
    try {
      expect(itemKey.bytes, equals(fromB64u(folder['itemKey']! as String)));

      final bytes = await open(
        itemKey,
        folder['payload']! as String,
        folder['dataAad']! as String,
      );
      expect(unpadJson(bytes), folder['plaintextJson']);

      final payload = await openFolderPayload(
        itemKey,
        folder['payload']! as String,
        folder['dataAad']! as String,
      );
      expect(payload.name, decrypted['name']);
    } finally {
      itemKey.dispose();
    }
  });
}
