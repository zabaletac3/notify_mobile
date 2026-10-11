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

Map<String, Object?> _emptySyncResponse({String cursor = '1'}) => {
  'cursor': cursor,
  'hasMore': false,
  'applied': <Object?>[],
  'conflicts': <Object?>[],
  'remoteChanges': <Object?>[],
};

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

  test(
    'open monta la base, el motor, el controlador y los disparadores; close lo suelta todo',
    () async {
      final adapter = FakeAdapter(
        (options) async => jsonResponse(200, _emptySyncResponse()),
      );
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

      // El controlador ya tiene el motor (attach lo adjunta y refresca el snapshot).
      await session.local.notes.create(const NoteDraft(title: 'x'));
      await container.read(syncControllerProvider.notifier).syncNow();
      final state = container.read(syncControllerProvider);
      expect(state.lastError, isNull);
      expect(state.pendingCount, 0);

      // onSessionExpired/onDeviceRevoked quedan conectados a los que pasó quien llamó a open().
      final controller = container.read(syncControllerProvider.notifier);
      controller.onSessionExpired!();
      controller.onDeviceRevoked!();
      expect(sessionExpired, isTrue);
      expect(deviceRevoked, isTrue);

      await session.close();
      expect(container.read(syncTriggersProvider).isRunning, isFalse);
      expect(container.read(syncControllerProvider), SyncUiState.empty);
    },
  );
}
