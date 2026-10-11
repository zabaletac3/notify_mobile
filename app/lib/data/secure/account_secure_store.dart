import 'dart:convert';

import 'package:axonote_domain/axonote_domain.dart';

import 'secure_store.dart';

/// Datos de la sesión actual (plan §5.1): quién es, cómo hablar con el servidor sin la
/// contraseña, y cómo volver a abrir la clave maestra con la contraseña sin red. La clave maestra
/// **no** está aquí: vive en `axonote_platform`, ligada a biometría (A9 del plan).
class SessionData {
  const SessionData({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.keyBundleJson,
  });

  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;

  /// `KeyBundle` tal como lo sirve el servidor, en JSON (su forma la fija `axonote_api`; este
  /// paquete solo lo guarda y lo devuelve, nunca lo interpreta).
  final String keyBundleJson;
}

/// Almacén seguro de la cuenta (plan §5.1): tokens, identidad y `KeyBundle` en
/// `flutter_secure_storage`; preferencias de bloqueo por cuenta (no se sincronizan, igual que la
/// web). Nada de esto se registra ni se expone en `toString()`.
class AccountSecureStore {
  AccountSecureStore(this._store);

  final SecureStore _store;

  static const _userIdKey = 'session.userId';
  static const _emailKey = 'session.email';
  static const _accessTokenKey = 'session.accessToken';
  static const _refreshTokenKey = 'session.refreshToken';
  static const _keyBundleKey = 'session.keyBundle';
  static const _lockPrefsPrefix = 'lockPrefs.';

  static String _lockPrefsKey(String userId) => '$_lockPrefsPrefix$userId';

  Future<void> saveSession(SessionData session) async {
    await _store.write(_userIdKey, session.userId);
    await _store.write(_emailKey, session.email);
    await _store.write(_accessTokenKey, session.accessToken);
    await _store.write(_refreshTokenKey, session.refreshToken);
    await _store.write(_keyBundleKey, session.keyBundleJson);
  }

  /// Quién tiene sesión guardada en este dispositivo, o `null` si nadie. Sirve para saber con qué
  /// cuenta intentar el desbloqueo con biometría al abrir la app.
  Future<String?> readUserId() => _store.read(_userIdKey);

  Future<String?> readEmail() => _store.read(_emailKey);

  Future<String?> readAccessToken() => _store.read(_accessTokenKey);

  Future<String?> readRefreshToken() => _store.read(_refreshTokenKey);

  Future<String?> readKeyBundleJson() => _store.read(_keyBundleKey);

  /// Tras renovar la sesión con el servidor.
  Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _store.write(_accessTokenKey, accessToken);
    await _store.write(_refreshTokenKey, refreshToken);
  }

  /// Tras cambiar la contraseña o la clave de recuperación (sube `keysVersion`).
  Future<void> updateKeyBundleJson(String keyBundleJson) =>
      _store.write(_keyBundleKey, keyBundleJson);

  /// Borra la sesión guardada (tokens, identidad, `KeyBundle`). Lo llama el gestor de bloqueo al
  /// cerrar sesión o recibir `device-revoked` (A1); no toca las preferencias de bloqueo, que son
  /// de la cuenta, no de la sesión.
  Future<void> clearSession() async {
    await _store.delete(_userIdKey);
    await _store.delete(_emailKey);
    await _store.delete(_accessTokenKey);
    await _store.delete(_refreshTokenKey);
    await _store.delete(_keyBundleKey);
  }

  /// Preferencias de bloqueo de `userId` (§5.3), o los valores por defecto si nunca se guardaron.
  Future<LockSettings> readLockSettings(String userId) async {
    final raw = await _store.read(_lockPrefsKey(userId));
    if (raw == null) return const LockSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const LockSettings();
      return LockSettings(
        biometricLock: decoded['biometricLock'] as bool? ?? true,
        lockOnExit: decoded['lockOnExit'] as bool? ?? false,
        lockTimeout: LockTimeout.values.firstWhere(
          (v) => v.name == decoded['lockTimeout'],
          orElse: () => LockTimeout.oneMinute,
        ),
      );
    } on FormatException {
      // JSON inválido: se trata como si no hubiera nada guardado (igual que `normalizeSettings`
      // en la web, de forma tolerante).
      return const LockSettings();
    } on TypeError {
      // JSON válido pero con algún campo de otro tipo (p. ej. guardado por una versión anterior
      // con otra forma): mismo criterio, se trata como si no hubiera nada.
      return const LockSettings();
    }
  }

  Future<void> writeLockSettings(String userId, LockSettings settings) =>
      _store.write(
        _lockPrefsKey(userId),
        jsonEncode({
          'biometricLock': settings.biometricLock,
          'lockOnExit': settings.lockOnExit,
          'lockTimeout': settings.lockTimeout.name,
        }),
      );

  /// Borra también las preferencias de bloqueo de `userId` (borrar la cuenta del dispositivo, no
  /// un simple cierre de sesión).
  Future<void> forgetAccount(String userId) async {
    await clearSession();
    await _store.delete(_lockPrefsKey(userId));
  }
}
