import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('pad', () {
    test('conserva los bytes originales al principio', () {
      final input = utf8Encode('{"a":1}');
      final padded = pad(input);
      expect(padded.sublist(0, input.length), equals(input));
    });

    test('rellena con 0x20', () {
      final input = utf8Encode('x');
      final padded = pad(input);
      expect(padded.sublist(1).every((b) => b == 0x20), isTrue);
    });

    test('usa el bloque por defecto de 256', () {
      expect(pad(Uint8List(1)).length, 256);
    });

    test('respeta un bloque distinto', () {
      expect(pad(Uint8List(1), block: 16).length, 16);
      expect(pad(Uint8List(16), block: 16).length, 16);
      expect(pad(Uint8List(17), block: 16).length, 32);
    });
  });

  group('unpadJson', () {
    test('quita solo el relleno final, no los espacios internos', () {
      final bytes = pad(utf8Encode('{"a": 1}'));
      expect(unpadJson(bytes), '{"a": 1}');
    });

    test('un texto sin relleno se devuelve igual', () {
      expect(unpadJson(utf8Encode('abc')), 'abc');
    });
  });
}
