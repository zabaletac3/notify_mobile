import 'dart:io';

import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_api/axonote_api.dart' show HttpClient;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/crypto/vault.dart';
import '../data/local/local_account.dart';
import 'sync_session.dart';

/// Sesión local de la cuenta abierta: la base cifrada y el motor de sincronización montados sobre
/// ella (`SyncSession`). Vive aquí porque es lo que necesitan tanto los repositorios de notas y
/// carpetas (fase 9) como el motor de sincronización (fase 7).
///
/// La costura entre las fases 7 y 8 (`vaultLifecycleProvider`) quedó sin conectar: nadie abría la
/// base al desbloquear. La fase 9, que necesita los repositorios para pintar la lista, la cierra:
/// `main.dart` sobrescribe `vaultLifecycleProvider` con una implementación que llama a [open] al
/// desbloquear y a [close] al cerrar sesión o recibir `device-revoked`.
class LocalSessionController extends Notifier<SyncSession?> {
  @override
  SyncSession? build() => null;

  /// Abre la base local de [userId] y monta el motor. Si ya había una sesión abierta, la cierra
  /// antes (cambio de cuenta). Sin cofre desbloqueado, `LocalDatabase.open` lanza
  /// `AppFailure(locked)`.
  Future<void> open({
    required Ref ref,
    required Vault vault,
    required String userId,
    required Directory directory,
    required HttpClient http,
    required String deviceId,
    required String deviceName,
    void Function()? onSessionExpired,
    void Function()? onDeviceRevoked,
  }) async {
    await close();
    final session = await SyncSession.open(
      ref: ref,
      vault: vault,
      userId: userId,
      directory: directory,
      http: http,
      deviceId: deviceId,
      deviceName: deviceName,
      onSessionExpired: onSessionExpired,
      onDeviceRevoked: onDeviceRevoked,
    );
    state = session;
  }

  /// Cierra la base abierta (si la hay) y deja el estado vacío.
  Future<void> close() async {
    final current = state;
    if (current == null) return;
    state = null;
    await current.close();
  }
}

final localSessionProvider =
    NotifierProvider<LocalSessionController, SyncSession?>(
      LocalSessionController.new,
    );

/// La base local de la cuenta abierta, o `null` si el cofre está bloqueado o no hay sesión.
final localDatabaseProvider = Provider<LocalDatabase?>(
  (ref) => ref.watch(localSessionProvider)?.local,
);

/// Repositorio de notas de la cuenta abierta (interfaz del dominio). `null` mientras el cofre
/// está bloqueado o no hay sesión: la interfaz muestra entonces el estado de carga.
final noteRepositoryProvider = Provider<NoteRepository?>(
  (ref) => ref.watch(localDatabaseProvider)?.notes,
);

/// Repositorio de carpetas de la cuenta abierta.
final folderRepositoryProvider = Provider<FolderRepository?>(
  (ref) => ref.watch(localDatabaseProvider)?.folders,
);
