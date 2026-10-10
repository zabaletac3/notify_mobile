/// Dónde se guardan los tokens de sesión entre ejecuciones. El paquete no decide el mecanismo:
/// la app inyecta un almacén sobre `flutter_secure_storage` (§5.1 del plan); las pruebas, uno en
/// memoria. El token de acceso dura minutos; el de renovación se rota en cada uso y es un secreto:
/// nunca se registra ni se manda a otro origen que la API.
library;

/// Tokens de la sesión con el servidor.
class StoredTokens {
  const StoredTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;

  /// Vence el token de acceso (ISO 8601, tal como lo entrega el contrato).
  final String expiresAt;

  // Sin `toString` propio: el de `Object` no imprime los campos, así que un registro accidental de
  // este objeto no puede filtrar los tokens.
}

/// Interfaz del almacén de tokens, inyectada por la app.
abstract interface class TokenStore {
  Future<StoredTokens?> read();

  Future<void> write(StoredTokens tokens);

  Future<void> clear();
}

/// Almacén en memoria (pruebas y arranques efímeros).
class MemoryTokenStore implements TokenStore {
  StoredTokens? _tokens;

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> write(StoredTokens tokens) async {
    _tokens = tokens;
  }

  @override
  Future<void> clear() async {
    _tokens = null;
  }
}
