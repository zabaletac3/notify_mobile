import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Un texto cifrado, una clave o un formato tiene un formato inválido (no es un fallo de la
/// clave). Nunca lleva material secreto en [message].
class CryptoFormatError implements Exception {
  const CryptoFormatError([this.message = 'formato inválido']);

  final String message;

  @override
  String toString() => 'CryptoFormatError: $message';
}

final Random _secureRandom = Random.secure();

/// Bytes aleatorios criptográficamente seguros.
Uint8List randomBytes(int length) {
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = _secureRandom.nextInt(256);
  }
  return bytes;
}

Uint8List utf8Encode(String text) => Uint8List.fromList(utf8.encode(text));

/// Decodifica UTF-8 estricto: lanza [FormatException] ante una secuencia inválida.
String fromUtf8(Uint8List bytes) =>
    const Utf8Decoder(allowMalformed: false).convert(bytes);

/// Base64 URL-safe, sin relleno.
String toB64u(Uint8List bytes) => base64Url.encode(bytes).replaceAll('=', '');

final RegExp _b64uPattern = RegExp(r'^[A-Za-z0-9_-]*$');

Uint8List fromB64u(String text) {
  if (!_b64uPattern.hasMatch(text) || text.length % 4 == 1) {
    throw const CryptoFormatError();
  }
  final padLength = (4 - (text.length % 4)) % 4;
  try {
    return base64Url.decode(text + ('=' * padLength));
  } on FormatException {
    throw const CryptoFormatError();
  }
}

Uint8List concatBytes(List<Uint8List> parts) {
  final total = parts.fold<int>(0, (sum, part) => sum + part.length);
  final out = Uint8List(total);
  var offset = 0;
  for (final part in parts) {
    out.setRange(offset, offset + part.length, part);
    offset += part.length;
  }
  return out;
}

/// Compara en tiempo constante (para valores secretos).
bool timingSafeEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Bytes de una clave secreta. No tiene un `toString` útil (nunca imprime los bytes) y se puede
/// borrar con [dispose]: sobrescribe la memoria con ceros y olvida la clave. Usar después de
/// [dispose] lanza [StateError].
final class SecretKeyBytes {
  SecretKeyBytes(Uint8List bytes) : _bytes = bytes, length = bytes.length;

  Uint8List? _bytes;

  /// Longitud en bytes. Sigue disponible tras [dispose].
  final int length;

  bool get isDisposed => _bytes == null;

  /// Los bytes de la clave (sin copiar). Lanza [StateError] si ya se borró.
  Uint8List get bytes {
    final value = _bytes;
    if (value == null) throw StateError('la clave ya se borró');
    return value;
  }

  /// Sobrescribe los bytes con ceros y olvida la clave. Repetirlo no hace nada.
  void dispose() {
    final value = _bytes;
    if (value == null) return;
    value.fillRange(0, value.length, 0);
    _bytes = null;
  }

  @override
  String toString() => 'SecretKeyBytes($length B)';
}
