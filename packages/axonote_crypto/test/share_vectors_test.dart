// Vector: contract/vectors/share.json.
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

void main() {
  final vector = loadVector('share');

  test('share.json', () async {
    final userId = vector['userId']! as String;
    final noteId = vector['noteId']! as String;
    final slug = vector['slug']! as String;
    final masterKey = SecretKeyBytes(fromB64u(vector['masterKey']! as String));
    final decrypted = vector['decrypted']! as Map<String, Object?>;

    expect(shareKeyAad(userId, noteId), vector['keyAad']);
    expect(shareContentAad(slug), vector['contentAad']);
    expect(isValidSlug(slug), isTrue);

    final shareKey = await unwrap(masterKey, vector['wrappedShareKey']! as String, vector['keyAad']! as String);
    try {
      expect(shareKey.bytes, equals(fromB64u(vector['shareKey']! as String)));
      expect(exportKeyRaw(shareKey), vector['shareKey']);
      expect(shareKeyFromFragment(vector['keyFragment']! as String), vector['shareKey']);

      final payload = await openLinkPayload(shareKey, slug, vector['payload']! as String);
      expect(payload.title, decrypted['title']);
      expect(payload.content, decrypted['content']);
    } finally {
      shareKey.dispose();
    }
  });
}
