import 'dart:async';

import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado de la sincronización para la interfaz (mismo papel que `SyncState` en
/// `notify_web/src/lib/features/sync/state/sync.svelte.ts`): fase, pendientes, conflictos y
/// último error. `ui` solo habla con esto; nunca con `SyncEngine` ni con `axonote_domain`
/// directamente más que por estos tipos (plan §4.2).
class SyncUiState {
  const SyncUiState({
    required this.phase,
    required this.pendingCount,
    required this.conflicts,
    required this.lastSyncedAt,
    this.lastError,
  });

  static const SyncUiState empty = SyncUiState(
    phase: SyncPhase.idle,
    pendingCount: 0,
    conflicts: [],
    lastSyncedAt: null,
  );

  final SyncPhase phase;
  final int pendingCount;
  final List<Conflict> conflicts;
  final IsoDate? lastSyncedAt;

  /// Error de la última sincronización. Se limpia al lograr una (igual que la web).
  final AppError? lastError;

  /// Primer conflicto sin resolver (el diálogo resuelve de a uno).
  Conflict? get firstConflict => conflicts.isEmpty ? null : conflicts.first;

  SyncUiState copyWith({
    SyncPhase? phase,
    int? pendingCount,
    List<Conflict>? conflicts,
    IsoDate? lastSyncedAt,
    Object? lastError = _unset,
  }) => SyncUiState(
    phase: phase ?? this.phase,
    pendingCount: pendingCount ?? this.pendingCount,
    conflicts: conflicts ?? this.conflicts,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    lastError: identical(lastError, _unset)
        ? this.lastError
        : lastError as AppError?,
  );

  static const Object _unset = Object();

  /// Compara por valor (fase, pendientes, ids de los conflictos, última sincronización y
  /// `kind` del error — nunca el contenido de un `Conflict`/`AppError`, que podría llevar texto
  /// de notas), para que las pruebas puedan comparar estados reconstruidos sin depender de que
  /// sea exactamente la misma instancia.
  @override
  bool operator ==(Object other) =>
      other is SyncUiState &&
      other.phase == phase &&
      other.pendingCount == pendingCount &&
      other.lastSyncedAt == lastSyncedAt &&
      other.lastError?.kind == lastError?.kind &&
      _sameConflictIds(other.conflicts, conflicts);

  @override
  int get hashCode => Object.hash(
    phase,
    pendingCount,
    lastSyncedAt,
    lastError?.kind,
    Object.hashAll(conflicts.map((c) => c.noteId)),
  );

  /// Sin contenido de notas: solo lo que hace falta para leer un fallo de prueba de un vistazo.
  @override
  String toString() =>
      'SyncUiState(phase: $phase, pendingCount: $pendingCount, '
      'conflicts: ${conflicts.length}, lastSyncedAt: $lastSyncedAt, '
      'lastError: ${lastError?.kind})';
}

bool _sameConflictIds(List<Conflict> a, List<Conflict> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].noteId != b[i].noteId) return false;
  }
  return true;
}

/// Controlador de la sincronización (plan §7). No sabe nada de `Timer` ni de conectividad: eso
/// son los disparadores (`sync_triggers.dart`), que lo llaman. Tampoco sabe nada de `drift`: solo
/// habla con el `SyncEngine` que le entrega [attach] (lo monta `app/lib/data` al abrir la base,
/// fase 8).
///
/// Errores (plan §7): `session-expired` y `device-revoked` no quedan como `lastError` (los
/// atiende [onSessionExpired]/[onDeviceRevoked], que cierran la sesión o borran la copia local:
/// eso lo conecta la fase 8, igual que `SyncState.handleFailure` en la web); el resto
/// (`network`, `server`, `forbidden`, `rate-limited`…) sí, para el aviso persistente. Ninguno
/// vacía la cola: eso lo decide `SyncStore.applyResult`, no esta clase.
class SyncController extends Notifier<SyncUiState> {
  @override
  SyncUiState build() => SyncUiState.empty;

  SyncEngine? _engine;

  /// Se llama cuando el servidor dice que la sesión venció (tras el reintento único que ya hace
  /// `HttpClient`). Lo conecta la fase 8 (cierra sesión y pide iniciar sesión otra vez).
  void Function()? onSessionExpired;

  /// Se llama cuando este dispositivo fue eliminado de la cuenta desde otro (A1: borrado local y
  /// pantalla de inicio de sesión). Lo conecta la fase 8.
  void Function()? onDeviceRevoked;

  /// El motor ya montado sobre la base recién abierta. Llamarlo de nuevo sustituye el anterior
  /// (p. ej. al cambiar de cuenta).
  void attach(SyncEngine engine) {
    _engine = engine;
    unawaited(refresh());
  }

  /// Al bloquear o cerrar sesión: sin motor no hay nada que sincronizar (A3, «con el cofre
  /// bloqueado no se sincroniza»).
  void detach() {
    _engine = null;
    state = SyncUiState.empty;
  }

  bool get isAttached => _engine != null;

  /// Relee el estado del almacén sin ir al servidor (al adjuntar y tras cada sincronización).
  ///
  /// [attach] la llama sin esperarla (`unawaited`), así que un fallo sin capturar aquí se
  /// convertiría en un error de zona sin dueño en vez de quedar en el estado; por eso protege la
  /// lectura igual que [syncNow] protege la suya: la fase pasa a `error`, nunca se propaga. Y, tras
  /// el `await`, comprueba que sigue siendo el mismo motor con el que empezó: si [detach] (o un
  /// [attach] con otro motor) ocurrió mientras tanto, no toca `state` — lo que haya dejado eso es
  /// lo correcto, no el resultado de un motor que ya no es el actual.
  Future<void> refresh() async {
    final engine = _engine;
    if (engine == null) return;
    SyncSnapshot? snapshot;
    try {
      snapshot = await engine.snapshot();
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // se gestiona abajo: `snapshot` queda null.
    }
    if (!identical(_engine, engine)) return;
    state = snapshot == null
        ? state.copyWith(
            phase: SyncPhase.error,
            lastError: state.lastError ?? const UnknownError(),
          )
        : _toUiState(snapshot, state.lastError);
  }

  /// Sincroniza ahora. No lanza: el fallo (si lo hay) queda en `state.lastError`, salvo
  /// `session-expired`/`device-revoked` (disparan su aviso y no se muestran como aviso
  /// persistente: ya los atiende quien cierra la sesión) y `locked` (A3: si el cofre se bloquea a
  /// mitad de la sincronización, se descarta en silencio, sin aviso ni reintento — bloquear ya
  /// para los disparadores por su cuenta).
  ///
  /// Cualquier fallo que no sea `AppFailure` (p. ej. un `StateError` de un dato interno
  /// inconsistente, o cualquier otra excepción no prevista) se convierte en un `UnknownError`
  /// genérico: nunca se expone el mensaje de la excepción a la interfaz ni a un registro, porque
  /// podría llevar datos de la persona. Por el mismo motivo se protege también el `snapshot()`
  /// posterior: si leer el almacén fallara, la fase pasa a `error` igualmente en vez de quedarse
  /// en `syncing` para siempre.
  ///
  /// Tras CADA `await` comprueba que `_engine` sigue siendo el mismo con el que empezó: un
  /// [detach] (o un [attach] con otro motor) durante `engine.syncNow()` o durante el
  /// `snapshot()` posterior no debe pisar el estado que haya dejado eso — ni con el resultado
  /// viejo ni con un `error` que ya no describe nada vigente.
  Future<void> syncNow() async {
    final engine = _engine;
    if (engine == null) return;
    state = state.copyWith(phase: SyncPhase.syncing);
    AppError? error;
    try {
      await engine.syncNow();
      // ignore: avoid_catches_without_on_clauses
    } catch (failure) {
      error = failure is AppFailure ? failure.error : const UnknownError();
      if (error is SessionExpiredError) {
        error = null;
        onSessionExpired?.call();
      } else if (error is DeviceRevokedError) {
        error = null;
        onDeviceRevoked?.call();
      } else if (error is LockedError) {
        error = null;
      }
    }
    if (!identical(_engine, engine)) {
      return; // se soltó o se sustituyó el motor mientras sincronizaba.
    }
    SyncSnapshot? snapshot;
    try {
      snapshot = await engine.snapshot();
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      error ??= const UnknownError();
    }
    if (!identical(_engine, engine)) {
      return; // se soltó o se sustituyó el motor mientras se leía el snapshot.
    }
    state = snapshot == null
        ? state.copyWith(phase: SyncPhase.error, lastError: error)
        : _toUiState(snapshot, error);
  }

  /// Resuelve un conflicto (`local`, `remote` o `both`) y refresca el estado. Mismo cuidado que
  /// [syncNow]/[refresh]: si el motor cambió mientras se resolvía, no toca `state`.
  Future<void> resolveConflict(Id noteId, ConflictResolution resolution) async {
    final engine = _engine;
    if (engine == null) return;
    final snapshot = await engine.resolveConflict(noteId, resolution);
    if (!identical(_engine, engine)) return;
    state = _toUiState(snapshot, state.lastError);
  }

  SyncUiState _toUiState(SyncSnapshot snapshot, AppError? lastError) {
    final phase = switch (lastError?.kind) {
      null => snapshot.phase,
      'network' => SyncPhase.offline,
      _ => SyncPhase.error,
    };
    return SyncUiState(
      phase: phase,
      pendingCount: snapshot.pendingCount,
      conflicts: snapshot.conflicts,
      lastSyncedAt: snapshot.lastSyncedAt,
      lastError: lastError,
    );
  }
}

final syncControllerProvider = NotifierProvider<SyncController, SyncUiState>(
  SyncController.new,
);
