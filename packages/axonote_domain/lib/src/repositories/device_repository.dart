import '../account.dart';

/// Dispositivos con sesión activa y su revocación (`/devices`). Lo implementa `app/lib/data`.
abstract interface class DeviceRepository {
  /// Dispositivos con sesión activa (el de esta sesión marcado con `current`).
  Future<List<Device>> list();

  /// Cierra la sesión de otro dispositivo (`DELETE /devices/{id}`).
  Future<void> remove(String deviceId);
}

/// Uso de espacio de la cuenta (`/storage/usage`). Lo implementa `app/lib/data`.
abstract interface class StorageRepository {
  Future<StorageUsage> usage();
}
