/// Formato criptográfico de AxoNote: a1, KDF, claves, relleno y clave de recuperación.
///
/// No se exporta `sealWithIv` (solo para vectores y pruebas): la app siempre usa [seal], que
/// genera un IV aleatorio. De `package:sodium` solo se exporta la clase propia `SodiumArgon2id`
/// (ver `argon2id_sodium.dart`); sus tipos internos (`SodiumSumo`, `CryptoPwhashAlgorithm`, etc.)
/// no salen de este paquete.
library;

export 'src/account_keys.dart';
export 'src/argon2id_sodium.dart' show SodiumArgon2id;
export 'src/bytes.dart'
    show
        CryptoFormatError,
        SecretKeyBytes,
        concatBytes,
        fromB64u,
        fromUtf8,
        randomBytes,
        timingSafeEqual,
        toB64u,
        utf8Encode;
export 'src/kdf.dart';
export 'src/keys.dart';
export 'src/note_codec.dart';
export 'src/padding.dart';
export 'src/recovery_key.dart';
export 'src/sealed.dart' show DecryptError, Sealed, isSealed, open, seal;
export 'src/share_codec.dart';
