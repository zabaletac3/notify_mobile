import 'dart:async';

import 'package:axonote_app/app/session.dart';
import 'package:axonote_app/data/local/local_item_codec.dart';
import 'package:axonote_app/features/sync/state/connectivity_probe.dart';
import 'package:axonote_app/features/sync/state/sync_controller.dart';
import 'package:axonote_app/features/sync/state/sync_settings.dart';
import 'package:axonote_app/features/sync/state/sync_triggers.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/features/vault/state/timer_factory.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../data/local/local_harness.dart';

/// Expone un [Ref] de pruebas: `ProviderContainer` no implementa `Ref`, así que se lee de un
/// proveedor trivial (patrón habitual de Riverpod para probar clases que piden un `Ref`).
final _refProvider = Provider<Ref>((ref) => ref);

class _FakeConnectivityProbe implements ConnectivityProbe {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> current = const [ConnectivityResult.wifi];

  @override
  Stream<List<ConnectivityResult>> get onChanged => _controller.stream;

  @override
  Future<List<ConnectivityResult>> check() async => current;

  void emit(List<ConnectivityResult> results) {
    current = results;
    _controller.add(results);
  }

  Future<void> dispose() => _controller.close();
}

class _CountingTransport implements SyncTransport {
  int calls = 0;

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    calls++;
    return const SyncResponse(
      cursor: '0',
      hasMore: false,
      applied: [],
      conflicts: [],
      remoteChanges: [],
    );
  }
}

void main() {
  late LocalHarness h;
  late FakeClock clock;
  late FakeTimerFactory timers;
  late _FakeConnectivityProbe connectivity;
  late ProviderContainer container;
  late SyncTriggers triggers;
  late _CountingTransport transport;

  setUp(() {
    h = LocalHarness();
    clock = FakeClock();
    timers = FakeTimerFactory(clock);
    connectivity = _FakeConnectivityProbe();
    transport = _CountingTransport();
    container = ProviderContainer();
    container.read(sessionProvider.notifier).set(AxoSession.unlocked);
    container
        .read(syncControllerProvider.notifier)
        .attach(
          SyncEngine(
            store: h.local.syncStore,
            transport: transport,
            codec: LocalItemCodec(h.local.deps),
          ),
        );
    triggers = SyncTriggers(
      ref: container.read(_refProvider),
      connectivity: connectivity,
      timerFactory: timers,
    );
  });

  tearDown(() async {
    triggers.stop();
    await connectivity.dispose();
    container.dispose();
    await h.close();
  });

  void start() => triggers.start(
    notes: h.local.notes,
    folders: h.local.folders,
    store: h.local.syncStore,
  );

  /// Arranca y deja correr el primer emparejamiento de `watch()` (que por sí solo ya hace saltar
  /// el rebote de 3 s, aunque no haya habido ningún cambio real): así cada prueba empieza en
  /// limpio, sin un temporizador de sobra ya en marcha.
  Future<void> startAndSettle() async {
    start();
    await pumpEventQueue();
    timers.advance(const Duration(seconds: 3));
    await pumpEventQueue();
    transport.calls = 0;
  }

  test('al arrancar sincroniza (desbloquear)', () async {
    start();
    await pumpEventQueue();
    expect(transport.calls, 1);
  });

  test('tras un cambio local sincroniza 3 s después, con rebote', () async {
    await startAndSettle();

    await h.local.notes.create(const NoteDraft(title: 'a'));
    await pumpEventQueue();
    timers.advance(const Duration(seconds: 2));
    await pumpEventQueue();

    // Otro cambio antes de que pasen los 3 s reinicia el rebote.
    await h.local.notes.create(const NoteDraft(title: 'b'));
    await pumpEventQueue();
    timers.advance(const Duration(seconds: 2));
    await pumpEventQueue();
    expect(transport.calls, 0, reason: 'el segundo cambio reinició el rebote');

    timers.advance(const Duration(seconds: 1));
    await pumpEventQueue();
    expect(transport.calls, 1);
  });

  test('sincroniza cada 60 s', () async {
    await startAndSettle();

    timers.advance(const Duration(seconds: 60));
    await pumpEventQueue();
    expect(transport.calls, 1);

    timers.advance(const Duration(seconds: 60));
    await pumpEventQueue();
    expect(transport.calls, 2);
  });

  test('sincroniza al recuperar la red', () async {
    await startAndSettle();

    connectivity.emit(const [ConnectivityResult.none]);
    await pumpEventQueue();
    expect(transport.calls, 0);

    connectivity.emit(const [ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(transport.calls, 1);
  });

  test('se detiene al bloquear: un cambio local ya no sincroniza', () async {
    await startAndSettle();
    triggers.stop();

    await h.local.notes.create(const NoteDraft(title: 'a'));
    await pumpEventQueue();
    timers.advance(const Duration(seconds: 3));
    await pumpEventQueue();
    expect(transport.calls, 0);
  });

  test('con la sesión bloqueada no sincroniza aunque el disparador salte', () async {
    await startAndSettle();
    container.read(sessionProvider.notifier).set(AxoSession.locked);

    timers.advance(const Duration(seconds: 60));
    await pumpEventQueue();
    expect(transport.calls, 0);
  });

  test('con autoSync desactivado no sincroniza sola', () async {
    await writeSyncSettings(h.local.syncStore, const SyncSettings(autoSync: false));
    start();
    await pumpEventQueue();
    expect(transport.calls, 0);
  });

  test('con wifiOnly activado no sincroniza fuera de Wi-Fi', () async {
    await writeSyncSettings(h.local.syncStore, const SyncSettings(wifiOnly: true));
    connectivity.current = const [ConnectivityResult.mobile];
    start();
    await pumpEventQueue();
    expect(transport.calls, 0);
    // Consume también el rebote inicial de `watch()` (ver startAndSettle): sin wifi, tampoco
    // sincroniza.
    timers.advance(const Duration(seconds: 3));
    await pumpEventQueue();
    expect(transport.calls, 0);

    connectivity.current = const [ConnectivityResult.wifi];
    timers.advance(const Duration(seconds: 60));
    await pumpEventQueue();
    expect(transport.calls, 1);
  });
}
