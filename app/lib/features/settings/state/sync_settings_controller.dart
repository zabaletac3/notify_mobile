import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/local_session.dart';
import '../../sync/state/sync_settings.dart';

/// Ajustes de sincronización (automática y solo con Wi-Fi). Reutiliza [SyncSettings], que ya los
/// guarda en la tabla `meta` de la base local y los respeta el motor (`sync_triggers`). Sin sesión
/// (base cerrada) devuelve los valores por defecto.
class SyncSettingsController extends AsyncNotifier<SyncSettings> {
  @override
  Future<SyncSettings> build() async {
    final store = ref.watch(localSessionProvider)?.local.syncStore;
    if (store == null) return const SyncSettings();
    return readSyncSettings(store);
  }

  Future<void> setAutoSync(bool value) =>
      _update((s) => s.copyWith(autoSync: value));

  Future<void> setWifiOnly(bool value) =>
      _update((s) => s.copyWith(wifiOnly: value));

  Future<void> _update(SyncSettings Function(SyncSettings) change) async {
    final next = change(state.value ?? const SyncSettings());
    state = AsyncData(next);
    final store = ref.read(localSessionProvider)?.local.syncStore;
    if (store != null) await writeSyncSettings(store, next);
  }
}

final syncSettingsProvider =
    AsyncNotifierProvider<SyncSettingsController, SyncSettings>(
      SyncSettingsController.new,
    );
