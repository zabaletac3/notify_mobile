import 'package:axonote_api/axonote_api.dart';

import '../secure/account_secure_store.dart';

/// `TokenStore` de `axonote_api` sobre el almacén seguro de la cuenta (plan §5.1): tokens de
/// sesión en `flutter_secure_storage`. El borrado solo afecta a los tokens (`clearTokens`), no a la
/// identidad ni al `KeyBundle`, para no perder el desbloqueo sin red cuando el servidor rechaza la
/// renovación.
class AccountTokenStore implements TokenStore {
  AccountTokenStore(this._account);

  final AccountSecureStore _account;

  @override
  Future<StoredTokens?> read() async {
    final access = await _account.readAccessToken();
    final refresh = await _account.readRefreshToken();
    if (access == null || refresh == null) return null;
    return StoredTokens(
      accessToken: access,
      refreshToken: refresh,
      expiresAt: await _account.readExpiresAt() ?? '',
    );
  }

  @override
  Future<void> write(StoredTokens tokens) => _account.updateTokens(
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    expiresAt: tokens.expiresAt,
  );

  @override
  Future<void> clear() => _account.clearTokens();
}
