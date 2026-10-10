// Vector: contract/vectors/wrap.json.
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

void main() {
  final vector = loadVector('wrap');
  final cases = listOf(vector['cases']);
  late Argon2idDeriver argon2id;

  setUpAll(() async {
    argon2id = await SodiumArgon2id.load();
  });

  group('wrap.json · cases', () {
    for (final case_ in cases) {
      final name = case_['name']! as String;
      test(name, () async {
        final aad = case_['aad']! as String;
        final sealed = case_['sealed']! as String;
        final expectedKey = fromB64u(case_['plaintextKey']! as String);

        final SecretKeyBytes wrapping;
        if (case_.containsKey('kdf')) {
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
          wrapping = derived.kek;
        } else if (case_.containsKey('recoveryBytes')) {
          final derived = await deriveFromRecoveryKey(
            fromB64u(case_['recoveryBytes']! as String),
          );
          wrapping = derived.rkWrap;
        } else {
          wrapping = SecretKeyBytes(fromB64u(case_['masterKey']! as String));
        }

        final unwrapped = await unwrap(wrapping, sealed, aad);
        try {
          expect(unwrapped.bytes, equals(expectedKey));
        } finally {
          unwrapped.dispose();
          wrapping.dispose();
        }
      });
    }
  });

  test(
    'keyBundle + password abre la clave maestra (unlockWithPassword)',
    () async {
      final keyBundleJson = vector['keyBundle']! as Map<String, Object?>;
      final kdfJson = keyBundleJson['kdf']! as Map<String, Object?>;
      final keys = KeyBundle(
        kdf: KdfParams(
          alg: kdfJson['alg']! as String,
          memoryKiB: kdfJson['memoryKiB']! as int,
          iterations: kdfJson['iterations']! as int,
          parallelism: kdfJson['parallelism']! as int,
          salt: kdfJson['salt']! as String,
        ),
        wrappedMasterKey: keyBundleJson['wrappedMasterKey']! as String,
        recoveryWrappedMasterKey:
            keyBundleJson['recoveryWrappedMasterKey']! as String,
        keysVersion: keyBundleJson['keysVersion']! as int,
      );
      final maestraCase = cases.firstWhere(
        (c) => c['name'] == 'maestra-con-kek',
      );
      final expectedKey = fromB64u(maestraCase['plaintextKey']! as String);

      final unlocked = await unlockWithPassword(
        password: vector['password']! as String,
        userId: vector['userId']! as String,
        keys: keys,
        argon2id: argon2id,
      );
      try {
        expect(unlocked.masterKey.bytes, equals(expectedKey));
      } finally {
        unlocked.masterKey.dispose();
      }
    },
  );
}
