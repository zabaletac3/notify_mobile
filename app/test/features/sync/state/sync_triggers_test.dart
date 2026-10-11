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

/// Confirma todo lo que suban (los cambios de la cola quedan en `synced`, como haría el
/// servidor): guion por defecto de [_ScriptedTransport].
Future<SyncResponse> _confirmAll(SyncRequest request) async => SyncResponse(
  cursor: '0',
  hasMore: false,
  applied: [
    for (final c in request.changes)
      AppliedChange(entity: c.entity, id: c.entityId, revision: 1),
  ],
  conflicts: const [],
  remoteChanges: const [],
);

/// Transporte guionizado: responde según [handler] (mutable, para cambiar el guion a mitad de
/// prueba).
class _ScriptedTransport implements SyncTransport {
  _ScriptedTransport([Future<SyncResponse> Function(SyncRequest)? handler])
    : handler = handler ?? _confirmAll;

  Future<SyncResponse> Function(SyncRequest) handler;
  int calls = 0;

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    calls++;
    return handler(request);
  }
}

void main() {
  late LocalHarness h;
  late FakeClock clock;
  late FakeTimerFactory timers;
  late _FakeConnectivityProbe connectivity;
  late ProviderContainer container;
  late SyncTriggers triggers;
  late _ScriptedTransport transport;

  void useTransport(_ScriptedTransport t) {
    transport = t;
    container
        .read(syncControllerProvider.notifier)
        .attach(
          SyncEngine(
            store: h.local.syncStore,
            transport: transport,
            codec: LocalItemCodec(h.local.deps),
          ),
        );
  }

  setUp(() {
    h = LocalHarness();
    clock = FakeClock();
    timers = FakeTimerFactory(clock);
    connectivity = _FakeConnectivityProbe();
    container = ProviderContainer();
    container.read(sessionProvider.notifier).set(AxoSession.unlocked);
    useTransport(_ScriptedTransport());
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

  void start() => triggers.start(store: h.local.syncStore);

  test('al arrancar sincroniza (desbloquear)', () async {
    start();
    await pumpEventQueue();
    expect(transport.calls, 1);
  });

  test('tras un cambio local sincroniza 3 s después, con rebote', () async {
    start();
    await pumpEventQueue();
    transport.calls = 0;

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

  test('no sincroniza en el rebote si no queda nada pendiente (tras confirmar la subida)', () async {
    start();
    await pumpEventQueue();
    transport.calls = 0;

    await h.local.notes.create(const NoteDraft(title: 'a'));
    await pumpEventQueue();

    // Primer rebote: pendingCount > 0, sincroniza y el transporte confirma la subida (la
    // entrada de outbox se borra, lo que también es una escritura en «outbox»).
    timers.advance(const Duration(seconds: 3));
    await pumpEventQueue();
    expect(transport.calls, 1);
    expect(await h.local.syncStore.pendingCount(), 0);

    // Ese borrado programó otro rebote: como ya no queda nada pendiente, no debe sincronizar.
    timers.advance(const Duration(seconds: 3));
    await pumpEventQueue();
    expect(
      transport.calls,
      1,
      reason: 'pendingCount es 0: el rebote no debe sincronizar de más',
    );
  });

  test('sincroniza cada 60 s', () async {
    start();
    await pumpEventQueue();
    transport.calls = 0;

    timers.advance(const Duration(seconds: 60));
    await pumpEventQueue();
    expect(transport.calls, 1);

    timers.advance(const Duration(seconds: 60));
    await pumpEventQueue();
    expect(transport.calls, 2);
  });

  test('sincroniza al recuperar la red', () async {
    start();
    await pumpEventQueue();
    transport.calls = 0;

    connectivity.emit(const [ConnectivityResult.none]);
    await pumpEventQueue();
    expect(transport.calls, 0);

    connectivity.emit(const [ConnectivityResult.wifi]);
    await pumpEventQueue();
    expect(transport.calls, 1);
  });

  test('se detiene al bloquear: un cambio local ya no sincroniza', () async {
    start();
    await pumpEventQueue();
    transport.calls = 0;
    triggers.stop();

    await h.local.notes.create(const NoteDraft(title: 'a'));
    await pumpEventQueue();
    timers.advance(const Duration(seconds: 3));
    await pumpEventQueue();
    expect(transport.calls, 0);
  });

  test(
    'con la sesión bloqueada no sincroniza aunque el disparador salte',
    () async {
      start();
      await pumpEventQueue();
      transport.calls = 0;
      container.read(sessionProvider.notifier).set(AxoSession.locked);

      timers.advance(const Duration(seconds: 60));
      await pumpEventQueue();
      expect(transport.calls, 0);
    },
  );

  test('con autoSync desactivado no sincroniza sola', () async {
    await writeSyncSettings(
      h.local.syncStore,
      const SyncSettings(autoSync: false),
    );
    start();
    await pumpEventQueue();
    expect(transport.calls, 0);
  });

  test('con wifiOnly activado no sincroniza fuera de Wi-Fi', () async {
    await writeSyncSettings(
      h.local.syncStore,
      const SyncSettings(wifiOnly: true),
    );
    connectivity.current = const [ConnectivityResult.mobile];
    start();
    await pumpEventQueue();
    expect(transport.calls, 0);

    connectivity.current = const [ConnectivityResult.wifi];
    timers.advance(const Duration(seconds: 60));
    await pumpEventQueue();
    expect(transport.calls, 1);
  });

  group('política de reintentos (plan §7)', () {
    test(
      'ante network/server reintenta con espera exponencial 2s, 4s, 8s…',
      () async {
        transport.handler = (r) async => throw const AppFailure(NetworkError());
        start();
        await pumpEventQueue();
        expect(transport.calls, 1, reason: 'falla al desbloquear');

        timers.advance(const Duration(seconds: 1));
        await pumpEventQueue();
        expect(transport.calls, 1, reason: 'aún no pasaron los 2 s');

        timers.advance(const Duration(seconds: 1)); // 2 s desde el 1er fallo
        await pumpEventQueue();
        expect(transport.calls, 2, reason: 'reintento a los 2 s');

        timers.advance(const Duration(seconds: 3)); // 3 s desde el 2º fallo
        await pumpEventQueue();
        expect(transport.calls, 2, reason: 'aún no pasaron los 4 s');

        timers.advance(const Duration(seconds: 1)); // 4 s desde el 2º fallo
        await pumpEventQueue();
        expect(transport.calls, 3, reason: 'reintento a los 4 s (doblado)');
      },
    );

    test('la espera del reintento se reinicia a 2 s tras una sincronización correcta', () async {
      transport.handler = (r) async => throw const AppFailure(ServerError());
      start();
      await pumpEventQueue();
      timers.advance(const Duration(seconds: 2));
      await pumpEventQueue();
      timers.advance(const Duration(seconds: 4));
      await pumpEventQueue();
      expect(transport.calls, 3, reason: '2 reintentos tras el fallo inicial');

      // Ahora responde bien: la próxima espera debe volver a ser 2 s, no 8.
      transport.handler = _confirmAll;
      timers.advance(const Duration(seconds: 8));
      await pumpEventQueue();
      expect(
        transport.calls,
        4,
        reason: 'el 3er reintento (a los 8 s) ya funciona',
      );

      await h.local.notes.create(const NoteDraft(title: 'x'));
      await pumpEventQueue();
      transport.handler = (r) async => throw const AppFailure(ServerError());

      timers.advance(const Duration(seconds: 3)); // dispara el rebote
      await pumpEventQueue();
      expect(transport.calls, 5, reason: 'el rebote intenta y falla otra vez');

      timers.advance(const Duration(seconds: 1));
      await pumpEventQueue();
      expect(
        transport.calls,
        5,
        reason:
            'todavía no pasaron los 2 s: la espera se reinició, no sigue en 8',
      );
      timers.advance(const Duration(seconds: 1));
      await pumpEventQueue();
      expect(transport.calls, 6, reason: 'reintento a los 2 s, no a los 8');
    });

    test('recuperar la red reinicia la espera y sincroniza ya, sin esperar el reintento programado', () async {
      transport.handler = (r) async => throw const AppFailure(NetworkError());
      start();
      await pumpEventQueue();
      expect(transport.calls, 1);

      // El reintento programado sería a los 2 s; la red vuelve antes, a 1 s.
      transport.handler = _confirmAll;
      timers.advance(const Duration(seconds: 1));
      connectivity.emit(const [ConnectivityResult.wifi]);
      await pumpEventQueue();
      expect(
        transport.calls,
        2,
        reason: 'sincronizó ya, sin esperar al reintento de los 2 s',
      );
    });

    test('rate-limited no sincroniza por ningún disparador hasta pasar retryAfterSec', () async {
      transport.handler = (r) async =>
          throw const AppFailure(RateLimitedError(retryAfterSec: 30));
      start();
      await pumpEventQueue();
      expect(transport.calls, 1);
      transport.handler = _confirmAll;

      // Ni el rebote…
      await h.local.notes.create(const NoteDraft(title: 'x'));
      await pumpEventQueue();
      timers.advance(const Duration(seconds: 3));
      await pumpEventQueue();
      expect(transport.calls, 1, reason: 'suprimido: ni el rebote sincroniza');

      // …ni la red…
      connectivity.emit(const [ConnectivityResult.none]);
      await pumpEventQueue();
      connectivity.emit(const [ConnectivityResult.wifi]);
      await pumpEventQueue();
      expect(
        transport.calls,
        1,
        reason: 'suprimido: ni recuperar la red sincroniza',
      );

      // …ni el sondeo, hasta que pasen los 30 s.
      timers.advance(const Duration(seconds: 26));
      await pumpEventQueue();
      expect(transport.calls, 1, reason: 'aún no pasaron los 30 s');

      timers.advance(const Duration(seconds: 1));
      await pumpEventQueue();
      expect(transport.calls, 2, reason: 'pasados los 30 s, se reintenta solo');
    });

    test('forbidden no programa un reintento propio, pero el sondeo normal sigue intentando', () async {
      transport.handler = (r) async => throw const AppFailure(ForbiddenError());
      start();
      await pumpEventQueue();
      expect(transport.calls, 1);

      // Sin reintento propio: a los 2 s (lo que tocaría con network/server) no pasa nada.
      timers.advance(const Duration(seconds: 2));
      await pumpEventQueue();
      expect(
        transport.calls,
        1,
        reason: 'forbidden no programa un reintento propio',
      );

      // El sondeo normal de 60 s sigue intentando (y, como aquí ya responde bien, confirma
      // que no quedó nada suprimido).
      transport.handler = _confirmAll;
      timers.advance(const Duration(seconds: 58));
      await pumpEventQueue();
      expect(transport.calls, 2, reason: 'el sondeo de 60 s sí lo reintenta');
    });
  });
}
