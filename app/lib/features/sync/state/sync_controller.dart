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
    lastError: identical(lastError, _unset) ? this.lastError : lastError as AppError?,
  );

  static const Object _unset = Object();
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
  Future<void> refresh() async {
    final engine = _engine;
    if (engine == null) return;
    state = _toUiState(await engine.snapshot(), state.lastError);
  }

  /// Sincroniza ahora. No lanza: el fallo (si lo hay) queda en `state.lastError`, salvo
  /// `session-expired`/`device-revoked`, que disparan sus avisos y no se muestran como aviso
  /// persistente (ya los atiende quien cierra la sesión).
  Future<void> syncNow() async {
    final engine = _engine;
    if (engine == null) return;
    state = state.copyWith(phase: SyncPhase.syncing);
    AppError? error;
    try {
      await engine.syncNow();
    } on AppFailure catch (failure) {
      error = failure.error;
      if (error is SessionExpiredError) {
        error = null;
        onSessionExpired?.call();
      } else if (error is DeviceRevokedError) {
        error = null;
        onDeviceRevoked?.call();
      }
    }
    final engineAfter = _engine;
    if (engineAfter == null) return; // se cerró sesión durante la sincronización.
    state = _toUiState(await engineAfter.snapshot(), error);
  }

  /// Resuelve un conflicto (`local`, `remote` o `both`) y refresca el estado.
  Future<void> resolveConflict(Id noteId, ConflictResolution resolution) async {
    final engine = _engine;
    if (engine == null) return;
    state = _toUiState(
      await engine.resolveConflict(noteId, resolution),
      state.lastError,
    );
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
