import 'dart:async';

import 'package:axonote_domain/axonote_domain.dart';
import 'package:connectivity_plus/connectivity_plus.dart' show ConnectivityResult;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session.dart';
import '../../vault/state/timer_factory.dart';
import 'connectivity_probe.dart';
import 'sync_controller.dart';
import 'sync_settings.dart';

/// 3 s después del último cambio local (plan §7, D7).
const Duration syncDebounceDelay = Duration(seconds: 3);

/// Cada 60 s, mientras haya sesión desbloqueada (plan §7, D7).
const Duration syncPollInterval = Duration(seconds: 60);

/// Disparadores de la sincronización (D7): al desbloquear, 3 s tras un cambio local (con
/// rebote), cada 60 s y al recuperar la red. Respetan `autoSync` y `wifiOnly`
/// ([SyncSettings]); se detienen al bloquear y al cerrar sesión.
///
/// Reutiliza [TimerFactory] de `features/vault/state` (ya pensado para esto: inyectable, con una
/// versión falsa para pruebas que no espera tiempo real) en vez de duplicarlo.
///
/// No conoce `axonote_sync` ni `drift` directamente: solo las interfaces de `axonote_domain`
/// ([NoteRepository]/[FolderRepository] como señal de "algo cambió en local", [SyncStore] para
/// leer los ajustes) y [SyncController] (que es quien sabe hablar con el motor). [start] los
/// recibe de quien abrió la base local (fase 8); antes de eso no hay nada que observar.
class SyncTriggers {
  SyncTriggers({
    required this.ref,
    ConnectivityProbe? connectivity,
    this.timerFactory = const RealTimerFactory(),
  }) : _connectivity = connectivity ?? PluginConnectivityProbe();

  final Ref ref;
  final TimerFactory timerFactory;
  final ConnectivityProbe _connectivity;

  SyncStore? _store;
  StreamSubscription<void>? _notesSub;
  StreamSubscription<void>? _foldersSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  CancelableTimer? _debounceTimer;
  CancelableTimer? _pollTimer;

  bool get isRunning => _store != null;

  bool get _unlocked => ref.read(sessionProvider) == AxoSession.unlocked;

  /// Arranca los cuatro disparadores. Lo llama quien acaba de desbloquear (abrió la base local y
  /// montó el `SyncEngine` en [SyncController.attach]), con los mismos repositorios de esa base.
  void start({
    required NoteRepository notes,
    required FolderRepository folders,
    required SyncStore store,
  }) {
    stop();
    _store = store;
    _notesSub = notes.watch().listen((_) => _debounce());
    _foldersSub = folders.watch().listen((_) => _debounce());
    _connectivitySub = _connectivity.onChanged.listen((results) {
      if (hasAnyConnection(results)) unawaited(_maybeSync());
    });
    _schedulePoll();
    unawaited(_maybeSync()); // al desbloquear.
  }

  /// Para al bloquear o cerrar sesión (plan §7): sin base abierta no hay nada que observar ni que
  /// sincronizar (A3).
  void stop() {
    _notesSub?.cancel();
    _foldersSub?.cancel();
    _connectivitySub?.cancel();
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
    _notesSub = null;
    _foldersSub = null;
    _connectivitySub = null;
    _debounceTimer = null;
    _pollTimer = null;
    _store = null;
  }

  void _debounce() {
    _debounceTimer?.cancel();
    _debounceTimer = timerFactory.schedule(
      syncDebounceDelay,
      () => unawaited(_maybeSync()),
    );
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    _pollTimer = timerFactory.schedule(syncPollInterval, () {
      unawaited(_maybeSync());
      _schedulePoll();
    });
  }

  Future<void> _maybeSync() async {
    final store = _store;
    if (store == null || !_unlocked) return;
    final settings = await readSyncSettings(store);
    if (!settings.autoSync) return;
    if (settings.wifiOnly) {
      final results = await _connectivity.check();
      if (!isWifiOrEthernet(results)) return;
    }
    await ref.read(syncControllerProvider.notifier).syncNow();
  }
}

final syncTriggersProvider = Provider<SyncTriggers>((ref) {
  final triggers = SyncTriggers(ref: ref);
  ref.onDispose(triggers.stop);
  return triggers;
});
