import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../vault/state/vault_lock.dart';

/// Ajustes de bloqueo del cofre (biométrico, bloquear al salir, tiempo de bloqueo). Se persisten por
/// cuenta en el almacén seguro (§5.3) y se aplican al gestor de bloqueo (`VaultLockController`).
class LockSettingsController extends AsyncNotifier<LockSettings> {
  @override
  Future<LockSettings> build() async {
    final userId = (await ref.read(vaultPrefsProvider).cachedSession())?.userId;
    if (userId == null) return const LockSettings();
    return ref.read(vaultPrefsProvider).readLockSettings(userId);
  }

  Future<void> save(LockSettings next) async {
    state = AsyncData(next);
    final userId = (await ref.read(vaultPrefsProvider).cachedSession())?.userId;
    if (userId == null) return;
    await ref.read(vaultPrefsProvider).writeLockSettings(userId, next);
    await ref.read(vaultLockControllerProvider).updateSettings(next);
  }
}

final lockSettingsProvider =
    AsyncNotifierProvider<LockSettingsController, LockSettings>(
      LockSettingsController.new,
    );
