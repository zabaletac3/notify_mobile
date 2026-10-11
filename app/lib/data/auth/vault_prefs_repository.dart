import 'package:axonote_domain/axonote_domain.dart';

import '../secure/account_secure_store.dart';

/// Implementación de [VaultPrefsRepository] y [VaultActivityStore] sobre el almacén seguro de la
/// cuenta (`flutter_secure_storage`, ver plan §5.1). Las preferencias de bloqueo son por cuenta y
/// no se sincronizan; la última actividad se guarda para recalcular el tiempo de bloqueo tras un
/// arranque en frío (§5.3).
class SecureVaultPrefs implements VaultPrefsRepository, VaultActivityStore {
  SecureVaultPrefs(this._account);

  final AccountSecureStore _account;

  @override
  Future<CachedSession?> cachedSession() async {
    final userId = await _account.readUserId();
    if (userId == null) return null;
    return CachedSession(
      userId: userId,
      email: await _account.readEmail() ?? '',
    );
  }

  @override
  Future<LockSettings> readLockSettings(String userId) =>
      _account.readLockSettings(userId);

  @override
  Future<void> writeLockSettings(String userId, LockSettings settings) =>
      _account.writeLockSettings(userId, settings);

  @override
  Future<DateTime?> readLastActiveAt(String userId) =>
      _account.readLastActiveAt(userId);

  @override
  Future<void> clearSession() => _account.clearSession();

  @override
  Future<DateTime?> read(String userId) => _account.readLastActiveAt(userId);

  @override
  Future<void> write(String userId, DateTime? at) =>
      _account.writeLastActiveAt(userId, at);
}
