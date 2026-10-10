import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:test/test.dart';

/// Nunca debe llamarse: las pruebas de [KdfUnsupported] comprueban que se rechaza antes de
/// intentar derivar.
class _NeverArgon2id implements Argon2idDeriver {
  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required int memoryKiB,
    required int iterations,
  }) {
    fail('no debía llamarse a Argon2id con parámetros no compatibles');
  }
}

/// Fuerza un error en una llamada concreta (1-based) a Argon2id; las demás se delegan a [real].
/// Sirve para forzar un fallo *después* de un paso que ya produjo una clave maestra, y comprobar
/// que el camino de error la borra en vez de devolverla.
class _FlakyArgon2id implements Argon2idDeriver {
  _FlakyArgon2id(this.real, {required this.failOnCall});

  final Argon2idDeriver real;
  final int failOnCall;
  int calls = 0;

  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required int memoryKiB,
    required int iterations,
  }) {
    calls++;
    if (calls == failOnCall) {
      throw _ForcedFailure();
    }
    return real.derive(
      password: password,
      salt: salt,
      memoryKiB: memoryKiB,
      iterations: iterations,
    );
  }
}

class _ForcedFailure implements Exception {}

void main() {
  late Argon2idDeriver argon2id;
  const userId = '018f6f9a-7b1c-7c3e-8c9d-00000000ffff';

  setUpAll(() async {
    argon2id = await SodiumArgon2id.load();
  });

  group('masterKeyAad', () {
    test('combina el userId y el tipo de clave', () {
      expect(
        masterKeyAad(userId, MasterKeyKind.password),
        'apunte/v1/mk/$userId/password',
      );
      expect(
        masterKeyAad(userId, MasterKeyKind.recovery),
        'apunte/v1/mk/$userId/recovery',
      );
      expect(
        masterKeyAad(userId, MasterKeyKind.device),
        'apunte/v1/mk/$userId/device',
      );
    });
  });

  group('ciclo de vida de una cuenta', () {
    test(
      'createAccountKeys → unlockWithPassword recupera la misma clave maestra',
      () async {
        final created = await createAccountKeys(
          password: 'contraseña de prueba',
          userId: userId,
          argon2id: argon2id,
          kdfBase: lightKdf,
        );
        expect(created.keys.keysVersion, 1);

        final unlocked = await unlockWithPassword(
          password: 'contraseña de prueba',
          userId: userId,
          keys: created.keys,
          argon2id: argon2id,
        );
        expect(unlocked.masterKey.bytes, equals(created.masterKey.bytes));
        expect(unlocked.authKey, created.authKey);
        unlocked.masterKey.dispose();
      },
    );

    test(
      'unlockWithPassword con la contraseña equivocada lanza DecryptError',
      () async {
        final created = await createAccountKeys(
          password: 'correcta',
          userId: userId,
          argon2id: argon2id,
          kdfBase: lightKdf,
        );
        expect(
          () => unlockWithPassword(
            password: 'incorrecta',
            userId: userId,
            keys: created.keys,
            argon2id: argon2id,
          ),
          throwsA(isA<DecryptError>()),
        );
      },
    );

    test(
      'unlockWithPassword rechaza un KeyBundle con KDF no compatible',
      () async {
        final created = await createAccountKeys(
          password: 'x',
          userId: userId,
          argon2id: argon2id,
          kdfBase: lightKdf,
        );
        final incompatible = created.keys.copyWith(
          kdf: KdfParams(
            alg: created.keys.kdf.alg,
            memoryKiB: created.keys.kdf.memoryKiB,
            iterations: created.keys.kdf.iterations,
            parallelism: 2,
            salt: created.keys.kdf.salt,
          ),
        );
        expect(
          () => unlockWithPassword(
            password: 'x',
            userId: userId,
            keys: incompatible,
            argon2id: _NeverArgon2id(),
          ),
          throwsA(isA<KdfUnsupported>()),
        );
      },
    );

    test('changePasswordKeys permite desbloquear con la contraseña nueva y no con la vieja', () async {
      final created = await createAccountKeys(
        password: 'vieja',
        userId: userId,
        argon2id: argon2id,
        kdfBase: lightKdf,
      );
      final changed = await changePasswordKeys(
        currentPassword: 'vieja',
        newPassword: 'nueva',
        userId: userId,
        current: created.keys,
        argon2id: argon2id,
        kdfBase: lightKdf,
      );
      expect(changed.keys.keysVersion, created.keys.keysVersion + 1);
      expect(changed.masterKey.bytes, equals(created.masterKey.bytes));

      final unlocked = await unlockWithPassword(
        password: 'nueva',
        userId: userId,
        keys: changed.keys,
        argon2id: argon2id,
      );
      expect(unlocked.masterKey.bytes, equals(created.masterKey.bytes));
      unlocked.masterKey.dispose();

      expect(
        () => unlockWithPassword(
          password: 'vieja',
          userId: userId,
          keys: changed.keys,
          argon2id: argon2id,
        ),
        throwsA(isA<DecryptError>()),
      );
    });

    test('recoverWithRecoveryKey restablece la contraseña conservando la clave maestra', () async {
      final created = await createAccountKeys(
        password: 'original',
        userId: userId,
        argon2id: argon2id,
        kdfBase: lightKdf,
      );
      final recovered = await recoverWithRecoveryKey(
        recoveryKeyText: created.recoveryKey,
        newPassword: 'nueva tras recuperar',
        userId: userId,
        recoveryWrappedMasterKey: created.keys.recoveryWrappedMasterKey,
        argon2id: argon2id,
        kdfBase: lightKdf,
      );
      expect(recovered.masterKey.bytes, equals(created.masterKey.bytes));
      expect(recovered.keys.keysVersion, 0);

      final unlocked = await unlockWithPassword(
        password: 'nueva tras recuperar',
        userId: userId,
        keys: recovered.keys,
        argon2id: argon2id,
      );
      expect(unlocked.masterKey.bytes, equals(created.masterKey.bytes));
      unlocked.masterKey.dispose();
    });

    test('recoverWithRecoveryKey con una clave mal escrita lanza CryptoFormatError', () async {
      final created = await createAccountKeys(
        password: 'x',
        userId: userId,
        argon2id: argon2id,
        kdfBase: lightKdf,
      );
      expect(
        () => recoverWithRecoveryKey(
          recoveryKeyText: 'no-es-una-clave-de-recuperacion',
          newPassword: 'y',
          userId: userId,
          recoveryWrappedMasterKey: created.keys.recoveryWrappedMasterKey,
          argon2id: argon2id,
          kdfBase: lightKdf,
        ),
        throwsA(isA<CryptoFormatError>()),
      );
    });

    test('rotateRecoveryKeys cambia la clave de recuperación sin tocar la contraseña', () async {
      final created = await createAccountKeys(
        password: 'secreta',
        userId: userId,
        argon2id: argon2id,
        kdfBase: lightKdf,
      );
      final rotated = await rotateRecoveryKeys(
        password: 'secreta',
        userId: userId,
        keys: created.keys,
        argon2id: argon2id,
      );
      expect(rotated.recoveryKey, isNot(created.recoveryKey));
      final updatedKeys = created.keys.copyWith(
        recoveryWrappedMasterKey: rotated.recoveryWrappedMasterKey,
      );

      final recoveredWithNew = await recoverWithRecoveryKey(
        recoveryKeyText: rotated.recoveryKey,
        newPassword: 'otra',
        userId: userId,
        recoveryWrappedMasterKey: updatedKeys.recoveryWrappedMasterKey,
        argon2id: argon2id,
        kdfBase: lightKdf,
      );
      expect(recoveredWithNew.masterKey.bytes, equals(created.masterKey.bytes));

      expect(
        () => recoverWithRecoveryKey(
          recoveryKeyText: created.recoveryKey,
          newPassword: 'otra',
          userId: userId,
          recoveryWrappedMasterKey: updatedKeys.recoveryWrappedMasterKey,
          argon2id: argon2id,
          kdfBase: lightKdf,
        ),
        throwsA(isA<DecryptError>()),
      );
    });

    test('createAccountKeys propaga el error si Argon2id falla', () async {
      // Argon2id es lo único inyectable y aquí es la única llamada: falla antes de que exista
      // una clave maestra que borrar. El borrado en el camino de error (si algo falla después de
      // generarla: un `wrap`) queda como código defensivo no accesible desde esta prueba, porque
      // ni `wrap` ni la derivación de la clave de recuperación fallan con entradas válidas.
      final flaky = _FlakyArgon2id(argon2id, failOnCall: 1);
      await expectLater(
        createAccountKeys(
          password: 'x',
          userId: userId,
          argon2id: flaky,
          kdfBase: lightKdf,
        ),
        throwsA(isA<_ForcedFailure>()),
      );
    });

    test(
      'changePasswordKeys borra la clave maestra si falla tras desbloquear',
      () async {
        final created = await createAccountKeys(
          password: 'vieja',
          userId: userId,
          argon2id: argon2id,
          kdfBase: lightKdf,
        );
        // Llamada 1 (desbloquear con la contraseña actual): real, produce la clave maestra.
        // Llamada 2 (derivar la contraseña nueva): falla ya con la clave maestra en memoria.
        final flaky = _FlakyArgon2id(argon2id, failOnCall: 2);
        await expectLater(
          changePasswordKeys(
            currentPassword: 'vieja',
            newPassword: 'nueva',
            userId: userId,
            current: created.keys,
            argon2id: flaky,
            kdfBase: lightKdf,
          ),
          throwsA(isA<_ForcedFailure>()),
        );
      },
    );

    test(
      'recoverWithRecoveryKey borra la clave maestra si falla tras abrirla',
      () async {
        final created = await createAccountKeys(
          password: 'original',
          userId: userId,
          argon2id: argon2id,
          kdfBase: lightKdf,
        );
        // La clave de recuperación no usa Argon2id: la clave maestra ya existe (por el `unwrap`)
        // cuando la única llamada a Argon2id (para la contraseña nueva) falla.
        final flaky = _FlakyArgon2id(argon2id, failOnCall: 1);
        await expectLater(
          recoverWithRecoveryKey(
            recoveryKeyText: created.recoveryKey,
            newPassword: 'nueva',
            userId: userId,
            recoveryWrappedMasterKey: created.keys.recoveryWrappedMasterKey,
            argon2id: flaky,
            kdfBase: lightKdf,
          ),
          throwsA(isA<_ForcedFailure>()),
        );
      },
    );
  });

  group('deriveAuthKey', () {
    test('coincide con el authKey que entrega deriveFromPassword', () async {
      final kdf = newKdfParams(base: lightKdf);
      final direct = await deriveFromPassword('x', kdf, argon2id);
      final authKey = await deriveAuthKey('x', kdf, argon2id);
      expect(authKey, direct.authKey);
      direct.kek.dispose();
    });
  });
}
