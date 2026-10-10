import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

/// Nunca debe llamarse: las pruebas de [KdfUnsupported] comprueban que `deriveFromPassword`
/// rechaza los parámetros antes de intentar derivar.
class _NeverArgon2id implements Argon2idDeriver {
  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required int memoryKiB,
    required int iterations,
  }) {
    fail('no debía llamarse a Argon2id con parámetros no compatibles');
  }
}

void main() {
  final argon2id = SodiumArgon2id.load();

  group('deriveFromPassword · KdfUnsupported', () {
    test('rechaza un algoritmo distinto de argon2id sin derivar', () {
      final kdf = KdfParams(
        alg: 'argon2i',
        memoryKiB: 1024,
        iterations: 1,
        parallelism: 1,
        salt: toB64u(Uint8List(16)),
      );
      expect(() => deriveFromPassword('x', kdf, _NeverArgon2id()), throwsA(isA<KdfUnsupported>()));
    });

    test('rechaza un paralelismo distinto de 1 sin derivar', () {
      final kdf = KdfParams(
        alg: 'argon2id',
        memoryKiB: 1024,
        iterations: 1,
        parallelism: 4,
        salt: toB64u(Uint8List(16)),
      );
      expect(() => deriveFromPassword('x', kdf, _NeverArgon2id()), throwsA(isA<KdfUnsupported>()));
    });
  });

  group('deriveFromPassword · NFKC', () {
    test('la misma palabra en NFC y en NFD produce la misma authKey', () async {
      final kdf = KdfParams(
        alg: 'argon2id',
        memoryKiB: 1024,
        iterations: 1,
        parallelism: 1,
        salt: toB64u(Uint8List(16)),
      );
      // La misma palabra: una con la vocal con tilde precompuesta (NFC, U+00E9) y otra con la
      // vocal y el acento combinante por separado (NFD, U+0065 U+0301). NFKC las normaliza a los
      // mismos bytes antes de pasar por Argon2id.
      final nfc = await deriveFromPassword('café', kdf, argon2id);
      final nfd = await deriveFromPassword('café', kdf, argon2id);
      expect(nfc.authKey, nfd.authKey);
      nfc.kek.dispose();
      nfd.kek.dispose();
    });
  });

  group('deriveFromRecoveryKey', () {
    test('es determinista para los mismos bytes', () async {
      final recoveryKey = Uint8List.fromList(List.generate(32, (i) => i));
      final a = await deriveFromRecoveryKey(recoveryKey);
      final b = await deriveFromRecoveryKey(recoveryKey);
      expect(a.recoveryAuth, b.recoveryAuth);
      expect(a.rkWrap.bytes, equals(b.rkWrap.bytes));
      a.rkWrap.dispose();
      b.rkWrap.dispose();
    });

    test('bytes distintos producen recoveryAuth distinto', () async {
      final a = await deriveFromRecoveryKey(Uint8List(32));
      final b = await deriveFromRecoveryKey(Uint8List.fromList(List.filled(32, 1)));
      expect(a.recoveryAuth, isNot(b.recoveryAuth));
      a.rkWrap.dispose();
      b.rkWrap.dispose();
    });
  });
}
