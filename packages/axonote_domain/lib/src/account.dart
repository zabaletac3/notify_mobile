/// Plataforma de un dispositivo (`DevicePlatform` del contrato).
enum DevicePlatform {
  linux('linux'),
  windows('windows'),
  android('android'),
  web('web');

  const DevicePlatform(this.wire);

  final String wire;
}

/// Dispositivo con sesión activa (`GET /devices`).
class Device {
  const Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.lastActiveAt,
    required this.current,
  });

  final String id;
  final String name;
  final DevicePlatform platform;
  final DateTime lastActiveAt;

  /// `true` en el dispositivo de la sesión actual (no se puede quitar).
  final bool current;
}

/// Uso de espacio de la cuenta (`GET /storage/usage`).
class StorageUsage {
  const StorageUsage({
    required this.usedBytes,
    required this.quotaBytes,
    required this.notesBytes,
    required this.imagesBytes,
    required this.trashBytes,
  });

  final int usedBytes;
  final int quotaBytes;
  final int notesBytes;
  final int imagesBytes;
  final int trashBytes;

  int get availableBytes => (quotaBytes - usedBytes).clamp(0, quotaBytes);

  double get percentUsed => quotaBytes <= 0 ? 0 : usedBytes / quotaBytes;
}
