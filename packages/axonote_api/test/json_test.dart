import 'package:axonote_api/axonote_api.dart';
import 'package:test/test.dart';

void main() {
  group('JsonReader', () {
    test('child exige el campo', () {
      final reader = JsonReader(<String, Object?>{'a': 1});
      expect(reader.child('a').asInt(), 1);
      expect(() => reader.child('b'), throwsA(isA<JsonFormatException>()));
    });

    test('optional devuelve null si falta o si es null', () {
      final reader = JsonReader(<String, Object?>{'a': 1, 'b': null});
      expect(reader.optional('a')!.asInt(), 1);
      expect(reader.optional('b'), isNull);
      expect(reader.optional('c'), isNull);
    });

    test('asString / asBool / asInt fallan con el tipo equivocado', () {
      expect(
        () => JsonReader(1).asString(),
        throwsA(isA<JsonFormatException>()),
      );
      expect(
        () => JsonReader('sí').asBool(),
        throwsA(isA<JsonFormatException>()),
      );
      expect(
        () => JsonReader(1.5).asInt(),
        throwsA(isA<JsonFormatException>()),
      );
      expect(
        () => JsonReader('1').asInt(),
        throwsA(isA<JsonFormatException>()),
      );
    });

    test('asNullableString y asNullableDateTime admiten null', () {
      expect(JsonReader(null).asNullableString(), isNull);
      expect(JsonReader('x').asNullableString(), 'x');
      expect(JsonReader(null).asNullableDateTime(), isNull);
      expect(
        JsonReader('2026-10-10T10:00:00.000Z').asNullableDateTime()!.year,
        2026,
      );
      expect(
        () => JsonReader('no-fecha').asDateTime(),
        throwsA(isA<JsonFormatException>()),
      );
    });

    test('asList y asMap validan el tipo', () {
      final items = JsonReader(<Object?>[1, 2]).asList();
      expect(items.map((item) => item.asInt()), <int>[1, 2]);
      expect(
        () => JsonReader('x').asList(),
        throwsA(isA<JsonFormatException>()),
      );
      expect(JsonReader(<String, Object?>{'k': 1}).asMap(), <String, Object?>{
        'k': 1,
      });
      expect(
        () => JsonReader('x').asMap(),
        throwsA(isA<JsonFormatException>()),
      );
    });

    test('la ruta del error nombra el campo y no el valor', () {
      final reader = JsonReader(<String, Object?>{
        'outer': <String, Object?>{
          'inner': <String, Object?>{'n': 'boom'},
        },
      });
      try {
        reader.child('outer').child('inner').child('n').asInt();
        fail('debería lanzar');
      } on JsonFormatException catch (e) {
        expect(e.path, r'$.outer.inner.n');
        expect(e.toString(), isNot(contains('boom')));
        expect(e.toString(), 'JsonFormatException(\$.outer.inner.n)');
      }
    });
  });
}
