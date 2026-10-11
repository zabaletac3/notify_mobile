import '../lock_settings.dart';

/// Quién tiene sesión guardada en este dispositivo (para el arranque en frío).
class CachedSession {
  const CachedSession({required this.userId, required this.email});

  final String userId;
  final String email;
}

/// Persistencia local de lo que gobierna el cofre y el arranque en frío (plan §5.1, §5.3). Lo
/// implementa `app/lib/data`; el estado solo conoce esta interfaz (plan §4.2).
abstract interface class VaultPrefsRepository {
  /// Cuenta con sesión guardada en este dispositivo, o `null`.
  Future<CachedSession?> cachedSession();

  /// Preferencias de bloqueo de `userId` (§5.3), o los valores por defecto.
  Future<LockSettings> readLockSettings(String userId);

  Future<void> writeLockSettings(String userId, LockSettings settings);

  /// Última actividad real de `userId`, para que el tiempo de bloqueo sobreviva a que el sistema
  /// mate el proceso (plan §5.3).
  Future<DateTime?> readLastActiveAt(String userId);

  /// Borra la sesión local (tokens, identidad y `KeyBundle`) sin tocar las preferencias de bloqueo.
  Future<void> clearSession();
}

/// Escribe la hora de la última actividad para que el tiempo de bloqueo se pueda recalcular tras
/// un arranque en frío. Se inyecta en el gestor de bloqueo para no acoplar `features` a `data`.
abstract interface class VaultActivityStore {
  Future<DateTime?> read(String userId);
  Future<void> write(String userId, DateTime? at);
}

/// Borrado de la copia local de una cuenta (A1 del plan): el archivo de la base cifrada y sus
/// auxiliares. Lo implementa `app/lib/data`. Cerrar sesión o recibir `device-revoked` lo invoca
/// junto con el borrado de las claves locales.
abstract interface class LocalDataCleaner {
  Future<void> wipe(String userId);
}
