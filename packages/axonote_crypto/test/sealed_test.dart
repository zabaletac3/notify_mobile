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
      final sealed = await seal(SecretKeyBytes(Uint8List(32)), utf8Encode('hola'), 'ctx');
      final otherKey = SecretKeyBytes(Uint8List.fromList(List.filled(32, 1)));
      expect(() => open(otherKey, sealed, 'ctx'), throwsA(isA<DecryptError>()));
    });

    test('abrir un texto cifrado alterado falla', () async {
      final key = SecretKeyBytes(Uint8List(32));
      final sealed = await seal(key, utf8Encode('hola'), 'ctx');
      final parts = sealed.split('.');
      final altered = '${parts[0]}.${parts[1]}.${parts[2].substring(0, parts[2].length - 1)}${parts[2].endsWith('A') ? 'B' : 'A'}';
      expect(() => open(key, altered, 'ctx'), throwsA(isA<DecryptError>()));
    });

    test('abrir algo que no tiene el formato a1 falla con CryptoFormatError', () {
      expect(() => open(SecretKeyBytes(Uint8List(32)), 'no-es-sealed', 'ctx'), throwsA(isA<CryptoFormatError>()));
    });

    test('cifrar con un texto vacío y abrirlo recupera texto vacío', () async {
      final key = SecretKeyBytes(Uint8List(32));
      final sealed = await seal(key, Uint8List(0), 'ctx');
      expect(await open(key, sealed, 'ctx'), isEmpty);
    });
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
