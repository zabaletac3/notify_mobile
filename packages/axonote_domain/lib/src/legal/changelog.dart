/// Historial de cambios (portado de `notify_web/src/lib/legal/changelog.ts`).
library;

/// Una versión publicada y los cambios que trae.
class ChangelogEntry {
  const ChangelogEntry({
    required this.version,
    required this.date,
    required this.changes,
  });

  /// Versión, o `null` en la entrada más reciente (que usa la versión actual del paquete).
  final String? version;

  /// Fecha de publicación (`YYYY-MM-DD`).
  final String date;
  final List<String> changes;
}

/// Del más reciente al más antiguo. Solo se describen funciones que existen.
const List<ChangelogEntry> changelog = [
  ChangelogEntry(
    version: null,
    date: '2026-10-08',
    changes: [
      'Notas en Markdown con editor y organización en carpetas.',
      'Búsqueda instantánea en todas tus notas.',
      'Papelera con recuperación durante 30 días.',
      'Enlaces públicos de solo lectura para compartir una nota.',
      'Sincronización entre varios dispositivos y uso sin conexión.',
      'Cifrado de extremo a extremo: las notas se cifran en tu dispositivo.',
      'Eliminar la cuenta ahora exige tu contraseña.',
    ],
  ),
];
