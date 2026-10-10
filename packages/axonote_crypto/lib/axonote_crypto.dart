/// Formato criptográfico de AxoNote: a1, KDF, claves, relleno y clave de recuperación.
///
/// No se exporta `sealWithIv` (solo para vectores y pruebas): la app siempre usa [seal], que
/// genera un IV aleatorio. Tampoco se exporta `package:sodium`, para que quien solo necesite el
/// formato (por ejemplo para leer el contrato) no cargue la librería nativa.
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
