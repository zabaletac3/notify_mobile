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
  late Argon2idDeriver argon2id;

  setUpAll(() async {
    argon2id = await SodiumArgon2id.load();
  });

  group('deriveFromPassword · KdfUnsupported', () {
    test('rechaza un algoritmo distinto de argon2id sin derivar', () {
      final kdf = KdfParams(
        alg: 'argon2i',
        memoryKiB: 1024,
        iterations: 1,
        parallelism: 1,
        salt: toB64u(Uint8List(16)),
      );
      expect(
        () => deriveFromPassword('x', kdf, _NeverArgon2id()),
        throwsA(isA<KdfUnsupported>()),
      );
    });

    test('rechaza un paralelismo distinto de 1 sin derivar', () {
      final kdf = KdfParams(
        alg: 'argon2id',
        memoryKiB: 1024,
        iterations: 1,
        parallelism: 4,
        salt: toB64u(Uint8List(16)),
      );
      expect(
        () => deriveFromPassword('x', kdf, _NeverArgon2id()),
        throwsA(isA<KdfUnsupported>()),
      );
    });
  });

  group('deriveFromPassword · sal', () {
    test('rechaza una sal que no mide 16 bytes sin derivar', () {
      // La web (kdf.ts, SALT_BYTES) siempre genera 16 bytes; una sal de otra longitud solo puede
      // venir de un servidor con un formato distinto, y se rechaza antes de llamar a Argon2id.
      final kdf = KdfParams(
        alg: 'argon2id',
        memoryKiB: 1024,
        iterations: 1,
        parallelism: 1,
        salt: toB64u(Uint8List(8)),
      );
      expect(
        () => deriveFromPassword('x', kdf, _NeverArgon2id()),
        throwsA(isA<CryptoFormatError>()),
      );
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
      final b = await deriveFromRecoveryKey(
        Uint8List.fromList(List.filled(32, 1)),
      );
      expect(a.recoveryAuth, isNot(b.recoveryAuth));
      a.rkWrap.dispose();
      b.rkWrap.dispose();
    });
  });

  group('deriveLocalDbKey', () {
    test('es determinista para la misma clave maestra y el mismo userId', () async {
      final mkA = SecretKeyBytes(Uint8List.fromList(List.generate(32, (i) => i)));
      final mkB = SecretKeyBytes(Uint8List.fromList(List.generate(32, (i) => i)));
      final a = await deriveLocalDbKey(mkA, 'user-1');
      final b = await deriveLocalDbKey(mkB, 'user-1');
      expect(a.bytes, equals(b.bytes));
      expect(a.length, 32);
      mkA.dispose();
      mkB.dispose();
      a.dispose();
      b.dispose();
    });

    test('userId distinto produce una clave de base distinta (etiquetas por cuenta, A1)', () async {
      final mk = SecretKeyBytes(Uint8List.fromList(List.generate(32, (i) => i)));
      final a = await deriveLocalDbKey(mk, 'user-1');
      final b = await deriveLocalDbKey(mk, 'user-2');
      expect(a.bytes, isNot(equals(b.bytes)));
      mk.dispose();
      a.dispose();
      b.dispose();
    });

    test('no coincide con otra etiqueta HKDF aplicada a los mismos bytes de entrada', () async {
      // Misma clave de entrada, etiquetas distintas: "apunte/v1/local-db/<userId>" frente a
      // "apunte/v1/recovery-kek" (deriveFromRecoveryKey usa la misma HKDF interna). Deben divergir.
      final ikm = Uint8List.fromList(List.generate(32, (i) => i * 3 % 256));
      final mk = SecretKeyBytes(Uint8List.fromList(ikm));
      final localDbKey = await deriveLocalDbKey(mk, 'user-1');
      final recoveryDerived = await deriveFromRecoveryKey(ikm);
      expect(localDbKey.bytes, isNot(equals(recoveryDerived.rkWrap.bytes)));
      mk.dispose();
      localDbKey.dispose();
      recoveryDerived.rkWrap.dispose();
    });
  });
}
