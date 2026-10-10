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

SecretKeyBytes _masterKey([int fill = 9]) =>
    SecretKeyBytes(Uint8List.fromList(List.filled(32, fill)));

class _Harness {
  _Harness()
    : clock = FakeClock(),
      platform = FakeAxonotePlatform() {
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

  void dispose() {
    controller.dispose();
    container.dispose();
  }
}

void main() {
  group('unlock', () {
    test('pone el cofre desbloqueado y la sesión en unlocked', () async {
      final h = _Harness();
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        remember: false,
      );
      expect(h.session, AxoSession.unlocked);
      expect(h.controller.vault.isUnlocked, isTrue);
      h.dispose();
    });

    test('con remember: true, guarda la clave en axonote_platform', () async {
      final h = _Harness();
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(7),
        remember: true,
      );
      final loaded = await h.platform.loadMasterKey(userId: 'u1', prompt: 'x');
      expect(loaded, Uint8List.fromList(List.filled(32, 7)));
      h.dispose();
    });

    test(
      'remember usa requireAuth según biometricLock de los ajustes actuales',
      () async {
        final h = _Harness();
        h.controller.updateSettings(const LockSettings(biometricLock: false));
        await h.controller.unlock(
          userId: 'u1',
          masterKey: _masterKey(),
          remember: true,
        );
        h.platform.nextAuthResult = const AuthCancelled();
        // Si se hubiera guardado con requireAuth: true, esto fallaría; con false, carga directo.
        final loaded = await h.platform.loadMasterKey(userId: 'u1', prompt: 'x');
        expect(loaded, isNotEmpty);
        h.dispose();
      },
    );
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

    test('si la clave quedó invalidada (huella nueva), devuelve false', () async {
      final h = _Harness();
      await h.platform.storeMasterKey(
        userId: 'u1',
        bytes: Uint8List.fromList(List.filled(32, 3)),
        requireAuth: true,
      );
      h.platform.invalidateByEnrollment();
      final ok = await h.controller.unlockWithStoredKey(
        userId: 'u1',
        prompt: 'x',
      );
      expect(ok, isFalse);
      h.dispose();
    });

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
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        remember: false,
      );
      final vault = h.controller.vault;
      h.controller.lock();
      expect(h.session, AxoSession.locked);
      expect(vault.isUnlocked, isFalse);
      expect(() => h.controller.vault, throwsA(isA<VaultLockedError>()));
      h.dispose();
    });
  });

  group('signOut', () {
    test('bloquea, borra la sesión y la clave guardada en axonote_platform', () async {
      final h = _Harness();
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        remember: true,
      );
      await h.controller.signOut();
      expect(h.session, AxoSession.noSession);
      await expectLater(
        h.platform.loadMasterKey(userId: 'u1', prompt: 'x'),
        throwsA(isA<NoStoredKey>()),
      );
      h.dispose();
    });
  });

  group('tiempo de bloqueo (§5.3)', () {
    test('"never" no bloquea por mucho que pase el tiempo', () async {
      final h = _Harness();
      h.controller.updateSettings(const LockSettings(lockTimeout: LockTimeout.never));
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        remember: false,
      );
      h.timers.advance(const Duration(minutes: 30));
      expect(h.session, AxoSession.unlocked);
      h.dispose();
    });

    test('"1m" bloquea tras un minuto sin actividad', () async {
      final h = _Harness();
      h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.oneMinute),
      );
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        remember: false,
      );
      h.timers.advance(const Duration(seconds: 59));
      expect(h.session, AxoSession.unlocked);
      h.timers.advance(const Duration(seconds: 2));
      expect(h.session, AxoSession.locked);
      h.dispose();
    });

    test('la actividad reinicia la cuenta de inactividad', () async {
      final h = _Harness();
      h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.oneMinute),
      );
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        remember: false,
      );
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
      h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.immediately),
      );
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        remember: false,
      );
      h.controller.appBackgrounded();
      expect(h.session, AxoSession.locked);
      h.dispose();
    });

    test('"immediately" no bloquea mientras sigue en primer plano', () async {
      final h = _Harness();
      h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.immediately),
      );
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        remember: false,
      );
      h.timers.advance(const Duration(minutes: 10));
      expect(h.session, AxoSession.unlocked);
      h.dispose();
    });

    test('lockOnExit bloquea al pasar a segundo plano aunque el tiempo sea "never"', () async {
      final h = _Harness();
      h.controller.updateSettings(
        const LockSettings(lockOnExit: true, lockTimeout: LockTimeout.never),
      );
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        remember: false,
      );
      h.controller.appBackgrounded();
      expect(h.session, AxoSession.locked);
      h.dispose();
    });

    test(
      'sin lockOnExit, al volver de segundo plano se descuenta el tiempo pasado fuera',
      () async {
        final h = _Harness();
        h.controller.updateSettings(
          const LockSettings(lockTimeout: LockTimeout.oneMinute),
        );
        await h.controller.unlock(
          userId: 'u1',
          masterKey: _masterKey(),
          remember: false,
        );
        h.controller.appBackgrounded();
        h.clock.advance(const Duration(seconds: 70));
        h.controller.appResumed();
        expect(h.session, AxoSession.locked);
        h.dispose();
      },
    );

    test(
      'sin lockOnExit, si no pasó suficiente tiempo fuera sigue desbloqueado',
      () async {
        final h = _Harness();
        h.controller.updateSettings(
          const LockSettings(lockTimeout: LockTimeout.oneMinute),
        );
        await h.controller.unlock(
          userId: 'u1',
          masterKey: _masterKey(),
          remember: false,
        );
        h.controller.appBackgrounded();
        h.clock.advance(const Duration(seconds: 10));
        h.controller.appResumed();
        expect(h.session, AxoSession.unlocked);
        h.dispose();
      },
    );

    test('bloquear a mano cancela cualquier temporizador pendiente', () async {
      final h = _Harness();
      h.controller.updateSettings(
        const LockSettings(lockTimeout: LockTimeout.oneMinute),
      );
      await h.controller.unlock(
        userId: 'u1',
        masterKey: _masterKey(),
        remember: false,
      );
      expect(h.timers.pendingCount, 1);
      h.controller.lock();
      expect(h.timers.pendingCount, 0);
      h.dispose();
    });
  });
}
