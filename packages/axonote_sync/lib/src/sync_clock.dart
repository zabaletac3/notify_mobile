import 'package:axonote_domain/axonote_domain.dart';

/// Reloj inyectable del motor (nada de `DateTime.now()` directo, ALCANCE de la fase 7): da el
/// instante que se guarda como `lastSyncedAt` y el de cada conflicto detectado.
abstract interface class SyncClock {
  /// Instante actual, en el mismo formato que viaja en el contrato (ISO 8601 UTC, milisegundos).
  IsoDate now();
}

/// Reloj real: el del sistema.
class SystemSyncClock implements SyncClock {
  const SystemSyncClock();

  @override
  IsoDate now() => nowIso();
}
