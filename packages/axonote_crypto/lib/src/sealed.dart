import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'bytes.dart';

/// Texto cifrado con AES-256-GCM: `a1.<iv>.<ct>` (base64url; `ct` incluye la etiqueta de 16
/// bytes).
typedef Sealed = String;

/// La etiqueta GCM no coincide: clave incorrecta, datos asociados distintos o texto alterado.
class DecryptError implements Exception {
  const DecryptError([this.message = 'no se pudo descifrar']);

  final String message;

  @override
  String toString() => 'DecryptError: $message';
}

final RegExp _sealedPattern = RegExp(
  r'^a1\.[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]+$',
);
const int _ivBytes = 12;
const int _macBytes = 16;

final AesGcm _aesGcm = AesGcm.with256bits(nonceLength: _ivBytes);

bool isSealed(Object? value) =>
    value is String && _sealedPattern.hasMatch(value);

/// Cifra con un IV **dado** de 12 bytes. Solo lo usan los vectores de prueba compartidos
/// (`contract/vectors`) y las pruebas: permite cifrar de forma reproducible. La app usa [seal],
/// que genera un IV nuevo. No se re-exporta desde el paquete público (`axonote_crypto.dart`).
Future<Sealed> sealWithIv(
  SecretKeyBytes key,
  Uint8List plaintext,
  String aad,
  Uint8List iv,
) async {
  if (iv.length != _ivBytes) throw const CryptoFormatError('IV inválido');
  final box = await _aesGcm.encrypt(
    plaintext,
    secretKey: SecretKeyData(key.bytes),
    nonce: iv,
    aad: utf8Encode(aad),
  );
  final cipherText = box.cipherText;
  final ct = Uint8List(cipherText.length + _macBytes)
    ..setRange(0, cipherText.length, cipherText)
    ..setRange(cipherText.length, cipherText.length + _macBytes, box.mac.bytes);
  return 'a1.${toB64u(iv)}.${toB64u(ct)}';
}

/// Cifra con un IV aleatorio nuevo. `aad` (datos asociados) liga el texto a su contexto —cuenta,
/// tipo e id—: si el servidor lo mueve a otro sitio, [open] falla.
Future<Sealed> seal(SecretKeyBytes key, Uint8List plaintext, String aad) =>
    sealWithIv(key, plaintext, aad, randomBytes(_ivBytes));

/// Lanza [CryptoFormatError] si `sealed` no tiene el formato `a1.<iv>.<ct>`, o [DecryptError] si
/// la clave, el AAD o el texto no corresponden.
Future<Uint8List> open(SecretKeyBytes key, Sealed sealed, String aad) async {
  if (!isSealed(sealed)) throw const CryptoFormatError();
  final parts = sealed.split('.');
  final ct = fromB64u(parts[2]);
  try {
    final iv = fromB64u(parts[1]);
    if (ct.length < _macBytes) throw const DecryptError();
    final cipherText = ct.sublist(0, ct.length - _macBytes);
    final mac = Mac(ct.sublist(ct.length - _macBytes));
    final plain = await _aesGcm.decrypt(
      SecretBox(cipherText, nonce: iv, mac: mac),
      secretKey: SecretKeyData(key.bytes),
      aad: utf8Encode(aad),
    );
    return Uint8List.fromList(plain);
  } catch (_) {
    throw const DecryptError();
  }
}
