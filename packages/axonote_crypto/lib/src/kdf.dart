import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'bytes.dart';

/// El servidor pide parámetros de Argon2id que este cliente no sabe calcular: `alg` distinto de
/// `argon2id` o `parallelism` distinto de 1 (libsodium lo fija en 1; ver decisión D11 del plan).
/// Nunca se intenta derivar en ese caso.
class KdfUnsupported implements Exception {
  const KdfUnsupported([this.message = 'parámetros de KDF no compatibles']);

  final String message;

  @override
  String toString() => 'KdfUnsupported: $message';
}

/// Parámetros de derivación de una cuenta. Se guardan en el servidor para poder subirlos en el
/// futuro.
class KdfParams {
  const KdfParams({
    required this.alg,
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.salt,
  });

  final String alg;
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  /// 16 bytes aleatorios en base64url. No depende del correo.
  final String salt;
}

/// Parámetros de Argon2id sin la sal (se genera una nueva en cada derivación).
typedef KdfBase = ({int memoryKiB, int iterations, int parallelism});

const KdfBase defaultKdf = (memoryKiB: 65536, iterations: 3, parallelism: 1);

/// Parámetros ligeros (1 MiB, 1 iteración): solo para desarrollo y pruebas, nunca en producción.
const KdfBase lightKdf = (memoryKiB: 1024, iterations: 1, parallelism: 1);

const int _saltBytes = 16;

KdfParams newKdfParams({KdfBase base = defaultKdf}) => KdfParams(
  alg: 'argon2id',
  memoryKiB: base.memoryKiB,
  iterations: base.iterations,
  parallelism: base.parallelism,
  salt: toB64u(randomBytes(_saltBytes)),
);

/// Calcula Argon2id. La implementación con libsodium vive en este paquete (`SodiumArgon2id`);
/// ejecutarla en un isolate es responsabilidad de quien llama (ver plan §4.4): este paquete solo
/// calcula.
abstract class Argon2idDeriver {
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required int memoryKiB,
    required int iterations,
  });
}

/// `authKey` (para el servidor) y `kek` (para la clave maestra).
class DerivedKeys {
  const DerivedKeys({required this.authKey, required this.kek});

  /// Lo que se envía al servidor en lugar de la contraseña (base64url).
  final String authKey;

  /// Clave que envuelve la clave maestra. No sale del cliente.
  final SecretKeyBytes kek;
}

/// `recoveryAuth` (para el servidor) y `rkWrap` (para la clave maestra).
class RecoveryDerivedKeys {
  const RecoveryDerivedKeys({required this.recoveryAuth, required this.rkWrap});

  final String recoveryAuth;
  final SecretKeyBytes rkWrap;
}

final Uint8List _zeroSalt32 = Uint8List(32);

Future<String> _hkdfBits(Uint8List ikm, String info) async {
  final derived = await Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  ).deriveKey(secretKey: SecretKeyData(ikm), nonce: _zeroSalt32, info: utf8Encode(info));
  return toB64u(Uint8List.fromList(derived.bytes));
}

Future<SecretKeyBytes> _hkdfKeyBytes(Uint8List ikm, String info) async {
  final derived = await Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  ).deriveKey(secretKey: SecretKeyData(ikm), nonce: _zeroSalt32, info: utf8Encode(info));
  return SecretKeyBytes(Uint8List.fromList(derived.bytes));
}

/// Contraseña → `authKey` y `kek`. Nunca viaja la contraseña. Lanza [KdfUnsupported] si el
/// servidor pide parámetros que este cliente no sabe calcular.
Future<DerivedKeys> deriveFromPassword(
  String password,
  KdfParams params,
  Argon2idDeriver argon2id,
) async {
  if (params.alg != 'argon2id' || params.parallelism != 1) {
    throw const KdfUnsupported();
  }
  final stretched = await argon2id.derive(
    password: utf8Encode(unorm.nfkc(password)),
    salt: fromB64u(params.salt),
    memoryKiB: params.memoryKiB,
    iterations: params.iterations,
  );
  try {
    final authKey = await _hkdfBits(stretched, 'apunte/v1/auth');
    final kek = await _hkdfKeyBytes(stretched, 'apunte/v1/kek');
    return DerivedKeys(authKey: authKey, kek: kek);
  } finally {
    stretched.fillRange(0, stretched.length, 0);
  }
}

/// Clave de recuperación → prueba para el servidor y clave que envuelve la clave maestra.
Future<RecoveryDerivedKeys> deriveFromRecoveryKey(Uint8List recoveryKey) async {
  final recoveryAuth = await _hkdfBits(recoveryKey, 'apunte/v1/recovery-auth');
  final rkWrap = await _hkdfKeyBytes(recoveryKey, 'apunte/v1/recovery-kek');
  return RecoveryDerivedKeys(recoveryAuth: recoveryAuth, rkWrap: rkWrap);
}
