// Vector: contract/vectors/sealed.json. Recorre todos los `cases` y todos los `failures`
// (incluidos los fallos esperados): nunca se debilita un vector para que pase.
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_crypto/src/sealed.dart' show sealWithIv;
import 'package:test/test.dart';

import 'support/vectors.dart';

void main() {
  final vector = loadVector('sealed');
  final cases = listOf(vector['cases']);
  final failures = listOf(vector['failures']);

  group('sealed.json · cases', () {
    for (final case_ in cases) {
      final name = case_['name']! as String;
      test(name, () async {
        final key = SecretKeyBytes(fromB64u(case_['key']! as String));
        final aad = case_['aad']! as String;
        final sealed = case_['sealed']! as String;
        final plaintext = case_['plaintext']! as String;

        final opened = await open(key, sealed, aad);
        expect(fromUtf8(opened), plaintext);

        // Cifrar con el mismo IV debe producir exactamente el mismo `sealed`.
        final reproduced = await sealWithIv(key, utf8Encode(plaintext), aad, fromB64u(case_['iv']! as String));
        expect(reproduced, sealed);
      });
    }
  });

  group('sealed.json · failures', () {
    for (final failure in failures) {
      final name = failure['name']! as String;
      test(name, () async {
        final base = cases.firstWhere((c) => c['name'] == failure['case']);
        final key = SecretKeyBytes(
          fromB64u((failure['key'] ?? base['key'])! as String),
        );
        final aad = (failure['aad'] ?? base['aad'])! as String;
        final sealed = (failure['sealed'] ?? base['sealed'])! as String;
        final errorMatcher = switch (failure['error']) {
          'DecryptError' => isA<DecryptError>(),
          'CryptoFormatError' => isA<CryptoFormatError>(),
          _ => fail('tipo de error desconocido en el vector: ${failure['error']}'),
        };
        await expectLater(open(key, sealed, aad), throwsA(errorMatcher));
      });
    }
  });
}
