import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_app/data/local/local_account.dart';
import 'package:axonote_crypto/axonote_crypto.dart';

/// Vault de pruebas: clave maestra aleatoria, sin Argon2.
Vault testVault({SecretKeyBytes? master}) {
  final vault = Vault(userId: 'u_test');
  vault.unlockWith(master ?? generateKeyBytes());
  return vault;
}

/// Base local en memoria con un vault desbloqueado, para las pruebas de repositorios.
class LocalHarness {
  LocalHarness._(this.vault, this.local);

  factory LocalHarness({
    DateTime Function()? now,
    SecretKeyBytes? master,
    String deviceId = 'd_test',
  }) {
    final vault = testVault(master: master);
    final local = LocalDatabase.memory(
      vault: vault,
      deviceId: deviceId,
      now: now,
    );
    return LocalHarness._(vault, local);
  }

  final Vault vault;
  final LocalDatabase local;

  Future<void> close() => local.close();
}
