import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import 'kdf.dart';

/// Argon2id con libsodium (`crypto_pwhash`, decisión D11 del plan). libsodium fija el
/// paralelismo en 1; por eso [Argon2idDeriver] no lo recibe, y [deriveFromPassword] ya rechaza
/// con [KdfUnsupported] cualquier parámetro con `parallelism != 1` antes de llegar aquí.
///
/// Esta clase solo calcula: ejecutarla en un isolate de trabajo (plan §4.4) es responsabilidad
/// de quien la instancia (la app, en su raíz de composición). Las pruebas de este paquete la
/// usan directamente, sin isolate, porque los vectores de `kdf.json` ya usan parámetros ligeros.
class SodiumArgon2id implements Argon2idDeriver {
  SodiumArgon2id(this._sodium);

  /// Carga la librería nativa (vía los hooks de compilación del paquete `sodium`). La firma de
  /// `SodiumSumoInit.init()` es `FutureOr<SodiumSumo>` para el analizador (la variante de
  /// respaldo sin FFI es asíncrona); la de FFI es síncrona en ejecución, pero `load` se mantiene
  /// asíncrono para valer en ambos casos.
  static Future<SodiumArgon2id> load() async =>
      SodiumArgon2id(await SodiumSumoInit.init());

  final SodiumSumo _sodium;

  static const int _outputLength = 32;

  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required int memoryKiB,
    required int iterations,
  }) async {
    final key = _sodium.crypto.pwhash.callRaw(
      outLen: _outputLength,
      password: Int8List.sublistView(password),
      salt: salt,
      opsLimit: iterations,
      memLimit: memoryKiB * 1024,
      alg: CryptoPwhashAlgorithm.argon2id13,
    );
    try {
      return key.extractBytes();
    } finally {
      key.dispose();
    }
  }
}
