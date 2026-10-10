// Operaciones con las claves de una cuenta. Son funciones puras sobre contraseñas y paquetes de
// claves: no guardan nada ni conocen la interfaz. La contraseña y las claves nunca salen de aquí
// hacia el servidor; solo `authKey`, `recoveryAuth` y las claves ya cifradas.
//
// Este paquete no depende de `axonote_domain` (ver plan §4.2): `userId` es el identificador tal
// cual (UUID v7 generado en la capa de dominio) y `KeyBundle` es una copia local del tipo que
// guarda el servidor.

import 'dart:typed_data';

import 'bytes.dart';
import 'kdf.dart';
import 'keys.dart';
import 'recovery_key.dart';
import 'sealed.dart';

/// Qué cifra cada clave maestra guardada (`apunte/v1/mk/{userId}/{kind}`).
enum MasterKeyKind { password, recovery, device }

/// Datos asociados (AAD) con los que se cifra la clave maestra, ligados a la cuenta y a quién la
/// abre.
String masterKeyAad(String userId, MasterKeyKind kind) =>
    'apunte/v1/mk/$userId/${kind.name}';

/// Lo que el servidor guarda de las claves de una cuenta. Nada de esto permite descifrar sin la
/// contraseña o la clave de recuperación.
class KeyBundle {
  const KeyBundle({
    required this.kdf,
    required this.wrappedMasterKey,
    required this.recoveryWrappedMasterKey,
    required this.keysVersion,
  });

  final KdfParams kdf;

  /// Clave maestra cifrada con la clave derivada de la contraseña
  /// (AAD `apunte/v1/mk/{userId}/password`).
  final Sealed wrappedMasterKey;

  /// La misma clave maestra, cifrada con la clave de recuperación
  /// (AAD `apunte/v1/mk/{userId}/recovery`).
  final Sealed recoveryWrappedMasterKey;

  /// Sube al cambiar la contraseña o la clave de recuperación.
  final int keysVersion;

  KeyBundle copyWith({
    KdfParams? kdf,
    Sealed? wrappedMasterKey,
    Sealed? recoveryWrappedMasterKey,
    int? keysVersion,
  }) => KeyBundle(
    kdf: kdf ?? this.kdf,
    wrappedMasterKey: wrappedMasterKey ?? this.wrappedMasterKey,
    recoveryWrappedMasterKey:
        recoveryWrappedMasterKey ?? this.recoveryWrappedMasterKey,
    keysVersion: keysVersion ?? this.keysVersion,
  );
}

class NewAccountKeys {
  const NewAccountKeys({
    required this.userId,
    required this.authKey,
    required this.recoveryAuth,
    required this.keys,
    required this.masterKey,
    required this.recoveryKey,
  });

  final String userId;

  /// Prueba de la contraseña para el servidor.
  final String authKey;

  /// Prueba de la clave de recuperación para el servidor.
  final String recoveryAuth;
  final KeyBundle keys;
  final SecretKeyBytes masterKey;

  /// La clave de recuperación, tal como se muestra a la persona. Se enseña una sola vez.
  final String recoveryKey;
}

/// Claves de una cuenta nueva (o de una que se reinicia sin conservar las notas). `userId` lo
/// genera quien llama (`axonote_domain`, UUID v7): este paquete no depende del dominio.
Future<NewAccountKeys> createAccountKeys({
  required String password,
  required String userId,
  required Argon2idDeriver argon2id,
  KdfBase kdfBase = defaultKdf,
  // Solo para pruebas: permite forzar un fallo después de generar la clave maestra, sin tocar
  // `deriveFromRecoveryKey` en producción (que nunca falla con bytes válidos).
  Future<RecoveryDerivedKeys> Function(Uint8List recoveryBytes) deriveRecovery =
      deriveFromRecoveryKey,
}) async {
  final kdf = newKdfParams(base: kdfBase);
  final derived = await deriveFromPassword(password, kdf, argon2id);
  try {
    final masterKey = generateKeyBytes();
    try {
      final recoveryBytes = generateRecoveryKey();
      try {
        final recoveryDerived = await deriveRecovery(recoveryBytes);
        try {
          final wrappedMasterKey = await wrap(
            derived.kek,
            masterKey,
            masterKeyAad(userId, MasterKeyKind.password),
          );
          final recoveryWrappedMasterKey = await wrap(
            recoveryDerived.rkWrap,
            masterKey,
            masterKeyAad(userId, MasterKeyKind.recovery),
          );
          return NewAccountKeys(
            userId: userId,
            authKey: derived.authKey,
            recoveryAuth: recoveryDerived.recoveryAuth,
            masterKey: masterKey,
            recoveryKey: formatRecoveryKey(recoveryBytes),
            keys: KeyBundle(
              kdf: kdf,
              wrappedMasterKey: wrappedMasterKey,
              recoveryWrappedMasterKey: recoveryWrappedMasterKey,
              keysVersion: 1,
            ),
          );
        } finally {
          recoveryDerived.rkWrap.dispose();
        }
      } finally {
        recoveryBytes.fillRange(0, recoveryBytes.length, 0);
      }
    } catch (_) {
      // Si algo falla tras generar la clave maestra, nunca se devuelve: se borra aquí.
      masterKey.dispose();
      rethrow;
    }
  } finally {
    derived.kek.dispose();
  }
}

/// Lo que el servidor necesita para comprobar la contraseña sin conocerla.
Future<String> deriveAuthKey(
  String password,
  KdfParams kdf,
  Argon2idDeriver argon2id,
) async {
  final derived = await deriveFromPassword(password, kdf, argon2id);
  derived.kek.dispose();
  return derived.authKey;
}

class UnlockedKeys {
  const UnlockedKeys({required this.masterKey, required this.authKey});

  final SecretKeyBytes masterKey;
  final String authKey;
}

/// Abre la clave maestra con la contraseña. Lanza [DecryptError] si la contraseña no es la de la
/// cuenta.
Future<UnlockedKeys> unlockWithPassword({
  required String password,
  required String userId,
  required KeyBundle keys,
  required Argon2idDeriver argon2id,
}) async {
  final derived = await deriveFromPassword(password, keys.kdf, argon2id);
  try {
    final masterKey = await unwrap(
      derived.kek,
      keys.wrappedMasterKey,
      masterKeyAad(userId, MasterKeyKind.password),
    );
    return UnlockedKeys(masterKey: masterKey, authKey: derived.authKey);
  } finally {
    derived.kek.dispose();
  }
}

class PasswordChangeKeys {
  const PasswordChangeKeys({
    required this.currentAuthKey,
    required this.newAuthKey,
    required this.keys,
    required this.masterKey,
  });

  final String currentAuthKey;
  final String newAuthKey;
  final KeyBundle keys;
  final SecretKeyBytes masterKey;
}

/// Misma clave maestra, cifrada con la contraseña nueva. Las notas no se vuelven a cifrar.
Future<PasswordChangeKeys> changePasswordKeys({
  required String currentPassword,
  required String newPassword,
  required String userId,
  required KeyBundle current,
  required Argon2idDeriver argon2id,
  KdfBase kdfBase = defaultKdf,
}) async {
  final unlocked = await unlockWithPassword(
    password: currentPassword,
    userId: userId,
    keys: current,
    argon2id: argon2id,
  );
  try {
    final kdf = newKdfParams(base: kdfBase);
    final derived = await deriveFromPassword(newPassword, kdf, argon2id);
    try {
      final wrappedMasterKey = await wrap(
        derived.kek,
        unlocked.masterKey,
        masterKeyAad(userId, MasterKeyKind.password),
      );
      return PasswordChangeKeys(
        currentAuthKey: unlocked.authKey,
        newAuthKey: derived.authKey,
        masterKey: unlocked.masterKey,
        keys: current.copyWith(
          kdf: kdf,
          wrappedMasterKey: wrappedMasterKey,
          keysVersion: current.keysVersion + 1,
        ),
      );
    } finally {
      derived.kek.dispose();
    }
  } catch (_) {
    // Si algo falla tras desbloquear con la contraseña actual, la clave maestra nunca se
    // devuelve: se borra aquí.
    unlocked.masterKey.dispose();
    rethrow;
  }
}

class RecoveredKeys {
  const RecoveredKeys({
    required this.newAuthKey,
    required this.recoveryAuth,
    required this.keys,
    required this.masterKey,
  });

  final String newAuthKey;
  final String recoveryAuth;
  final KeyBundle keys;
  final SecretKeyBytes masterKey;
}

/// Restablece la contraseña conservando las notas: abre la clave maestra con la clave de
/// recuperación y la vuelve a cifrar con la contraseña nueva. Lanza [CryptoFormatError] si la
/// clave está mal escrita y [DecryptError] si no es la de la cuenta.
Future<RecoveredKeys> recoverWithRecoveryKey({
  required String recoveryKeyText,
  required String newPassword,
  required String userId,
  required Sealed recoveryWrappedMasterKey,
  required Argon2idDeriver argon2id,
  KdfBase kdfBase = defaultKdf,
}) async {
  final recoveryBytes = parseRecoveryKey(recoveryKeyText);
  try {
    final recoveryDerived = await deriveFromRecoveryKey(recoveryBytes);
    try {
      final masterKey = await unwrap(
        recoveryDerived.rkWrap,
        recoveryWrappedMasterKey,
        masterKeyAad(userId, MasterKeyKind.recovery),
      );
      try {
        final kdf = newKdfParams(base: kdfBase);
        final derived = await deriveFromPassword(newPassword, kdf, argon2id);
        try {
          final wrappedMasterKey = await wrap(
            derived.kek,
            masterKey,
            masterKeyAad(userId, MasterKeyKind.password),
          );
          return RecoveredKeys(
            newAuthKey: derived.authKey,
            recoveryAuth: recoveryDerived.recoveryAuth,
            masterKey: masterKey,
            keys: KeyBundle(
              kdf: kdf,
              wrappedMasterKey: wrappedMasterKey,
              recoveryWrappedMasterKey: recoveryWrappedMasterKey,
              keysVersion: 0, // lo fija el servidor
            ),
          );
        } finally {
          derived.kek.dispose();
        }
      } catch (_) {
        // Si algo falla tras abrir la clave maestra con la clave de recuperación, nunca se
        // devuelve: se borra aquí.
        masterKey.dispose();
        rethrow;
      }
    } finally {
      recoveryDerived.rkWrap.dispose();
    }
  } finally {
    recoveryBytes.fillRange(0, recoveryBytes.length, 0);
  }
}

class RotatedRecovery {
  const RotatedRecovery({
    required this.authKey,
    required this.recoveryAuth,
    required this.recoveryWrappedMasterKey,
    required this.recoveryKey,
  });

  final String authKey;
  final String recoveryAuth;
  final Sealed recoveryWrappedMasterKey;

  /// La clave nueva, tal como se muestra.
  final String recoveryKey;
}

/// Nueva clave de recuperación para la misma clave maestra. Pide la contraseña para abrirla.
Future<RotatedRecovery> rotateRecoveryKeys({
  required String password,
  required String userId,
  required KeyBundle keys,
  required Argon2idDeriver argon2id,
}) async {
  final unlocked = await unlockWithPassword(
    password: password,
    userId: userId,
    keys: keys,
    argon2id: argon2id,
  );
  try {
    final recoveryBytes = generateRecoveryKey();
    try {
      final recoveryDerived = await deriveFromRecoveryKey(recoveryBytes);
      try {
        final wrapped = await wrap(
          recoveryDerived.rkWrap,
          unlocked.masterKey,
          masterKeyAad(userId, MasterKeyKind.recovery),
        );
        return RotatedRecovery(
          authKey: unlocked.authKey,
          recoveryAuth: recoveryDerived.recoveryAuth,
          recoveryKey: formatRecoveryKey(recoveryBytes),
          recoveryWrappedMasterKey: wrapped,
        );
      } finally {
        recoveryDerived.rkWrap.dispose();
      }
    } finally {
      recoveryBytes.fillRange(0, recoveryBytes.length, 0);
    }
  } finally {
    unlocked.masterKey.dispose();
  }
}
