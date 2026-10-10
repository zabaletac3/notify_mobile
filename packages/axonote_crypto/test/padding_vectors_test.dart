// Vector: contract/vectors/padding.json.
import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

void main() {
  final vector = loadVector('padding');
  final block = vector['block']! as int;
  final lengths = listOf(vector['lengths']);
  final unpad = vector['unpad']! as Map<String, Object?>;

  group('padding.json · lengths', () {
    for (final entry in lengths) {
      final input = entry['input']! as int;
      final padded = entry['padded']! as int;
      test('$input bytes → $padded', () {
        final result = pad(Uint8List(input), block: block);
        expect(result.length, padded);
      });
    }
  });

  test('padding.json · unpad', () {
    final paddedBytes = fromB64u(unpad['padded']! as String);
    expect(paddedBytes.length, unpad['paddedLength']);
    expect(unpadJson(paddedBytes), unpad['text']);
  });
}
