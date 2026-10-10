import 'dart:convert';
import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

Uint8List _jsonBytes(Object? value) => pad(utf8Encode(jsonEncode(value)));

void main() {
  group('NotePayload', () {
    test('ida y vuelta conserva los campos', () {
      const payload = NotePayload(
        title: 't',
        content: 'c',
        tags: ['a', 'b'],
        pinned: true,
      );
      expect(decodeNotePayload(encodeNotePayload(payload)).title, 't');
      expect(decodeNotePayload(encodeNotePayload(payload)).content, 'c');
      expect(decodeNotePayload(encodeNotePayload(payload)).tags, ['a', 'b']);
      expect(decodeNotePayload(encodeNotePayload(payload)).pinned, isTrue);
    });

    test('rechaza un JSON con sintaxis inválida', () {
      expect(
        () => decodeNotePayload(pad(utf8Encode('{no es json'))),
        throwsA(isA<DecryptError>()),
      );
    });

    test('rechaza un JSON que no es un objeto', () {
      expect(
        () => decodeNotePayload(_jsonBytes([1, 2, 3])),
        throwsA(isA<DecryptError>()),
      );
    });

    test('rechaza cuando falta un campo', () {
      expect(
        () => decodeNotePayload(
          _jsonBytes({'title': 't', 'content': 'c', 'tags': <String>[]}),
        ),
        throwsA(isA<DecryptError>()),
      );
    });

    test('rechaza "pinned" con el tipo equivocado', () {
      expect(
        () => decodeNotePayload(
          _jsonBytes({
            'title': 't',
            'content': 'c',
            'tags': <String>[],
            'pinned': 'si',
          }),
        ),
        throwsA(isA<DecryptError>()),
      );
    });

    test('rechaza "tags" con un elemento que no es texto', () {
      expect(
        () => decodeNotePayload(
          _jsonBytes({
            'title': 't',
            'content': 'c',
            'tags': [1],
            'pinned': false,
          }),
        ),
        throwsA(isA<DecryptError>()),
      );
    });
  });

  group('FolderPayload', () {
    test('ida y vuelta conserva el nombre', () {
      const payload = FolderPayload(name: 'Recetas');
      expect(decodeFolderPayload(encodeFolderPayload(payload)).name, 'Recetas');
    });

    test('rechaza cuando falta el nombre', () {
      expect(
        () => decodeFolderPayload(_jsonBytes({})),
        throwsA(isA<DecryptError>()),
      );
    });

    test('rechaza un JSON con sintaxis inválida', () {
      expect(
        () => decodeFolderPayload(pad(utf8Encode('{no es json'))),
        throwsA(isA<DecryptError>()),
      );
    });

    test('rechaza un nombre con el tipo equivocado', () {
      expect(
        () => decodeFolderPayload(_jsonBytes({'name': 1})),
        throwsA(isA<DecryptError>()),
      );
    });
  });

  group('sealNotePayload/openNotePayload', () {
    test('ida y vuelta con una clave', () async {
      final key = SecretKeyBytes(Uint8List(32));
      const payload = NotePayload(
        title: 't',
        content: 'c',
        tags: [],
        pinned: false,
      );
      final sealed = await sealNotePayload(key, payload, 'aad');
      final opened = await openNotePayload(key, sealed, 'aad');
      expect(opened.title, 't');
    });
  });

  group('sealFolderPayload/openFolderPayload', () {
    test('ida y vuelta con una clave', () async {
      final key = SecretKeyBytes(Uint8List(32));
      const payload = FolderPayload(name: 'Recetas');
      final sealed = await sealFolderPayload(key, payload, 'aad');
      final opened = await openFolderPayload(key, sealed, 'aad');
      expect(opened.name, 'Recetas');
    });
  });
}
