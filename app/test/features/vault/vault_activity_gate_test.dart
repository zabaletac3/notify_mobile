import 'dart:typed_data';

import 'package:axonote_app/app/session.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/features/vault/state/timer_factory.dart';
import 'package:axonote_app/features/vault/state/vault_lock.dart';
import 'package:axonote_app/features/vault/ui/vault_activity_gate.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('un toque en la pantalla reinicia el tiempo de bloqueo', (
    tester,
  ) async {
    final clock = FakeClock();
    final timers = FakeTimerFactory(clock);
    final platform = FakeAxonotePlatform();
    final container = ProviderContainer(
      overrides: [
        vaultLockControllerProvider.overrideWith(
          (ref) => VaultLockController(
            ref: ref,
            platform: platform,
            clock: clock,
            timerFactory: timers,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(vaultLockControllerProvider);
    await controller.updateSettings(
      const LockSettings(lockTimeout: LockTimeout.oneMinute),
    );
    await controller.unlock(
      userId: 'u1',
      masterKey: SecretKeyBytes(Uint8List(32)),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultActivityGate(child: Scaffold(body: Text('pantalla'))),
        ),
      ),
    );

    timers.advance(const Duration(seconds: 50));
    expect(container.read(sessionProvider), AxoSession.unlocked);

    await tester.tapAt(tester.getCenter(find.text('pantalla')));
    await tester.pump();

    // Si el toque reinició la cuenta, a los 50 s de ESE toque sigue desbloqueado (en total serían
    // 100 s desde el desbloqueo inicial, que ya habría bloqueado sin el reinicio).
    timers.advance(const Duration(seconds: 50));
    expect(container.read(sessionProvider), AxoSession.unlocked);

    timers.advance(const Duration(seconds: 11));
    expect(container.read(sessionProvider), AxoSession.locked);
  });

  testWidgets('pasar a segundo plano con lockOnExit bloquea', (tester) async {
    final clock = FakeClock();
    final timers = FakeTimerFactory(clock);
    final platform = FakeAxonotePlatform();
    final container = ProviderContainer(
      overrides: [
        vaultLockControllerProvider.overrideWith(
          (ref) => VaultLockController(
            ref: ref,
            platform: platform,
            clock: clock,
            timerFactory: timers,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(vaultLockControllerProvider);
    await controller.updateSettings(const LockSettings(lockOnExit: true));
    await controller.unlock(
      userId: 'u1',
      masterKey: SecretKeyBytes(Uint8List(32)),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultActivityGate(child: Scaffold(body: Text('pantalla'))),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(container.read(sessionProvider), AxoSession.locked);
  });
}
