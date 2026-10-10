// Vector: contract/vectors/kdf.json.
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

void main() {
  final vector = loadVector('kdf');
  final cases = listOf(vector['cases']);
  late Argon2idDeriver argon2id;

  setUpAll(() async {
    argon2id = await SodiumArgon2id.load();
  });

  group('kdf.json · cases', () {
    for (final case_ in cases) {
      final name = case_['name']! as String;
      test(name, () async {
        final kdfJson = case_['kdf']! as Map<String, Object?>;
        final kdf = KdfParams(
          alg: kdfJson['alg']! as String,
          memoryKiB: kdfJson['memoryKiB']! as int,
          iterations: kdfJson['iterations']! as int,
          parallelism: kdfJson['parallelism']! as int,
          salt: kdfJson['salt']! as String,
        );
        final derived = await deriveFromPassword(
          case_['password']! as String,
          kdf,
          argon2id,
        );
        try {
          expect(derived.authKey, case_['authKey']);

          final kekCheck = case_['kekCheck']! as Map<String, Object?>;
          final opened = await open(
            derived.kek,
            kekCheck['sealed']! as String,
            kekCheck['aad']! as String,
          );
          expect(opened, equals(fromB64u(kekCheck['masterKey']! as String)));
        } finally {
          derived.kek.dispose();
        }
      });
    }
  });
}
