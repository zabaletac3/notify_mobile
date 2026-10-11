import 'package:axonote_domain/axonote_domain.dart';

import 'item_codec.dart';
import 'sync_clock.dart';
import 'sync_transport.dart';

/// Motor de sincronización (plan §7): el ciclo `syncNow()` sobre `SyncStore`, `SyncTransport` e
/// `ItemCodec`.
///
/// Hace **un solo intento** por `syncNow()`, igual que la referencia web
/// (`LocalSyncRepository.syncNow()`/`SyncState.syncNow()`: ninguna reintenta sola). Ante un fallo
/// (`AppFailure`) no se captura nada aquí: se propaga tal cual. La política de qué hacer con cada
/// `kind` — reintentar con espera exponencial ante `network`/`server`, respetar `retryAfterSec` en
/// `rate-limited`, cerrar sesión ante `session-expired`, borrar y pedir inicio de sesión ante
/// `device-revoked`, aviso persistente ante `forbidden` — vive en
/// `app/lib/features/sync/state` (fuera de este paquete puro, que por eso mismo no usa `Timer` ni
/// `DateTime.now()` directos: esa política necesita temporizadores, y el motor no).
class SyncEngine {
  SyncEngine({
    required this.store,
    required this.transport,
    required this.codec,
    SyncClock? clock,
  }) : clock = clock ?? const SystemSyncClock();

  final SyncStore store;
  final SyncTransport transport;
  final ItemCodec codec;
  final SyncClock clock;

  /// Tope de páginas por sincronización (plan §7).
  static const int maxPages = 100;

  Future<void>? _running;

  /// `true` mientras una sincronización está en curso (propia o de una llamada concurrente).
  bool get isSyncing => _running != null;

  /// Sincroniza la cola local con el servidor (plan §7): toma la cola (sin las notas en
  /// conflicto), cifra cada elemento desde su fila actual, la envía con el cursor guardado y
  /// aplica la respuesta en una transacción. Mientras el servidor diga `hasMore`, repite sin
  /// cambios nuevos que subir (tope [maxPages]).
  ///
  /// Una sola ejecución a la vez: si ya hay una en curso, esta llamada espera a esa misma y
  /// recibe su resultado (o su fallo), sin repetirla.
  Future<void> syncNow() {
    final running = _running;
    if (running != null) return running;
    final future = _run();
    _running = future;
    return future.whenComplete(() => _running = null);
  }

  Future<void> _run() async {
    var toSend = await store.pending();
    for (var page = 0; page < maxPages; page++) {
      final sealed = await _seal(toSend);
      final cursor = await store.cursor();
      final response = await transport.sync(
        SyncRequest(cursor: cursor, changes: sealed),
      );
      await store.applyResult(
        sent: sealed,
        applied: response.applied,
        conflicts: response.conflicts,
        remoteChanges: response.remoteChanges,
        cursor: response.cursor,
        now: clock.now(),
      );
      if (!response.hasMore) return;
      toSend = const [];
    }
  }

  /// Cifra desde la fila actual cada entrada `upsert` (A4); un `delete` no lleva datos.
  Future<List<OutboxEntry>> _seal(List<OutboxEntry> entries) async {
    final sealed = <OutboxEntry>[];
    for (final entry in entries) {
      if (entry.op != SyncOp.upsert) {
        sealed.add(entry);
        continue;
      }
      sealed.add(
        OutboxEntry(
          seq: entry.seq,
          entity: entry.entity,
          entityId: entry.entityId,
          op: entry.op,
          baseRevision: entry.baseRevision,
          version: entry.version,
          changedAt: entry.changedAt,
          noteData: entry.entity == SyncEntity.note
              ? await codec.sealNote(entry.entityId)
              : null,
          folderData: entry.entity == SyncEntity.folder
              ? await codec.sealFolder(entry.entityId)
              : null,
        ),
      );
    }
    return sealed;
  }

  /// Resuelve un conflicto (`local`, `remote` o `both`) delegando en el almacén y devuelve el
  /// estado nuevo.
  Future<SyncSnapshot> resolveConflict(
    Id noteId,
    ConflictResolution resolution,
  ) async {
    await store.resolveConflict(noteId, resolution);
    return snapshot();
  }

  /// Estado agregado para la interfaz (pendientes, último conflicto, última sincronización).
  /// `phase` solo distingue `syncing` de `idle`: `offline`/`error` dependen de la conectividad y
  /// del último fallo, que este motor no conoce (los decide quien lo llama, igual que `SyncState`
  /// en la web combina `syncing`/`lastError` con el `snapshot()` del repositorio).
  Future<SyncSnapshot> snapshot() async {
    return SyncSnapshot(
      phase: isSyncing ? SyncPhase.syncing : SyncPhase.idle,
      lastSyncedAt: await store.lastSyncedAt(),
      pendingCount: await store.pendingCount(),
      conflicts: await store.conflicts(),
    );
  }
}
