import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/crypto/vault.dart';

/// Punto de extensión entre la fase 8 (cuenta) y la fase 7 (sincronización).
///
/// La fase 7 necesita saber cuándo se desbloquea el cofre (para abrir la base local y disparar la
/// sincronización) y cuándo se cierra la sesión (para cerrar la base). La fase 8 **no implementa
/// la sincronización**: solo llama a estos ganchos. La fase 7 sustituirá
/// [vaultLifecycleProvider] por una implementación real (por ejemplo, con
/// `LocalDatabase.open` y el motor de `axonote_sync`).
class VaultLifecycle {
  const VaultLifecycle({this.onUnlocked, this.onSignedOut});

  /// Sin implementación todavía (fase 8): todo es no-op.
  static const VaultLifecycle none = VaultLifecycle();

  /// Tras desbloquear: la fase 7 abrirá la base local y sincronizará.
  final Future<void> Function(String userId, Vault vault)? onUnlocked;

  /// Tras cerrar sesión o recibir `device-revoked`: la fase 7 cerrará la base.
  final Future<void> Function(String? userId)? onSignedOut;
}

/// Implementación por defecto: no-op. La fase 7 sobrescribe este proveedor.
final vaultLifecycleProvider = Provider<VaultLifecycle>(
  (ref) => VaultLifecycle.none,
);
