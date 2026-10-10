import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('generateKeyBytes', () {
    test('genera 32 bytes', () {
      expect(generateKeyBytes().length, 32);
    });

    test('dos llamadas no coinciden', () {
      expect(generateKeyBytes().bytes, isNot(equals(generateKeyBytes().bytes)));
    });
  });

  group('wrap/unwrap', () {
    test('ida y vuelta recupera la misma clave', () async {
      final wrapping = SecretKeyBytes(Uint8List(32));
      final key = generateKeyBytes();
      final sealed = await wrap(wrapping, key, 'aad');
      final unwrapped = await unwrap(wrapping, sealed, 'aad');
      expect(unwrapped.bytes, equals(key.bytes));
    });

    test('rechaza un texto cifrado que no envuelve 32 bytes', () async {
      final wrapping = SecretKeyBytes(Uint8List(32));
      final sealed = await seal(wrapping, Uint8List(16), 'aad');
      expect(() => unwrap(wrapping, sealed, 'aad'), throwsA(isA<CryptoFormatError>()));
    });
  });

  group('exportKeyRaw/importKeyRaw', () {
    test('ida y vuelta', () {
      final key = generateKeyBytes();
      expect(importKeyRaw(exportKeyRaw(key)).bytes, equals(key.bytes));
    });

    test('rechaza una clave que no mide 32 bytes', () {
      expect(() => importKeyRaw(toB64u(Uint8List(16))), throwsA(isA<CryptoFormatError>()));
    });
  });
}
