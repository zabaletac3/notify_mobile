// Vector: contract/vectors/recovery-key.json.
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

import 'support/vectors.dart';

void main() {
  final vector = loadVector('recovery-key');
  final cases = listOf(vector['cases']);
  final tolerant = listOf(vector['tolerant']);
  final invalid = listOf(vector['invalid']);

  group('recovery-key.json · cases', () {
    for (final case_ in cases) {
      final name = case_['name']! as String;
      final bytes = fromB64u(case_['bytes']! as String);
      final text = case_['text']! as String;

      test('$name · formatRecoveryKey', () {
        expect(formatRecoveryKey(bytes), text);
      });

      test('$name · parseRecoveryKey', () {
        expect(parseRecoveryKey(text), equals(bytes));
      });
    }
  });

  group('recovery-key.json · tolerant', () {
    for (final case_ in tolerant) {
      final name = case_['name']! as String;
      test(name, () {
        expect(parseRecoveryKey(case_['text']! as String), equals(fromB64u(case_['bytes']! as String)));
      });
    }
  });

  group('recovery-key.json · invalid', () {
    for (final case_ in invalid) {
      final name = case_['name']! as String;
      test(name, () {
        expect(() => parseRecoveryKey(case_['text']! as String), throwsA(isA<CryptoFormatError>()));
      });
    }
  });
}
