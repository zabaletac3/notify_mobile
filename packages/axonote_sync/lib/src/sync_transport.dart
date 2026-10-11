import 'package:axonote_domain/axonote_domain.dart';

/// Cuerpo de un `POST /sync`, en tipos de dominio (plan §7). El [SyncTransport] lo traduce a DTO
/// y de vuelta; el motor nunca ve JSON ni bytes HTTP.
///
/// [changes] son las entradas de la cola a subir, ya con `noteData`/`folderData` rellenos para los
/// `upsert` (el motor las cifra con [ItemCodec] desde la fila actual antes de construir la
/// petición; en un `delete` ambos quedan en `null`). En la segunda página en adelante de una
/// misma `syncNow()`, [changes] va vacía (§7: "repetir sin cambios que subir").
class SyncRequest {
  const SyncRequest({required this.cursor, required this.changes});

  /// Último cursor guardado, o `null` la primera vez.
  final String? cursor;
  final List<OutboxEntry> changes;
}

/// Respuesta de un `POST /sync`, en tipos de dominio.
class SyncResponse {
  const SyncResponse({
    required this.cursor,
    required this.hasMore,
    required this.applied,
    required this.conflicts,
    required this.remoteChanges,
  });

  final String cursor;

  /// Hay más cambios remotos por bajar: repetir `POST /sync` con este cursor y sin cambios nuevos.
  final bool hasMore;
  final List<AppliedChange> applied;
  final List<ConflictReport> conflicts;
  final List<RemoteChange> remoteChanges;
}

/// Canal de sincronización (`POST /sync`), en tipos de dominio. Lo implementa `app/lib/data`
/// sobre `SyncApi` (`axonote_api`): mapea DTO ↔ dominio y traduce los fallos HTTP a `AppFailure`
/// (eso ya lo hace `HttpClient`, §4 de la fase 4; el adaptador solo traduce formas).
///
/// Lanza `AppFailure` ante cualquier fallo (red, servidor, sesión, etc.); el motor no captura
/// nada aquí: la política de reintentos y la reacción a cada `kind` vive en
/// `app/lib/features/sync/state` (fuera del motor, que no usa `Timer`, ver plan §7 y ALCANCE).
abstract interface class SyncTransport {
  Future<SyncResponse> sync(SyncRequest request);
}
