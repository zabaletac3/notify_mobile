import 'dart:typed_data';

import 'bytes.dart';

/// Alfabeto Crockford base32 (sin I, L, O, U) + símbolos de control de Crockford.
const String _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const String _checkSymbols = '$_alphabet*~\$=U';
const int _keyBytes = 32;
const int _chars = 52; // ceil(256 / 5)

Uint8List generateRecoveryKey() => randomBytes(_keyBytes);

BigInt _toBigInt(Uint8List bytes) {
  var n = BigInt.zero;
  for (final byte in bytes) {
    n = (n << 8) | BigInt.from(byte);
  }
  return n;
}

/// Texto legible: 52 caracteres base32 + 1 de control, en grupos de 4 separados por «-».
String formatRecoveryKey(Uint8List key) {
  if (key.length != _keyBytes)
    throw const CryptoFormatError('longitud inválida');
  final n = _toBigInt(key) << 4; // 256 bits → 260 bits (52 × 5)
  final buffer = StringBuffer();
  for (var i = _chars - 1; i >= 0; i--) {
    buffer.write(_alphabet[((n >> (i * 5)) & BigInt.from(31)).toInt()]);
  }
  buffer.write(_checkSymbols[(_toBigInt(key) % BigInt.from(37)).toInt()]);
  final text = buffer.toString();
  final groups = <String>[];
  for (var i = 0; i < text.length; i += 4) {
    final end = i + 4 > text.length ? text.length : i + 4;
    groups.add(text.substring(i, end));
  }
  return groups.join('-');
}

/// Lee lo que escribió una persona: tolera minúsculas, espacios, guiones y O→0, I/L→1.
Uint8List parseRecoveryKey(String text) {
  final clean = text
      .toUpperCase()
      .replaceAll(RegExp(r'[\s-]'), '')
      .replaceAll('O', '0')
      .replaceAll(RegExp('[IL]'), '1');
  if (clean.length != _chars + 1)
    throw const CryptoFormatError('longitud inválida');

  var n = BigInt.zero;
  for (var i = 0; i < _chars; i++) {
    final value = _alphabet.indexOf(clean[i]);
    if (value < 0) throw const CryptoFormatError('carácter inválido');
    n = (n << 5) | BigInt.from(value);
  }
  if ((n & BigInt.from(15)) != BigInt.zero) {
    throw const CryptoFormatError('relleno inválido');
  }
  n >>= 4;

  final key = Uint8List(_keyBytes);
  for (var i = _keyBytes - 1; i >= 0; i--) {
    key[i] = (n & BigInt.from(255)).toInt();
    n >>= 8;
  }
  if (_checkSymbols[(_toBigInt(key) % BigInt.from(37)).toInt()] !=
      clean[_chars]) {
    throw const CryptoFormatError('dígito de control incorrecto');
  }
  return key;
}
