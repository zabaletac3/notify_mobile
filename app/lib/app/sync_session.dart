import 'dart:io';

import 'package:axonote_api/axonote_api.dart' show HttpClient, SyncApi;
import 'package:axonote_sync/axonote_sync.dart' show SyncEngine;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crypto/vault.dart';
import '../data/local/local_account.dart';
import '../data/remote/remote_sync_transport.dart';
import '../features/sync/state/sync_controller.dart';
import '../features/sync/state/sync_triggers.dart';

/// Costura con la fase 8 (plan §8/§10, otra rama). Esta fase deja montados por separado
/// `LocalDatabase`, `RemoteSyncTransport`, `SyncEngine`, `SyncController` y `SyncTriggers`, pero
/// nadie los une todavía: no hay `VaultLifecycle.onUnlocked`/`onSignedOut`, ni un `HttpClient`
/// por cuenta, ni `deviceModel()`, que son los que decide la fase 8. [SyncSession.open] es el
/// único punto de unión que esta fase puede dejar listo: la fase 8 solo tiene que llamarlo desde
/// `onUnlocked` (con el `HttpClient` y el nombre de dispositivo que ella construya) y a [close]
/// desde `onSignedOut` o al bloquear, y pasarle sus propios `onSessionExpired`/`onDeviceRevoked`
/// (cerrar sesión y pedir inicio de sesión otra vez; borrar la copia local).
///
/// Monta, en orden: `LocalDatabase.open` (la base cifrada de la cuenta) → `RemoteSyncTransport`
/// (sobre el `HttpClient` que recibe, uno por cuenta según la fase 8) → `SyncEngine` (con el
/// `ItemCodec` que ya expone `LocalDatabase`) → `SyncController.attach` → `SyncTriggers.start`
/// (con el `SyncStore` de esa misma base). [close] lo deshace en el orden inverso.
class SyncSession {
  SyncSession._(this._ref, this.local, this.engine);

  final Ref _ref;

  /// La base local de la cuenta: la fase 8 también la necesita para los repositorios de notas y
  /// carpetas (`local.notes`/`local.folders`), no solo para sincronizar.
  final LocalDatabase local;
  final SyncEngine engine;

  /// Abre la base local de [userId] en [directory] y monta el motor de sincronización sobre ella.
  /// Con el cofre bloqueado lanza `AppFailure(locked)` (igual que `LocalDatabase.open`): quien
  /// llama debe desbloquear antes de abrir una sesión de sincronización.
  static Future<SyncSession> open({
    required Ref ref,
    required Vault vault,
    required String userId,
    required Directory directory,
    required HttpClient http,
    required String deviceId,
    required String deviceName,
    void Function()? onSessionExpired,
    void Function()? onDeviceRevoked,
    DateTime Function()? now,
  }) async {
    final local = await LocalDatabase.open(
      directory: directory,
      userId: userId,
      vault: vault,
      deviceId: deviceId,
      deviceName: deviceName,
      now: now,
    );
    final engine = SyncEngine(
      store: local.syncStore,
      transport: RemoteSyncTransport(
        SyncApi(http),
        deviceId: deviceId,
        deviceName: deviceName,
      ),
      codec: local.itemCodec,
    );
    final controller = ref.read(syncControllerProvider.notifier);
    controller.onSessionExpired = onSessionExpired;
    controller.onDeviceRevoked = onDeviceRevoked;
    controller.attach(engine);
    ref.read(syncTriggersProvider).start(store: local.syncStore);
    return SyncSession._(ref, local, engine);
  }

  /// Al bloquear o cerrar sesión (A3): para los disparadores, suelta el motor del controlador
  /// (vuelve a `SyncUiState.empty`) y cierra la base, en ese orden — para que nada intente
  /// sincronizar mientras la base ya se está cerrando.
  Future<void> close() async {
    _ref.read(syncTriggersProvider).stop();
    _ref.read(syncControllerProvider.notifier).detach();
    await local.close();
  }
}
