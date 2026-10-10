import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('b64u', () {
    test('ida y vuelta', () {
      final bytes = Uint8List.fromList(List.generate(37, (i) => i * 7 % 256));
      expect(fromB64u(toB64u(bytes)), equals(bytes));
    });

    test('nunca lleva relleno "="', () {
      expect(toB64u(Uint8List.fromList([1])), isNot(contains('=')));
    });

    test('rechaza caracteres fuera del alfabeto', () {
      expect(() => fromB64u('a+b/c'), throwsA(isA<CryptoFormatError>()));
    });

    test('rechaza una longitud con resto 1', () {
      expect(() => fromB64u('a'), throwsA(isA<CryptoFormatError>()));
    });

    test('acepta la cadena vacía', () {
      expect(fromB64u(''), isEmpty);
    });
  });

  group('concatBytes', () {
    test('concatena en orden', () {
      final result = concatBytes([
        Uint8List.fromList([1, 2]),
        Uint8List.fromList([]),
        Uint8List.fromList([3]),
      ]);
      expect(result, equals(Uint8List.fromList([1, 2, 3])));
    });
  });

  group('timingSafeEqual', () {
    test('bytes iguales', () {
      expect(
        timingSafeEqual(
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([1, 2, 3]),
        ),
        isTrue,
      );
    });

    test('bytes distintos', () {
      expect(
        timingSafeEqual(
          Uint8List.fromList([1, 2, 3]),
          Uint8List.fromList([1, 2, 4]),
        ),
        isFalse,
      );
    });

    test('longitudes distintas', () {
      expect(
        timingSafeEqual(Uint8List.fromList([1]), Uint8List.fromList([1, 2])),
        isFalse,
      );
    });
  });

  group('SecretKeyBytes', () {
    test('expone los bytes y la longitud', () {
      final key = SecretKeyBytes(Uint8List.fromList([9, 8, 7]));
      expect(key.length, 3);
      expect(key.bytes, equals(Uint8List.fromList([9, 8, 7])));
      expect(key.isDisposed, isFalse);
    });

    test('dispose borra los bytes y los vuelve inaccesibles', () {
      final original = Uint8List.fromList([1, 2, 3, 4]);
      final key = SecretKeyBytes(original);
      key.dispose();
      expect(key.isDisposed, isTrue);
      expect(original, equals(Uint8List.fromList([0, 0, 0, 0])));
      expect(() => key.bytes, throwsStateError);
    });

    test('dispose repetido no falla', () {
      final key = SecretKeyBytes(Uint8List.fromList([1]));
      key.dispose();
      expect(key.dispose, returnsNormally);
    });

    test('la longitud sigue disponible tras borrar la clave', () {
      final key = SecretKeyBytes(Uint8List.fromList([1, 2, 3, 4, 5]));
      key.dispose();
      expect(key.length, 5);
    });

    test('toString no revela los bytes', () {
      final key = SecretKeyBytes(Uint8List.fromList([0xAB, 0xCD, 0xEF]));
      expect(key.toString(), isNot(contains('ab')));
      expect(key.toString(), isNot(contains('AB')));
      expect(
        key.toString(),
        isNot(contains(toB64u(Uint8List.fromList([0xAB, 0xCD, 0xEF])))),
      );
    });
  });
}
