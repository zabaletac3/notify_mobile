import 'dart:async';

import 'package:axonote_domain/axonote_domain.dart';
import 'package:connectivity_plus/connectivity_plus.dart'
    show ConnectivityResult;
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

/// Primera espera del reintento ante `network`/`server` (plan §7): 2 s → 4 → 8 … hasta
/// [_maxBackoffDelay].
const Duration _initialBackoffDelay = Duration(seconds: 2);

/// Tope del reintento ante `network`/`server` (plan §7).
const Duration _maxBackoffDelay = Duration(seconds: 60);

/// Espera por defecto ante `rate-limited` sin `retryAfterSec` (no debería pasar: el contrato
/// siempre lo manda, pero el disparador no puede quedarse sin ninguna espera).
const Duration _defaultRateLimitWait = Duration(seconds: 30);

/// Disparadores de la sincronización (D7): al desbloquear, 3 s tras un cambio local (con
/// rebote), cada 60 s y al recuperar la red. Respetan `autoSync` y `wifiOnly`
/// ([SyncSettings]); se detienen al bloquear y al cerrar sesión.
///
/// **Política de errores (plan §7).** Tras cada intento, [_handleResult] mira
/// `SyncController.state.lastError`:
/// - `network`/`server`: reintento con espera exponencial (2 s → 4 → 8 … tope 60 s), que se
///   reinicia a 2 s tras una sincronización correcta y se cancela en [stop]. Recuperar la red
///   también reinicia la espera y sincroniza ya (no hace falta esperar al reintento programado).
/// - `rate-limited`: no se sincroniza por ningún disparador (sondeo, rebote ni red) hasta pasar
///   `retryAfterSec`; pasado ese plazo, se reintenta solo.
/// - `forbidden` (incluye `quota-exceeded`/`limit-reached`, ver `docs/decisions.md` fase 4) y
///   cualquier otro `kind` persistente: sin bucle de reintento propio — el aviso ya lo muestra
///   `SyncController.state.lastError`, y el siguiente disparador normal (sondeo, cambio local o
///   red) lo volverá a intentar sin ayuda adicional de esta clase.
///
/// Reutiliza [TimerFactory] de `features/vault/state` (ya pensado para esto: inyectable, con una
/// versión falsa para pruebas que no espera tiempo real) en vez de duplicarlo.
///
/// No conoce `axonote_sync` ni `drift` directamente: solo las interfaces de `axonote_domain`
/// (`SyncStore.localChanges` como señal de "algo cambió en la cola" y para leer los ajustes) y
/// [SyncController] (que es quien sabe hablar con el motor y quien guarda `lastError`). [start]
/// recibe el almacén de quien abrió la base local (fase 8); antes de eso no hay nada que observar.
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
  StreamSubscription<void>? _localChangesSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  CancelableTimer? _debounceTimer;
  CancelableTimer? _pollTimer;
  CancelableTimer? _backoffTimer;
  CancelableTimer? _suppressTimer;
  Duration _nextBackoffDelay = _initialBackoffDelay;

  /// `true` mientras dure la espera de `rate-limited`: ningún disparador sincroniza.
  bool _suppressed = false;

  /// Evita que dos disparadores a la vez (p. ej. el sondeo y el rebote) entren a la política de
  /// reintento por separado para el mismo intento.
  bool _syncing = false;

  bool get isRunning => _store != null;

  bool get _unlocked => ref.read(sessionProvider) == AxoSession.unlocked;

  /// Arranca los cuatro disparadores. Lo llama quien acaba de desbloquear (abrió la base local y
  /// montó el `SyncEngine` en [SyncController.attach]), con el `SyncStore` de esa base.
  void start({required SyncStore store}) {
    stop();
    _store = store;
    _localChangesSub = store.localChanges.listen((_) => _debounce());
    _connectivitySub = _connectivity.onChanged.listen((results) {
      if (!hasAnyConnection(results)) return;
      // Recuperar la red reinicia la espera del reintento (plan §7) y sincroniza ya, sin esperar
      // al reintento que ya hubiera programado (pero respeta `rate-limited`: eso lo decide
      // `_maybeSync` por su cuenta).
      _backoffTimer?.cancel();
      _backoffTimer = null;
      _nextBackoffDelay = _initialBackoffDelay;
      unawaited(_maybeSync());
    });
    _schedulePoll();
    unawaited(_maybeSync()); // al desbloquear.
  }

  /// Para al bloquear o cerrar sesión (plan §7): sin base abierta no hay nada que observar ni que
  /// sincronizar (A3), y se cancela cualquier reintento o espera pendiente.
  void stop() {
    _localChangesSub?.cancel();
    _connectivitySub?.cancel();
    _debounceTimer?.cancel();
    _pollTimer?.cancel();
    _backoffTimer?.cancel();
    _suppressTimer?.cancel();
    _localChangesSub = null;
    _connectivitySub = null;
    _debounceTimer = null;
    _pollTimer = null;
    _backoffTimer = null;
    _suppressTimer = null;
    _nextBackoffDelay = _initialBackoffDelay;
    _suppressed = false;
    _syncing = false;
    _store = null;
  }

  void _debounce() {
    _debounceTimer?.cancel();
    _debounceTimer = timerFactory.schedule(
      syncDebounceDelay,
      () => unawaited(_debouncedSync()),
    );
  }

  /// El rebote solo tiene sentido si hay algo que subir: `SyncStore.localChanges` avisa de
  /// cualquier escritura en `outbox` (incluida la que hace `applyResult` al vaciar una entrada ya
  /// aplicada), así que sin esta comprobación cada descarga remota programaría una sincronización
  /// de más 3 s después.
  Future<void> _debouncedSync() async {
    final store = _store;
    if (store == null) return;
    if (await store.pendingCount() == 0) return;
    await _maybeSync();
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
    if (store == null || !_unlocked || _suppressed || _syncing) return;
    final settings = await readSyncSettings(store);
    if (!settings.autoSync) return;
    if (settings.wifiOnly) {
      final results = await _connectivity.check();
      if (!isWifiOrEthernet(results)) return;
    }
    _syncing = true;
    try {
      await ref.read(syncControllerProvider.notifier).syncNow();
    } finally {
      _syncing = false;
    }
    if (_store == null)
      return; // se bloqueó o cerró sesión durante la sincronización.
    _handleResult(ref.read(syncControllerProvider).lastError);
  }

  /// Decide qué hacer tras un intento, según `lastError` (plan §7, ver la documentación de la
  /// clase). `null` es éxito: reinicia la espera del reintento a su valor inicial.
  void _handleResult(AppError? error) {
    _backoffTimer?.cancel();
    _backoffTimer = null;
    if (error == null) {
      _nextBackoffDelay = _initialBackoffDelay;
      return;
    }
    switch (error.kind) {
      case 'network':
      case 'server':
        _scheduleBackoff();
      case 'rate-limited':
        _scheduleSuppression(error as RateLimitedError);
      default:
        // forbidden/quota-exceeded/limit-reached y cualquier otro kind persistente: sin bucle de
        // reintento propio. El aviso ya lo lleva `SyncController.state.lastError`; el próximo
        // disparador normal (sondeo, cambio local o red) lo reintentará sin ayuda extra.
        break;
    }
  }

  void _scheduleBackoff() {
    final delay = _nextBackoffDelay;
    _backoffTimer = timerFactory.schedule(delay, () {
      _backoffTimer = null;
      unawaited(_maybeSync());
    });
    final doubled = delay * 2;
    _nextBackoffDelay = doubled > _maxBackoffDelay ? _maxBackoffDelay : doubled;
  }

  void _scheduleSuppression(RateLimitedError error) {
    _suppressTimer?.cancel();
    final wait = error.retryAfterSec != null
        ? Duration(seconds: error.retryAfterSec!)
        : _defaultRateLimitWait;
    _suppressed = true;
    _suppressTimer = timerFactory.schedule(wait, () {
      _suppressed = false;
      _suppressTimer = null;
      unawaited(_maybeSync());
    });
  }
}

final syncTriggersProvider = Provider<SyncTriggers>((ref) {
  final triggers = SyncTriggers(ref: ref);
  ref.onDispose(triggers.stop);
  return triggers;
});
