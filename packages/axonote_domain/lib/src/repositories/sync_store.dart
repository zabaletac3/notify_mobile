import '../ids.dart';
import '../sync.dart';
import '../sync_protocol.dart';

/// Almacén de sincronización sobre la base local (plan §7). Lo implementa `app/lib/data` (drift);
/// el motor de sincronización (fase 7 y el paquete `axonote_sync`) solo conoce esta interfaz.
///
/// No transporta ni cifra nada: solo guarda filas y aplica lo que el motor le entrega ya
/// descifrado/cifrado. Los métodos lanzan `AppFailure`.
abstract interface class SyncStore {
  /// Apunta un cambio en la cola fundiéndolo con el que ya hubiera (semántica de `outbox.ts`).
  /// Debe llamarse dentro de la misma transacción que escribe la fila.
  Future<void> enqueue(PendingChange change, IsoDate changedAt);

  /// Cambios pendientes en orden de `seq`, sin las notas que están en conflicto.
  Future<List<OutboxEntry>> pending();

  /// Cuántos cambios hay pendientes de subir.
  Future<int> pendingCount();

  /// Avisa cuando cambia la cola local (se añade, actualiza o borra una entrada de `outbox`).
  /// Nunca emite nada al suscribirse ni el valor que cambió: es solo la señal de "algo cambió",
  /// para que los disparadores (D7, fase 7) sepan cuándo reintentar sin tener que volver a listar
  /// ni a contar la cola entera en cada cambio.
  Stream<void> get localChanges;

  /// Último cursor recibido del servidor, o `null` la primera vez.
  Future<String?> cursor();

  /// Instante de la última sincronización, o `null`.
  Future<IsoDate?> lastSyncedAt();

  /// Lee un valor de `meta` (cursor, lastSyncedAt, deviceId, ajustes en caché…).
  Future<String?> readMeta(String key);

  /// Escribe un valor de `meta`.
  Future<void> writeMeta(String key, String? value);

  /// Aplica la respuesta de un `POST /sync` en una sola transacción: confirma lo aceptado,
  /// guarda conflictos, trae cambios remotos y avanza el cursor.
  Future<void> applyResult({
    required List<OutboxEntry> sent,
    required List<AppliedChange> applied,
    required List<ConflictReport> conflicts,
    required List<RemoteChange> remoteChanges,
    required String cursor,
    required IsoDate now,
  });

  /// Conflictos abiertos, con sus dos versiones descifradas.
  Future<List<Conflict>> conflicts();

  /// Resuelve un conflicto (`local`, `remote` o `both`).
  Future<void> resolveConflict(Id noteId, ConflictResolution resolution);

  /// Enlace público guardado de una nota, o `null`.
  Future<ShareRow?> share(Id noteId);

  /// Guarda (o reemplaza) el enlace público de una nota.
  Future<void> upsertShare(ShareRow share);

  /// Borra el enlace público de una nota.
  Future<void> deleteShare(Id noteId);
}
