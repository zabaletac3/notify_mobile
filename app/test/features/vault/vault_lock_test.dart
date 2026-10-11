import 'dart:typed_data';

import 'package:axonote_app/app/session.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/features/vault/state/timer_factory.dart';
import 'package:axonote_app/features/vault/state/vault_lock.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:axonote_app/data/crypto/vault.dart';

SecretKeyBytes _masterKey([int fill = 9]) =>
    SecretKeyBytes(Uint8List.fromList(List.filled(32, fill)));

class _Harness {
  _Harness() : clock = FakeClock(), platform = FakeAxonotePlatform() {
    timers = FakeTimerFactory(clock);
    final provider = Provider<VaultLockController>(
      (ref) => VaultLockController(
        ref: ref,
        platform: platform,
        clock: clock,
        timerFactory: timers,
      ),
    );
    container = ProviderContainer();
    controller = container.read(provider);
  }

  final FakeClock clock;
  final FakeAxonotePlatform platform;
  late final FakeTimerFactory timers;
  late final ProviderContainer container;
  late final VaultLockController controller;

  AxoSession get session => container.read(sessionProvider);

  Future<bool> hasStored(String userId) async {
    try {
      await platform.loadMasterKey(userId: userId, prompt: 'x');
      return true;
    } on NoStoredKey {
      return false;
    }
  }

  void dispose() {
    controller.dispose();
    container.dispose();
  }
}

void main() {
  group('unlock · regla de recuerdo (plan §5.3)', () {
    test('pone el cofre desbloqueado y la sesión en unlocked', () async {
      final h = _Harness();
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      expect(h.session, AxoSession.unlocked);
      expect(h.controller.vault.isUnlocked, isTrue);
      h.dispose();
    });

    test('biometricLock: true → se guarda con requireAuth: true', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(
          biometricLock: true,
          lockOnExit: true,
          lockTimeout: LockTimeout.oneMinute,
        ),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey(7));
      // requireAuth: true y sin forzar nada: la Fake exige que haya biometría disponible (la hay
      // por defecto) para completar storeMasterKey; que haya quedado guardado así se comprueba
      // forzando un fallo de biometría en la próxima carga.
      h.platform.nextAuthResult = const AuthCancelled();
      await expectLater(
        h.platform.loadMasterKey(userId: 'u1', prompt: 'x'),
        throwsA(isA<AuthCancelled>()),
      );
      h.dispose();
    });

    test('biometricLock: true gana aunque lockOnExit/lockTimeout permitirían guardar sin auth', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(
          biometricLock: true,
          lockOnExit: false,
          lockTimeout: LockTimeout.never,
        ),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      h.platform.nextAuthResult = const AuthCancelled();
      await expectLater(
        h.platform.loadMasterKey(userId: 'u1', prompt: 'x'),
        throwsA(isA<AuthCancelled>()),
      );
      h.dispose();
    });

    test('biometricLock: false, lockOnExit: false, lockTimeout: never → '
        'se guarda con requireAuth: false', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(
          biometricLock: false,
          lockOnExit: false,
          lockTimeout: LockTimeout.never,
        ),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey(7));
      // Si se hubiera guardado con requireAuth: true, esto fallaría (se consume aquí sin
      // afectar al resultado); con requireAuth: false, carga directo sin mirarlo.
      h.platform.nextAuthResult = const AuthCancelled();
      final loaded = await h.platform.loadMasterKey(userId: 'u1', prompt: 'x');
      expect(loaded, Uint8List.fromList(List.filled(32, 7)));
      h.dispose();
    });

    test('biometricLock: false, lockOnExit: true, lockTimeout: never → no se guarda nada', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(
          biometricLock: false,
          lockOnExit: true,
          lockTimeout: LockTimeout.never,
        ),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      expect(await h.hasStored('u1'), isFalse);
      h.dispose();
    });

    test('biometricLock: false, lockOnExit: false, lockTimeout: 1m → no se guarda nada', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(
          biometricLock: false,
          lockOnExit: false,
          lockTimeout: LockTimeout.oneMinute,
        ),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      expect(await h.hasStored('u1'), isFalse);
      h.dispose();
    });

    test('biometricLock: false, lockOnExit: true, lockTimeout: 1m → no se guarda nada', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(
          biometricLock: false,
          lockOnExit: true,
          lockTimeout: LockTimeout.oneMinute,
        ),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      expect(await h.hasStored('u1'), isFalse);
      h.dispose();
    });

    test('rememberOnThisDevice: false no guarda nada aunque la regla permitiría guardar', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(
          biometricLock: false,
          lockOnExit: false,
          lockTimeout: LockTimeout.never,
        ),
      );
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        rememberOnThisDevice: false,
      );
      expect(await h.hasStored('u1'), isFalse);
      h.dispose();
    });
  });

  group('updateSettings · reaplica la regla con el cofre desbloqueado', () {
    test('pasar de requireAuth a no-guardar borra lo guardado', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(biometricLock: true),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      expect(await h.hasStored('u1'), isTrue);

      await h.controller.updateSettings(
        const LockSettings(
          biometricLock: false,
          lockOnExit: true,
          lockTimeout: LockTimeout.oneMinute,
        ),
      );
      expect(await h.hasStored('u1'), isFalse);
      h.dispose();
    });

    test('cambiar solo lockTimeout con biometricLock: true no vuelve a guardar '
        '(la política no cambia, no hace falta pedir biometría otra vez)', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(biometricLock: true, lockTimeout: LockTimeout.never),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      // unlock() ya guarda una vez (requireAuth: true, por biometricLock).
      expect(h.platform.storeMasterKeyCallCount, 1);

      // Si updateSettings volviera a guardar sin necesidad, el contador subiría
      // a 2. No se usa hasStored aquí: con requireAuth: true consumiría
      // nextAuthResult si se forzara uno, además de solo poder comprobarse
      // después (ver más abajo).
      await h.controller.updateSettings(
        const LockSettings(
          biometricLock: true,
          lockTimeout: LockTimeout.oneMinute,
        ),
      );
      expect(h.platform.storeMasterKeyCallCount, 1);

      // Con nextAuthResult limpio (nunca se tocó), la clave sigue intacta.
      expect(await h.hasStored('u1'), isTrue);
      h.dispose();
    });

    test(
      'pasar de no-guardar a requireAuth guarda con requireAuth: true',
      () async {
        final h = _Harness();
        await h.controller.updateSettings(
          const LockSettings(biometricLock: false, lockOnExit: true),
        );
        await h.controller.unlock(userId: 'u1', masterKey: _masterKey(3));
        expect(await h.hasStored('u1'), isFalse);

        await h.controller.updateSettings(
          const LockSettings(biometricLock: true),
        );
        h.platform.nextAuthResult = const AuthCancelled();
        await expectLater(
          h.platform.loadMasterKey(userId: 'u1', prompt: 'x'),
          throwsA(isA<AuthCancelled>()),
        );
        h.dispose();
      },
    );

    test(
      'pasar de no-guardar a noAuth guarda con requireAuth: false',
      () async {
        final h = _Harness();
        await h.controller.updateSettings(
          const LockSettings(biometricLock: false, lockOnExit: true),
        );
        await h.controller.unlock(userId: 'u1', masterKey: _masterKey(7));
        expect(await h.hasStored('u1'), isFalse);

        await h.controller.updateSettings(
          const LockSettings(
            biometricLock: false,
            lockOnExit: false,
            lockTimeout: LockTimeout.never,
          ),
        );
        h.platform.nextAuthResult = const AuthCancelled();
        final loaded = await h.platform.loadMasterKey(
          userId: 'u1',
          prompt: 'x',
        );
        expect(loaded, Uint8List.fromList(List.filled(32, 7)));
        h.dispose();
      },
    );

    test('si reaplicar falla (biometría cancelada), no queda nada guardado y se relanza', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(
          biometricLock: false,
          lockOnExit: false,
          lockTimeout: LockTimeout.never,
        ),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      expect(await h.hasStored('u1'), isTrue);

      h.platform.nextAuthResult = const AuthCancelled();
      await expectLater(
        h.controller.updateSettings(const LockSettings(biometricLock: true)),
        throwsA(isA<AuthCancelled>()),
      );
      // Coherente: nada guardado (ni lo viejo, con la regla ya abandonada, ni lo nuevo, que
      // nunca llegó a confirmarse).
      expect(await h.hasStored('u1'), isFalse);
      h.dispose();
    });

    test('rememberOnThisDevice: false sigue sin guardar aunque cambien los ajustes', () async {
      final h = _Harness();
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        rememberOnThisDevice: false,
      );
      expect(await h.hasStored('u1'), isFalse);

      await h.controller.updateSettings(
        const LockSettings(biometricLock: true),
      );
      expect(await h.hasStored('u1'), isFalse);
      h.dispose();
    });

    test('sin sesión desbloqueada, solo guarda el ajuste (no toca axonote_platform)', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(biometricLock: true),
      );
      expect(await h.hasStored('u1'), isFalse);
      h.dispose();
    });
  });

  group('unlockWithStoredKey', () {
    test('sin nada guardado, devuelve false', () async {
      final h = _Harness();
      final ok = await h.controller.unlockWithStoredKey(
        userId: 'u1',
        prompt: 'x',
      );
      expect(ok, isFalse);
      expect(h.session, AxoSession.noSession);
      h.dispose();
    });

    test('con una clave guardada, desbloquea y pasa a unlocked', () async {
      final h = _Harness();
      await h.platform.storeMasterKey(
        userId: 'u1',
        bytes: Uint8List.fromList(List.filled(32, 3)),
        requireAuth: false,
      );
      final ok = await h.controller.unlockWithStoredKey(
        userId: 'u1',
        prompt: 'x',
      );
      expect(ok, isTrue);
      expect(h.session, AxoSession.unlocked);
      h.dispose();
    });

    test(
      'si la clave quedó invalidada (p. ej. se quitó el bloqueo de pantalla '
      'seguro), devuelve false',
      () async {
        final h = _Harness();
        await h.platform.storeMasterKey(
          userId: 'u1',
          bytes: Uint8List.fromList(List.filled(32, 3)),
          requireAuth: true,
        );
        h.platform.invalidateStoredKey();
        final ok = await h.controller.unlockWithStoredKey(
          userId: 'u1',
          prompt: 'x',
        );
        expect(ok, isFalse);
        h.dispose();
      },
    );

    test('si se cancela la biometría, relanza AuthCancelled', () async {
      final h = _Harness();
      await h.platform.storeMasterKey(
        userId: 'u1',
        bytes: Uint8List.fromList(List.filled(32, 3)),
        requireAuth: true,
      );
      h.platform.nextAuthResult = const AuthCancelled();
      await expectLater(
        h.controller.unlockWithStoredKey(userId: 'u1', prompt: 'x'),
        throwsA(isA<AuthCancelled>()),
      );
      h.dispose();
    });
  });

  group('lock', () {
    test('borra el cofre de memoria y pasa a locked', () async {
      final h = _Harness();
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      final vault = h.controller.vault;
      h.controller.lock();
      expect(h.session, AxoSession.locked);
      expect(vault.isUnlocked, isFalse);
      expect(() => h.controller.vault, throwsA(isA<VaultLockedError>()));
      h.dispose();
    });
  });

  group('signOut', () {
    test(
      'bloquea, borra la sesión y la clave guardada en axonote_platform',
      () async {
        final h = _Harness();
        await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
        await h.controller.signOut(userId: 'u1');
        expect(h.session, AxoSession.noSession);
        expect(await h.hasStored('u1'), isFalse);
        h.dispose();
      },
    );

    test('borra la clave guardada aunque el cofre nunca se desbloqueara en este proceso '
        '(arranque en frío bloqueado)', () async {
      final h = _Harness();
      await h.platform.storeMasterKey(
        userId: 'u1',
        bytes: Uint8List(32),
        requireAuth: false,
      );
      // _vault es null: nunca se llamó a unlock ni a unlockWithStoredKey en este proceso.
      await h.controller.signOut(userId: 'u1');
      expect(await h.hasStored('u1'), isFalse);
      h.dispose();
    });
  });

  group('tiempo de bloqueo (§5.3)', () {
    test('"never" no bloquea por mucho que pase el tiempo', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.never),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      h.timers.advance(const Duration(minutes: 30));
      expect(h.session, AxoSession.unlocked);
      h.dispose();
    });

    test('"1m" bloquea tras un minuto sin actividad', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.oneMinute),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      h.timers.advance(const Duration(seconds: 59));
      expect(h.session, AxoSession.unlocked);
      h.timers.advance(const Duration(seconds: 2));
      expect(h.session, AxoSession.locked);
      h.dispose();
    });

    test('la actividad reinicia la cuenta de inactividad', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.oneMinute),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      h.timers.advance(const Duration(seconds: 50));
      h.controller.noteActivity();
      h.timers.advance(const Duration(seconds: 50));
      // 100 s desde el desbloqueo, pero solo 50 s desde la última actividad: sigue desbloqueado.
      expect(h.session, AxoSession.unlocked);
      h.timers.advance(const Duration(seconds: 11));
      expect(h.session, AxoSession.locked);
      h.dispose();
    });

    test('"immediately" bloquea al pasar a segundo plano', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.immediately),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      h.controller.appBackgrounded();
      expect(h.session, AxoSession.locked);
      h.dispose();
    });

    test('"immediately" no bloquea mientras sigue en primer plano', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.immediately),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      h.timers.advance(const Duration(minutes: 10));
      expect(h.session, AxoSession.unlocked);
      h.dispose();
    });

    test('lockOnExit bloquea al pasar a segundo plano aunque el tiempo sea "never"', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(lockOnExit: true, lockTimeout: LockTimeout.never),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      h.controller.appBackgrounded();
      expect(h.session, AxoSession.locked);
      h.dispose();
    });

    test('sin lockOnExit, al volver de segundo plano se descuenta el tiempo pasado fuera', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.oneMinute),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      h.controller.appBackgrounded();
      h.clock.advance(const Duration(seconds: 70));
      h.controller.appResumed();
      expect(h.session, AxoSession.locked);
      h.dispose();
    });

    test(
      'sin lockOnExit, si no pasó suficiente tiempo fuera sigue desbloqueado',
      () async {
        final h = _Harness();
        await h.controller.updateSettings(
          const LockSettings(lockTimeout: LockTimeout.oneMinute),
        );
        await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
        h.controller.appBackgrounded();
        h.clock.advance(const Duration(seconds: 10));
        h.controller.appResumed();
        expect(h.session, AxoSession.unlocked);
        h.dispose();
      },
    );

    test('bloquear a mano cancela cualquier temporizador pendiente', () async {
      final h = _Harness();
      await h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.oneMinute),
      );
      await h.controller.unlock(userId: 'u1', masterKey: _masterKey());
      expect(h.timers.pendingCount, 1);
      h.controller.lock();
      expect(h.timers.pendingCount, 0);
      h.dispose();
    });
  });
}
