import 'ids.dart';

/// Fase de la sincronización (la barra de estado y los avisos se derivan de aquí).
enum SyncPhase { idle, syncing, offline, error }

/// Una versión de la nota involucrada en un conflicto.
class NoteVersion {
  const NoteVersion({
    required this.title,
    required this.content,
    required this.editedAt,
    required this.deviceName,
  });

  final String title;
  final String content;
  final IsoDate editedAt;
  final String deviceName;
}

/// La misma nota se editó en dos dispositivos a la vez.
class Conflict {
  const Conflict({
    required this.noteId,
    required this.local,
    required this.remote,
  });

  final Id noteId;
  final NoteVersion local;
  final NoteVersion remote;
}

/// `local` = conservar esta versión · `remote` = usar la de la nube · `both` = conservar ambas.
enum ConflictResolution { local, remote, both }

/// Estado agregado de la sincronización, para el indicador de la interfaz.
class SyncSnapshot {
  const SyncSnapshot({
    required this.phase,
    required this.lastSyncedAt,
    required this.pendingCount,
    required this.conflicts,
  });

  final SyncPhase phase;
  final IsoDate? lastSyncedAt;

  /// Cambios locales que aún no se subieron.
  final int pendingCount;
  final List<Conflict> conflicts;
}
