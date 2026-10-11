import 'package:axonote_domain/axonote_domain.dart';

/// Ajustes que gobiernan la sincronización automática (D7, plan §7), con los mismos nombres y
/// valores por defecto que `DEFAULT_SETTINGS` de `notify_web/src/lib/domain/settings.ts`
/// (`autoSync: true`, `wifiOnly: false`).
///
/// Todavía no hay pantalla de ajustes (llega en la fase 11): se guardan en la tabla `meta` de la
/// base local a través de `SyncStore.readMeta`/`writeMeta` (ya pensada para «ajustes en caché»,
/// plan §6), para que lo que se cambie aquí sobreviva a cerrar la app. La fase 11 solo tiene que
/// llamar a [writeSyncSettings] desde su interruptor; no hace falta otro almacén.
class SyncSettings {
  const SyncSettings({this.autoSync = true, this.wifiOnly = false});

  final bool autoSync;
  final bool wifiOnly;

  SyncSettings copyWith({bool? autoSync, bool? wifiOnly}) => SyncSettings(
    autoSync: autoSync ?? this.autoSync,
    wifiOnly: wifiOnly ?? this.wifiOnly,
  );
}

const String _autoSyncKey = 'autoSync';
const String _wifiOnlyKey = 'wifiOnly';

/// Lee los ajustes guardados, con los valores por defecto si nunca se guardó nada.
Future<SyncSettings> readSyncSettings(SyncStore store) async {
  final autoSync = await store.readMeta(_autoSyncKey);
  final wifiOnly = await store.readMeta(_wifiOnlyKey);
  return SyncSettings(
    autoSync: autoSync == null ? true : autoSync == 'true',
    wifiOnly: wifiOnly == null ? false : wifiOnly == 'true',
  );
}

/// Guarda los ajustes. La fase 11 (pantalla de ajustes) la llama al cambiar un interruptor.
Future<void> writeSyncSettings(SyncStore store, SyncSettings settings) async {
  await store.writeMeta(_autoSyncKey, settings.autoSync.toString());
  await store.writeMeta(_wifiOnlyKey, settings.wifiOnly.toString());
}
