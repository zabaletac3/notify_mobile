import 'package:axonote_domain/axonote_domain.dart';

import '../http_client.dart';
import '../json.dart';
import '../models/auth.dart';
import '../models/common.dart';
import '../models/mfa.dart';
import '../routes.dart';

/// Cliente de las rutas de cuenta y sesión (`/auth/*`) y de las claves de la cuenta.
class AuthApi {
  const AuthApi(
    this._http, {
    this.deviceName,
    this.platform = DevicePlatform.android,
  });

  final HttpClient _http;

  /// Nombre del dispositivo para la lista de dispositivos. Si es `null`, no se envía.
  final String? deviceName;
  final DevicePlatform platform;

  DeviceInfoDto? get _device => deviceName == null
      ? null
      : DeviceInfoDto(name: deviceName!, platform: platform);

  /// Parámetros de derivación de la contraseña de una cuenta (ruta pública).
  Future<KdfParamsDto> prelogin(String email) {
    return _http.request<KdfParamsDto>(
      ApiRoutes.prelogin.method,
      ApiRoutes.prelogin.pathTemplate,
      auth: AuthMode.none,
      body: <String, Object?>{'email': email},
      decode: (json) => PreloginResultDto.fromJson(json).kdf,
    );
  }

  /// Crea la cuenta (sin verificar) y envía el código al correo.
  Future<RegisterResultDto> register(RegisterRequestDto input) {
    return _http.request<RegisterResultDto>(
      ApiRoutes.register.method,
      ApiRoutes.register.pathTemplate,
      auth: AuthMode.none,
      body: input.toJson(),
      decode: RegisterResultDto.fromJson,
    );
  }

  /// Verifica el correo con el código de 6 dígitos e inicia sesión.
  Future<UserDto> verifyEmail(String email, String code) async {
    final session = await _http.request<SessionDto>(
      ApiRoutes.verifyEmail.method,
      ApiRoutes.verifyEmail.pathTemplate,
      auth: AuthMode.none,
      body: <String, Object?>{'email': email, 'code': code},
      decode: SessionDto.fromJson,
    );
    await _http.saveTokens(
      expiresAt: session.expiresAt,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    return session.user;
  }

  /// Reenvía el código de verificación (máx. 1 cada 60 s).
  Future<void> resendVerificationCode(String email) {
    return _http.request<void>(
      ApiRoutes.resendCode.method,
      ApiRoutes.resendCode.pathTemplate,
      auth: AuthMode.none,
      body: <String, Object?>{'email': email},
      decode: (_) {},
    );
  }

  /// Inicia sesión con la prueba de la contraseña (`authKey`). Devuelve la sesión o un reto de
  /// segundo paso.
  Future<LoginResponse> login(String email, String authKey) async {
    final response = await _http.request<LoginResponse>(
      ApiRoutes.login.method,
      ApiRoutes.login.pathTemplate,
      auth: AuthMode.none,
      body: LoginInputDto(
        email: email,
        authKey: authKey,
        device: _device,
      ).toJson(),
      decode: _decodeLogin,
    );
    if (response is LoginSession) {
      await _saveLogin(response.result);
    }
    return response;
  }

  /// Segundo paso del login (código TOTP o de respaldo).
  Future<LoginResultDto> loginMfa(String mfaToken, String code) async {
    final result = await _http.request<LoginResultDto>(
      ApiRoutes.loginMfa.method,
      ApiRoutes.loginMfa.pathTemplate,
      auth: AuthMode.none,
      body: <String, Object?>{'mfaToken': mfaToken, 'code': code},
      decode: LoginResultDto.fromJson,
    );
    await _saveLogin(result);
    return result;
  }

  /// Cierra la sesión de este dispositivo. Siempre limpia los tokens locales, aunque falle la red.
  Future<void> logout() async {
    try {
      if (await _http.hasSession) {
        await _http.request<void>(
          ApiRoutes.logout.method,
          ApiRoutes.logout.pathTemplate,
          decode: (_) {},
        );
      }
    } on AppFailure {
      // Sin red o sesión ya vencida: se cierra igualmente aquí.
    } finally {
      await _http.clearSession();
    }
  }

  /// Sesión vigente, o `null` si no hay sesión.
  Future<SessionDto?> currentSession() async {
    if (!await _http.hasSession) return null;
    return _http.request<SessionDto>(
      ApiRoutes.session.method,
      ApiRoutes.session.pathTemplate,
      decode: SessionDto.fromJson,
    );
  }

  /// Pide el enlace de recuperación. Siempre resuelve, exista o no la cuenta.
  Future<void> requestPasswordReset(String email) {
    return _http.request<void>(
      ApiRoutes.passwordForgot.method,
      ApiRoutes.passwordForgot.pathTemplate,
      auth: AuthMode.none,
      body: <String, Object?>{'email': email},
      decode: (_) {},
    );
  }

  /// Con el token del correo, lo necesario para restablecer conservando las notas.
  Future<PasswordResetBundleDto> passwordResetBundle(String token) {
    return _http.request<PasswordResetBundleDto>(
      ApiRoutes.passwordResetBundle.method,
      ApiRoutes.passwordResetBundle.pathTemplate,
      auth: AuthMode.none,
      body: <String, Object?>{'token': token},
      decode: PasswordResetBundleDto.fromJson,
    );
  }

  /// Crea una contraseña nueva con el token del enlace y cierra la sesión local.
  Future<void> resetPassword(PasswordResetRequestDto input) async {
    await _http.request<void>(
      ApiRoutes.passwordReset.method,
      ApiRoutes.passwordReset.pathTemplate,
      auth: AuthMode.none,
      body: input.toJson(),
      decode: (_) {},
    );
    await _http.clearSession();
  }

  Future<void> _saveLogin(LoginResultDto result) {
    return _http.saveTokens(
      expiresAt: result.expiresAt,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
  }

  static LoginResponse _decodeLogin(Object? json) {
    final reader = JsonReader(json);
    final mfaRequired = reader.optional('mfaRequired');
    if (mfaRequired != null && mfaRequired.asBool()) {
      return LoginChallenge(MfaChallengeDto.fromJson(json));
    }
    return LoginSession(LoginResultDto.fromJson(json));
  }
}

/// Cliente de la verificación en dos pasos (`/mfa`).
class MfaApi {
  const MfaApi(this._http);

  final HttpClient _http;

  /// Estado de la verificación en dos pasos.
  Future<MfaStatusDto> status() {
    return _http.request<MfaStatusDto>(
      ApiRoutes.mfa.method,
      ApiRoutes.mfa.pathTemplate,
      decode: MfaStatusDto.fromJson,
    );
  }

  /// Genera (o sustituye) un secreto TOTP pendiente. Exige la prueba de la contraseña.
  Future<MfaSetupResultDto> setup(String authKey) {
    return _http.request<MfaSetupResultDto>(
      ApiRoutes.mfaSetup.method,
      ApiRoutes.mfaSetup.pathTemplate,
      body: <String, Object?>{'authKey': authKey},
      decode: MfaSetupResultDto.fromJson,
    );
  }

  /// Confirma el código TOTP y activa la verificación; devuelve los códigos de respaldo.
  Future<MfaRecoveryCodesDto> enable(String code) {
    return _http.request<MfaRecoveryCodesDto>(
      ApiRoutes.mfaEnable.method,
      ApiRoutes.mfaEnable.pathTemplate,
      body: <String, Object?>{'code': code},
      decode: MfaRecoveryCodesDto.fromJson,
    );
  }

  /// Desactiva la verificación en dos pasos (contraseña + código).
  Future<void> disable(String authKey, String code) {
    return _http.request<void>(
      ApiRoutes.mfaDisable.method,
      ApiRoutes.mfaDisable.pathTemplate,
      body: <String, Object?>{'authKey': authKey, 'code': code},
      decode: (_) {},
    );
  }

  /// Regenera los 10 códigos de respaldo (contraseña + código).
  Future<MfaRecoveryCodesDto> regenerateCodes(String authKey, String code) {
    return _http.request<MfaRecoveryCodesDto>(
      ApiRoutes.mfaRecoveryCodes.method,
      ApiRoutes.mfaRecoveryCodes.pathTemplate,
      body: <String, Object?>{'authKey': authKey, 'code': code},
      decode: MfaRecoveryCodesDto.fromJson,
    );
  }
}
