import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('generateRecoveryKey', () {
    test('genera 32 bytes', () {
      expect(generateRecoveryKey().length, 32);
    });

    test('dos llamadas no coinciden', () {
      expect(generateRecoveryKey(), isNot(equals(generateRecoveryKey())));
    });

    test('ida y vuelta con formatRecoveryKey/parseRecoveryKey', () {
      final bytes = generateRecoveryKey();
      expect(parseRecoveryKey(formatRecoveryKey(bytes)), equals(bytes));
    });
  });

  group('formatRecoveryKey', () {
    test('rechaza una clave que no mide 32 bytes', () {
      expect(() => formatRecoveryKey(Uint8List(31)), throwsA(isA<CryptoFormatError>()));
      expect(() => formatRecoveryKey(Uint8List(33)), throwsA(isA<CryptoFormatError>()));
    });
  });

  group('parseRecoveryKey', () {
    test('rechaza una longitud de texto distinta de 53', () {
      expect(() => parseRecoveryKey('ABCD'), throwsA(isA<CryptoFormatError>()));
    });
  });
}
