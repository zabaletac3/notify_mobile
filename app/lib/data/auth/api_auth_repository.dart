import 'dart:convert';

import 'package:axonote_api/axonote_api.dart' as api;
import 'package:axonote_domain/axonote_domain.dart';

import '../secure/account_secure_store.dart';
import 'session_events.dart';

/// Implementación de [AuthRepository] sobre `axonote_api` (plan §4.2: nadie fuera de
/// `app/lib/data` importa `dio`).
///
/// Además de llamar al servidor, guarda la sesión en el almacén seguro (identidad, tokens y
/// `KeyBundle`) para el arranque en frío y el desbloqueo sin red. Publica los errores de sesión en
/// el canal único ([SessionEventBus]).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    required api.HttpClient http,
    required this._account,
    required this._events,
    String? deviceName,
  }) : _auth = api.AuthApi(http, deviceName: deviceName),
       _keys = api.KeysApi(http),
       _accountApi = api.AccountApi(http),
       _mfaApi = api.MfaApi(http);

  final AccountSecureStore _account;
  final SessionEventBus _events;
  final api.AuthApi _auth;
  final api.KeysApi _keys;
  final api.AccountApi _accountApi;
  final api.MfaApi _mfaApi;

  @override
  Future<KdfParams> prelogin(String email) => _guard(() async {
    final dto = await _auth.prelogin(email);
    return _kdf(dto);
  });

  @override
  Future<RegisterResult> register(RegisterRequest input) => _guard(() async {
    final dto = await _auth.register(
      api.RegisterRequestDto(
        userId: input.userId,
        fullName: input.fullName,
        email: input.email,
        acceptedTerms: input.acceptedTerms,
        authKey: input.authKey,
        recoveryAuth: input.recoveryAuth,
        keys: _keysDto(input.keys),
      ),
    );
    return RegisterResult(dto.email);
  });

  @override
  Future<User> verifyEmail({
    required String email,
    required String code,
    required KeyBundle keys,
  }) => _guard(() async {
    final user = await _auth.verifyEmail(email, code);
    await _persistSession(
      user: user,
      keys: _keysDto(keys),
      expiresAt: await _account.readExpiresAt() ?? '',
    );
    return _user(user);
  });

  @override
  Future<void> resendVerificationCode(String email) =>
      _guard(() => _auth.resendVerificationCode(email));

  @override
  Future<LoginOutcome> login({
    required String email,
    required String authKey,
  }) => _guard(() async {
    final response = await _auth.login(email, authKey);
    switch (response) {
      case api.LoginSession():
        await _persistLogin(response.result);
        return LoginSucceeded(_loginResult(response.result));
      case api.LoginChallenge():
        final c = response.challenge;
        return LoginMfaRequired(
          MfaChallenge(mfaToken: c.mfaToken, expiresAt: c.expiresAt),
        );
    }
  });

  @override
  Future<LoginResult> loginMfa({
    required String mfaToken,
    required String code,
  }) => _guard(() async {
    final result = await _auth.loginMfa(mfaToken, code);
    await _persistLogin(result);
    return _loginResult(result);
  });

  @override
  Future<void> logout() => _guard(() async {
    await _auth.logout();
    await _account.clearSession();
  });

  @override
  Future<User?> currentSession() => _guard(() async {
    final session = await _auth.currentSession();
    return session == null ? null : _user(session.user);
  });

  @override
  Future<KeyBundle> keyBundle() => _guard(() async {
    final cached = await _account.readKeyBundleJson();
    if (cached != null) {
      return _keyBundle(api.KeyBundleDto.fromJson(jsonDecode(cached)));
    }
    final dto = await _keys.keys();
    await _account.updateKeyBundleJson(jsonEncode(dto.toJson()));
    return _keyBundle(dto);
  });

  @override
  Future<void> requestPasswordReset(String email) =>
      _guard(() => _auth.requestPasswordReset(email));

  @override
  Future<User> updateProfile(String fullName) => _guard(() async {
    final dto = await _accountApi.updateProfile(fullName);
    return _user(dto);
  });

  @override
  Future<String> requestEmailChange({
    required String newEmail,
    required String authKey,
  }) => _guard(() => _accountApi.requestEmailChange(newEmail, authKey));

  @override
  Future<User> confirmEmailChange({
    required String email,
    required String code,
  }) => _guard(() async {
    final dto = await _accountApi.confirmEmailChange(email, code);
    // El correo guardado cambia con la cuenta.
    final userId = await _account.readUserId();
    if (userId != null) {
      await _account.saveSession(
        SessionData(
          userId: userId,
          email: dto.email,
          accessToken: await _account.readAccessToken() ?? '',
          refreshToken: await _account.readRefreshToken() ?? '',
          keyBundleJson: await _account.readKeyBundleJson() ?? '',
          expiresAt: await _account.readExpiresAt() ?? '',
        ),
      );
    }
    return _user(dto);
  });

  @override
  Future<void> changePassword({
    required String currentAuthKey,
    required String newAuthKey,
    required KeyBundle keys,
  }) => _guard(() async {
    final dto = _keysDto(keys);
    await _accountApi.changePassword(
      api.PasswordChangeRequestDto(
        currentAuthKey: currentAuthKey,
        newAuthKey: newAuthKey,
        keys: dto,
      ),
    );
    await _account.updateKeyBundleJson(jsonEncode(dto.toJson()));
  });

  @override
  Future<void> deleteAccount(String authKey) =>
      _guard(() => _accountApi.deleteAccount(authKey));

  @override
  Future<MfaStatus> mfaStatus() => _guard(() async {
    final dto = await _mfaApi.status();
    return MfaStatus(
      enabled: dto.enabled,
      enabledAt: dto.enabledAt,
      recoveryCodesLeft: dto.recoveryCodesLeft,
    );
  });

  @override
  Future<MfaSetup> mfaSetup(String authKey) => _guard(() async {
    final dto = await _mfaApi.setup(authKey);
    return MfaSetup(secret: dto.secret, otpauthUri: dto.otpauthUri);
  });

  @override
  Future<List<String>> mfaEnable(String code) => _guard(() async {
    final dto = await _mfaApi.enable(code);
    return dto.recoveryCodes;
  });

  @override
  Future<void> mfaDisable({required String authKey, required String code}) =>
      _guard(() => _mfaApi.disable(authKey, code));

  @override
  Future<List<String>> mfaRegenerateCodes({
    required String authKey,
    required String code,
  }) => _guard(() async {
    final dto = await _mfaApi.regenerateCodes(authKey, code);
    return dto.recoveryCodes;
  });

  @override
  Future<void> rotateRecoveryKey({
    required String authKey,
    required String recoveryAuth,
    required String recoveryWrappedMasterKey,
  }) => _guard(
    () => _keys.rotateRecoveryKey(
      api.RecoveryKeyRotationDto(
        authKey: authKey,
        recoveryAuth: recoveryAuth,
        recoveryWrappedMasterKey: recoveryWrappedMasterKey,
      ),
    ),
  );

  Future<void> _persistLogin(api.LoginResultDto result) => _persistSession(
    user: result.user,
    keys: result.keys,
    expiresAt: result.expiresAt.toUtc().toIso8601String(),
  );

  Future<void> _persistSession({
    required api.UserDto user,
    required api.KeyBundleDto keys,
    required String expiresAt,
  }) async {
    await _account.saveSession(
      SessionData(
        userId: user.id,
        email: user.email,
        accessToken: await _account.readAccessToken() ?? '',
        refreshToken: await _account.readRefreshToken() ?? '',
        keyBundleJson: jsonEncode(keys.toJson()),
        expiresAt: expiresAt,
      ),
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure catch (e) {
      if (e.error is DeviceRevokedError) {
        await _account.clearSession();
      }
      _events.emitForError(e.error);
      rethrow;
    }
  }

  static User _user(api.UserDto dto) => User(
    id: dto.id,
    email: dto.email,
    fullName: dto.fullName,
    emailVerified: dto.emailVerified,
    hasGoogle: dto.hasGoogle,
    createdAt: dto.createdAt,
  );

  static LoginResult _loginResult(api.LoginResultDto dto) => LoginResult(
    user: _user(dto.user),
    expiresAt: dto.expiresAt,
    keys: _keyBundle(dto.keys),
  );

  static KdfParams _kdf(api.KdfParamsDto dto) => KdfParams(
    alg: dto.alg,
    memoryKiB: dto.memoryKiB,
    iterations: dto.iterations,
    parallelism: dto.parallelism,
    salt: dto.salt,
  );

  static KeyBundle _keyBundle(api.KeyBundleDto dto) => KeyBundle(
    kdf: _kdf(dto.kdf),
    wrappedMasterKey: dto.wrappedMasterKey,
    recoveryWrappedMasterKey: dto.recoveryWrappedMasterKey,
    keysVersion: dto.keysVersion,
  );

  static api.KeyBundleDto _keysDto(KeyBundle keys) => api.KeyBundleDto(
    kdf: api.KdfParamsDto(
      alg: keys.kdf.alg,
      memoryKiB: keys.kdf.memoryKiB,
      iterations: keys.kdf.iterations,
      parallelism: keys.kdf.parallelism,
      salt: keys.kdf.salt,
    ),
    wrappedMasterKey: keys.wrappedMasterKey,
    recoveryWrappedMasterKey: keys.recoveryWrappedMasterKey,
    keysVersion: keys.keysVersion,
  );
}
