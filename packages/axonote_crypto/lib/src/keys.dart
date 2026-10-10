import 'bytes.dart';
import 'sealed.dart';

/// Clave nueva (clave maestra o de un elemento): 32 bytes aleatorios.
SecretKeyBytes generateKeyBytes() => SecretKeyBytes(randomBytes(32));

/// Cifra una clave con otra.
Future<Sealed> wrap(SecretKeyBytes wrapping, SecretKeyBytes key, String aad) =>
    seal(wrapping, key.bytes, aad);

/// Lanza [DecryptError] o [CryptoFormatError] si la clave envolvente o el AAD no corresponden,
/// o [CryptoFormatError] si el resultado no mide 32 bytes.
Future<SecretKeyBytes> unwrap(
  SecretKeyBytes wrapping,
  Sealed sealed,
  String aad,
) async {
  final raw = await open(wrapping, sealed, aad);
  if (raw.length != 32)
    throw const CryptoFormatError('longitud de clave inválida');
  return SecretKeyBytes(raw);
}

/// Bytes de una clave en base64url (para el fragmento de la URL de un enlace público).
String exportKeyRaw(SecretKeyBytes key) => toB64u(key.bytes);

/// Importa una clave a partir de sus bytes en base64url. Lanza [CryptoFormatError] si no mide
/// 32 bytes.
SecretKeyBytes importKeyRaw(String raw) {
  final bytes = fromB64u(raw);
  if (bytes.length != 32)
    throw const CryptoFormatError('longitud de clave inválida');
  return SecretKeyBytes(bytes);
}
