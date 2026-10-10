import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

void main() {
  group('isValidSlug', () {
    test('acepta 22 caracteres base64url', () {
      expect(isValidSlug(newSlug()), isTrue);
    });

    test('rechaza una longitud distinta', () {
      expect(isValidSlug('abc'), isFalse);
    });

    test('rechaza caracteres fuera del alfabeto', () {
      expect(isValidSlug('+' * 22), isFalse);
    });
  });

  group('newSlug', () {
    test('dos llamadas no coinciden', () {
      expect(newSlug(), isNot(newSlug()));
    });
  });

  group('shareKeyFromFragment', () {
    test('extrae la clave con el prefijo #k=', () {
      final key = 'A' * 43;
      expect(shareKeyFromFragment('#k=$key'), key);
    });

    test('extrae la clave sin el símbolo #', () {
      final key = 'A' * 43;
      expect(shareKeyFromFragment('k=$key'), key);
    });

    test('devuelve null si no hay fragmento', () {
      expect(shareKeyFromFragment(''), isNull);
    });

    test('devuelve null si la clave no mide 43 caracteres', () {
      expect(shareKeyFromFragment('#k=corta'), isNull);
    });
  });

  group('LinkPayload', () {
    test('ida y vuelta conserva título y contenido', () {
      const payload = LinkPayload(title: 't', content: 'c');
      final decoded = decodeLinkPayload(encodeLinkPayload(payload));
      expect(decoded.title, 't');
      expect(decoded.content, 'c');
    });

    test('rechaza un JSON al que le falta un campo', () {
      final bytes = pad(utf8Encode('{"title":"t"}'));
      expect(() => decodeLinkPayload(bytes), throwsA(isA<DecryptError>()));
    });

    test('rechaza un JSON con sintaxis inválida', () {
      final bytes = pad(utf8Encode('{no es json'));
      expect(() => decodeLinkPayload(bytes), throwsA(isA<DecryptError>()));
    });
  });

  group('sealLinkPayload/openLinkPayload', () {
    test('ida y vuelta con una clave y un slug', () async {
      final key = SecretKeyBytes(Uint8List(32));
      final slug = newSlug();
      const payload = LinkPayload(title: 't', content: 'c');
      final sealed = await sealLinkPayload(key, slug, payload);
      final opened = await openLinkPayload(key, slug, sealed);
      expect(opened.title, 't');
      expect(opened.content, 'c');
    });

    test('falla si se abre con un slug distinto (el AAD no coincide)', () async {
      final key = SecretKeyBytes(Uint8List(32));
      const payload = LinkPayload(title: 't', content: 'c');
      final sealed = await sealLinkPayload(key, newSlug(), payload);
      expect(() => openLinkPayload(key, newSlug(), sealed), throwsA(isA<DecryptError>()));
    });
  });
}
