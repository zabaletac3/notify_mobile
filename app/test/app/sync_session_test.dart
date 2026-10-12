// Prueba la costura con la fase 8 (plan §8/§10, ver docs/decisions.md «Fase 7»): que
// `SyncSession.open`/`close` monten y suelten de verdad todas las piezas (base local, motor,
// controlador, disparadores), no solo que compilen.
import 'dart:async';
import 'dart:io';

import 'package:axonote_api/axonote_api.dart';
import 'package:axonote_app/app/session.dart';
import 'package:axonote_app/app/sync_session.dart';
import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_app/features/sync/state/connectivity_probe.dart';
import 'package:axonote_app/features/sync/state/sync_controller.dart';
import 'package:axonote_app/features/sync/state/sync_triggers.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart' show SyncEngine;
import 'package:connectivity_plus/connectivity_plus.dart'
    show ConnectivityResult;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/remote/fake_dio.dart';

/// `ProviderContainer` no implementa `Ref` (mismo patrón que `sync_triggers_test.dart`): se lee
/// de un proveedor trivial.
final _refProvider = Provider<Ref>((ref) => ref);

/// `SyncTriggers` real, pero con conectividad simulada: `flutter test` no tiene el canal de
/// plataforma de `connectivity_plus`, así que el `PluginConnectivityProbe` por defecto del
/// proveedor no sirve aquí (mismo motivo que en `sync_triggers_test.dart`).
class _FakeConnectivityProbe implements ConnectivityProbe {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Stream<List<ConnectivityResult>> get onChanged => _controller.stream;

  @override
  Future<List<ConnectivityResult>> check() async => const [
    ConnectivityResult.wifi,
  ];
}

Future<HttpClient> _httpClientWith(FakeAdapter adapter) async {
  final tokens = MemoryTokenStore();
  await tokens.write(
    const StoredTokens(
      accessToken: 'at',
      refreshToken: 'rt',
      expiresAt: '2099-01-01T00:00:00.000Z',
    ),
  );
  return HttpClient(
    HttpClientOptions(
      baseUrl: 'http://localhost:8080/v1',
      tokens: tokens,
      dio: dioWith(adapter),
    ),
  );
}

/// Espera, con tiempo real y sin adivinar cuánto tarda nada, a que se asiente la
/// sincronización «al desbloquear» que `SyncTriggers.start()` dispara sola (`unawaited`).
///
/// Usa [SyncEngine.isSyncing] directamente (no `syncControllerProvider.phase`, que solo cambia
/// a `syncing` cuando `SyncController.syncNow()` ya está en marcha — y abrir por primera vez la
/// base cifrada del isolate puede tardar más de lo que parece, así que un solo chequeo
/// inmediato puede pillarla todavía en `idle` sin haber empezado). Primero espera a que
/// [engine] se ponga a sincronizar de verdad; si el plazo se agota sin verlo, no es un fallo —
/// puede que ya hubiera terminado tan rápido (nada pendiente, respuesta instantánea del
/// servidor falso) que nunca se la vio en marcha, y entonces no hay nada que esperar. Si sí
/// llegó a arrancar, entonces SÍ hace falta que termine a tiempo: eso es lo único que falla de
/// verdad, con un mensaje claro.
Future<void> _waitUntilSyncSettles(
  SyncEngine engine, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final startedBy = DateTime.now().add(timeout);
  while (!engine.isSyncing && DateTime.now().isBefore(startedBy)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  // Nunca llegó a verse en marcha: no hay nada que esperar.
  if (!engine.isSyncing) return;
  final finishedBy = DateTime.now().add(timeout);
  while (engine.isSyncing) {
    if (DateTime.now().isAfter(finishedBy)) {
      throw TestFailure(
        'la sincronización «al desbloquear» sigue en curso tras '
        '${timeout.inSeconds} s: no se puede seguir sin saber si terminó',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  late ProviderContainer container;
  late Directory dir;
  late Vault vault;
  const userId = 'u_seam';

  setUp(() {
    container = ProviderContainer(
      overrides: [
        syncTriggersProvider.overrideWith((ref) {
          final triggers = SyncTriggers(
            ref: ref,
            connectivity: _FakeConnectivityProbe(),
          );
          ref.onDispose(triggers.stop);
          return triggers;
        }),
      ],
    );
    container.read(sessionProvider.notifier).set(AxoSession.unlocked);
    dir = Directory.systemTemp.createTempSync('axonote-sync-session');
    vault = Vault(userId: userId)..unlockWith(generateKeyBytes());
  });

  tearDown(() {
    container.dispose();
    dir.deleteSync(recursive: true);
  });

  test('open monta la base, el motor, el controlador y los disparadores; close lo suelta todo', () async {
    // El servidor falso confirma cada cambio que reciba (como haría uno real), en vez de
    // devolver siempre `applied: []`: si no, el motor hace bien su trabajo —la entrada sigue
    // pendiente porque de verdad nadie la aceptó— y la prueba pide algo que no puede pasar.
    final adapter = FakeAdapter((options) async {
      final body = options.data! as Map<String, Object?>;
      final changes = (body['changes']! as List).cast<Map<String, Object?>>();
      return jsonResponse(200, {
        'cursor': '1',
        'hasMore': false,
        'applied': [
          for (final c in changes)
            {'entity': c['entity'], 'id': c['id'], 'revision': 1},
        ],
        'conflicts': <Object?>[],
        'remoteChanges': <Object?>[],
      });
    });
    final http = await _httpClientWith(adapter);
    var sessionExpired = false;
    var deviceRevoked = false;

    final session = await SyncSession.open(
      ref: container.read(_refProvider),
      vault: vault,
      userId: userId,
      directory: dir,
      http: http,
      deviceId: 'd1',
      deviceName: 'Móvil de prueba',
      onSessionExpired: () => sessionExpired = true,
      onDeviceRevoked: () => deviceRevoked = true,
    );

    // Los disparadores están montados sobre el `SyncStore` de la base recién abierta.
    expect(container.read(syncTriggersProvider).isRunning, isTrue);

    // Deja que se asiente el ciclo de sincronización que start() ya disparó solo (sin nada
    // pendiente): si no, podría seguir en vuelo cuando se llame a syncNow() más abajo y esa
    // llamada se limitaría a esperar ESE resultado (de antes de crear la nota).
    await _waitUntilSyncSettles(session.engine);

    // El controlador ya tiene el motor (attach lo adjunta y refresca el snapshot).
    await session.local.notes.create(const NoteDraft(title: 'x'));
    await container.read(syncControllerProvider.notifier).syncNow();
    final state = container.read(syncControllerProvider);
    expect(state.lastError, isNull);
    expect(state.pendingCount, 0);

    // La petición que subió la nota llevó exactamente un upsert, con el deviceId/deviceName de
    // esta sesión (y no, p. ej., los de una sincronización vacía anterior).
    final noteRequest = adapter.requests.firstWhere(
      (r) => ((r.data! as Map<String, Object?>)['changes']! as List).isNotEmpty,
    );
    final body = noteRequest.data! as Map<String, Object?>;
    expect(body['deviceId'], 'd1');
    expect(body['deviceName'], 'Móvil de prueba');
    final changes = (body['changes']! as List).cast<Map<String, Object?>>();
    expect(changes, hasLength(1));
    expect(changes.single['entity'], 'note');
    expect(changes.single['op'], 'upsert');

    // onSessionExpired/onDeviceRevoked quedan conectados a los que pasó quien llamó a open().
    final controller = container.read(syncControllerProvider.notifier);
    controller.onSessionExpired!();
    controller.onDeviceRevoked!();
    expect(sessionExpired, isTrue);
    expect(deviceRevoked, isTrue);

    await session.close();
    expect(container.read(syncTriggersProvider).isRunning, isFalse);
    expect(container.read(syncControllerProvider), SyncUiState.empty);
  });
}
