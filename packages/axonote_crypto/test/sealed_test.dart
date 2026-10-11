import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_crypto/src/sealed.dart' show sealWithIv;
import 'package:test/test.dart';

void main() {
  group('isSealed', () {
    test('acepta el formato correcto', () {
      expect(isSealed('a1.AAAAAAAAAAAAAAAA.AA'), isTrue);
    });

    test('rechaza valores que no son texto', () {
      expect(isSealed(42), isFalse);
      expect(isSealed(null), isFalse);
    });

    test('rechaza una versión distinta de a1', () {
      expect(isSealed('a2.AAAAAAAAAAAAAAAA.AA'), isFalse);
    });

    test('rechaza un IV que no mide 16 caracteres en base64url', () {
      expect(isSealed('a1.corto.AA'), isFalse);
    });

    test('rechaza texto cifrado vacío', () {
      expect(isSealed('a1.AAAAAAAAAAAAAAAA.'), isFalse);
    });
  });

  group('seal/open', () {
    test('la ida y vuelta con un IV aleatorio recupera el texto', () async {
      final key = SecretKeyBytes(Uint8List(32));
      final sealed = await seal(key, utf8Encode('hola'), 'ctx');
      expect(await open(key, sealed, 'ctx'), equals(utf8Encode('hola')));
    });

    test('dos cifrados del mismo texto no coinciden (IV aleatorio)', () async {
      final key = SecretKeyBytes(Uint8List(32));
      final a = await seal(key, utf8Encode('hola'), 'ctx');
      final b = await seal(key, utf8Encode('hola'), 'ctx');
      expect(a, isNot(b));
    });

    test('abrir con un AAD distinto falla', () async {
      final key = SecretKeyBytes(Uint8List(32));
      final sealed = await seal(key, utf8Encode('hola'), 'ctx');
      expect(() => open(key, sealed, 'otro'), throwsA(isA<DecryptError>()));
    });

    test('abrir con una clave distinta falla', () async {
      final sealed = await seal(
        SecretKeyBytes(Uint8List(32)),
        utf8Encode('hola'),
        'ctx',
      );
      final otherKey = SecretKeyBytes(Uint8List.fromList(List.filled(32, 1)));
      expect(() => open(otherKey, sealed, 'ctx'), throwsA(isA<DecryptError>()));
    });

    test(
      'abrir un texto cifrado con el cuerpo cifrado alterado falla',
      () async {
        final key = SecretKeyBytes(Uint8List(32));
        final sealed = await seal(key, utf8Encode('hola'), 'ctx');
        final parts = sealed.split('.');
        final ct = fromB64u(parts[2]);
        // Invierte un bit del primer byte del cuerpo cifrado (antes de la etiqueta GCM de 16
        // bytes). Se reconstruye con toB64u para que la base64url siga siendo canónica (si se
        // tocara el último carácter a mano, los bits de relleno podrían quedar a no-cero y
        // fromB64u lanzaría CryptoFormatError antes de llegar a descifrar: ver la prueba de más
        // abajo sobre ese caso).
        ct[0] ^= 0x01;
        final altered = '${parts[0]}.${parts[1]}.${toB64u(ct)}';
        expect(() => open(key, altered, 'ctx'), throwsA(isA<DecryptError>()));
      },
    );

    test('abrir un texto cifrado con la etiqueta GCM alterada falla', () async {
      final key = SecretKeyBytes(Uint8List(32));
      final sealed = await seal(key, utf8Encode('hola'), 'ctx');
      final parts = sealed.split('.');
      final ct = fromB64u(parts[2]);
      // Invierte un bit del último byte, dentro de la etiqueta GCM de 16 bytes.
      ct[ct.length - 1] ^= 0x01;
      final altered = '${parts[0]}.${parts[1]}.${toB64u(ct)}';
      expect(() => open(key, altered, 'ctx'), throwsA(isA<DecryptError>()));
    });

    test(
      'abrir con un cuerpo cifrado en base64url no canónica (bits de '
      'relleno a no-cero) lanza CryptoFormatError, no DecryptError',
      () {
        // "AB" decodifica como 1 byte (más "==" de relleno implícito): el segundo carácter
        // codifica ese byte más 4 bits de relleno que deben ser cero. 'B' (índice 1 del
        // alfabeto) los deja en 0001, no canónico, así que base64Url.decode lo rechaza antes de
        // llegar siquiera a intentar descifrar.
        expect(
          () => open(
            SecretKeyBytes(Uint8List(32)),
            'a1.AAAAAAAAAAAAAAAA.AB',
            'ctx',
          ),
          throwsA(isA<CryptoFormatError>()),
        );
      },
    );

    test(
      'abrir algo que no tiene el formato a1 falla con CryptoFormatError',
      () {
        expect(
          () => open(SecretKeyBytes(Uint8List(32)), 'no-es-sealed', 'ctx'),
          throwsA(isA<CryptoFormatError>()),
        );
      },
    );

    test('cifrar con un texto vacío y abrirlo recupera texto vacío', () async {
      final key = SecretKeyBytes(Uint8List(32));
      final sealed = await seal(key, Uint8List(0), 'ctx');
      expect(await open(key, sealed, 'ctx'), isEmpty);
    });

    test('abrir un sealed cuyo texto cifrado no llega a 16 bytes falla', () {
      final key = SecretKeyBytes(Uint8List(32));
      // "AA" decodifica a 1 byte: no alcanza para la etiqueta GCM de 16 bytes.
      expect(
        () => open(key, 'a1.AAAAAAAAAAAAAAAA.AA', 'ctx'),
        throwsA(isA<DecryptError>()),
      );
    });

    test(
      'abrir con una clave ya borrada lanza StateError, no DecryptError',
      () async {
        final key = SecretKeyBytes(Uint8List(32));
        final sealed = await seal(key, utf8Encode('hola'), 'ctx');
        key.dispose();
        expect(() => open(key, sealed, 'ctx'), throwsStateError);
      },
    );
  });

  group('sealWithIv', () {
    test('rechaza un IV que no mide 12 bytes', () {
      final key = SecretKeyBytes(Uint8List(32));
      expect(
        () => sealWithIv(key, utf8Encode('hola'), 'ctx', Uint8List(11)),
        throwsA(isA<CryptoFormatError>()),
      );
    });

    test('con el mismo IV produce siempre el mismo sealed', () async {
      final key = SecretKeyBytes(Uint8List(32));
      final iv = Uint8List(12);
      final a = await sealWithIv(key, utf8Encode('hola'), 'ctx', iv);
      final b = await sealWithIv(key, utf8Encode('hola'), 'ctx', iv);
      expect(a, b);
    });
  });
}
