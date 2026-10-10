import '../json.dart';
import 'common.dart';

/// Parámetros de derivación de la contraseña (Argon2id), tal como los guarda el servidor.
class KdfParamsDto {
  const KdfParamsDto({
    required this.alg,
    required this.memoryKiB,
    required this.iterations,
    required this.parallelism,
    required this.salt,
  });

  factory KdfParamsDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return KdfParamsDto(
      alg: r.child('alg').asString(),
      memoryKiB: r.child('memoryKiB').asInt(),
      iterations: r.child('iterations').asInt(),
      parallelism: r.child('parallelism').asInt(),
      salt: r.child('salt').asString(),
    );
  }

  final String alg;
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  /// 16 bytes aleatorios en base64url.
  final String salt;

  Map<String, Object?> toJson() => <String, Object?>{
    'alg': alg,
    'memoryKiB': memoryKiB,
    'iterations': iterations,
    'parallelism': parallelism,
    'salt': salt,
  };
}

/// Lo que el servidor guarda de las claves de una cuenta. Sin la contraseña o la clave de
/// recuperación no permite descifrar nada.
class KeyBundleDto {
  const KeyBundleDto({
    required this.kdf,
    required this.wrappedMasterKey,
    required this.recoveryWrappedMasterKey,
    required this.keysVersion,
  });

  factory KeyBundleDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return KeyBundleDto(
      kdf: KdfParamsDto.fromJson(r.child('kdf').asMap()),
      wrappedMasterKey: r.child('wrappedMasterKey').asString(),
      recoveryWrappedMasterKey: r.child('recoveryWrappedMasterKey').asString(),
      keysVersion: r.child('keysVersion').asInt(),
    );
  }

  final KdfParamsDto kdf;

  /// Clave maestra cifrada con la clave derivada de la contraseña.
  final Sealed wrappedMasterKey;

  /// La misma clave maestra, cifrada con la clave de recuperación.
  final Sealed recoveryWrappedMasterKey;

  final int keysVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'kdf': kdf.toJson(),
    'wrappedMasterKey': wrappedMasterKey,
    'recoveryWrappedMasterKey': recoveryWrappedMasterKey,
    'keysVersion': keysVersion,
  };
}

/// Perfil de la cuenta.
class UserDto {
  const UserDto({
    required this.id,
    required this.email,
    required this.fullName,
    required this.emailVerified,
    required this.hasGoogle,
    required this.createdAt,
  });

  factory UserDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return UserDto(
      id: r.child('id').asString(),
      email: r.child('email').asString(),
      fullName: r.child('fullName').asString(),
      emailVerified: r.child('emailVerified').asBool(),
      hasGoogle: r.child('hasGoogle').asBool(),
      createdAt: r.child('createdAt').asDateTime(),
    );
  }

  final String id;
  final String email;
  final String fullName;
  final bool emailVerified;
  final bool hasGoogle;
  final DateTime createdAt;
}

/// Sesión iniciada, sin las claves (que solo trae `LoginResult`).
class SessionDto {
  const SessionDto({
    required this.user,
    required this.expiresAt,
    this.accessToken,
    this.refreshToken,
  });

  factory SessionDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return SessionDto(
      user: UserDto.fromJson(r.child('user').asMap()),
      expiresAt: r.child('expiresAt').asDateTime(),
      accessToken: r.optional('accessToken')?.asString(),
      refreshToken: r.optional('refreshToken')?.asString(),
    );
  }

  final UserDto user;
  final DateTime expiresAt;
  final String? accessToken;
  final String? refreshToken;
}

/// Respuesta de `/auth/login` y `/auth/login/mfa`: la sesión con las claves cifradas de la cuenta.
class LoginResultDto {
  const LoginResultDto({
    required this.user,
    required this.expiresAt,
    required this.keys,
    this.accessToken,
    this.refreshToken,
  });

  factory LoginResultDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return LoginResultDto(
      user: UserDto.fromJson(r.child('user').asMap()),
      expiresAt: r.child('expiresAt').asDateTime(),
      keys: KeyBundleDto.fromJson(r.child('keys').asMap()),
      accessToken: r.optional('accessToken')?.asString(),
      refreshToken: r.optional('refreshToken')?.asString(),
    );
  }

  final UserDto user;
  final DateTime expiresAt;
  final KeyBundleDto keys;
  final String? accessToken;
  final String? refreshToken;
}

/// Reto de segundo paso: el primer factor fue correcto pero falta el código. No es una sesión: no
/// trae `keys` ni tokens.
class MfaChallengeDto {
  const MfaChallengeDto({
    required this.mfaRequired,
    required this.mfaToken,
    required this.expiresAt,
  });

  factory MfaChallengeDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return MfaChallengeDto(
      mfaRequired: r.child('mfaRequired').asBool(),
      mfaToken: r.child('mfaToken').asString(),
      expiresAt: r.child('expiresAt').asDateTime(),
    );
  }

  final bool mfaRequired;
  final String mfaToken;
  final DateTime expiresAt;
}

/// Respuesta de inicio de sesión: sesión completa o reto de segundo paso.
sealed class LoginResponse {
  const LoginResponse();
}

/// El inicio de sesión terminó: hay sesión y claves.
final class LoginSession extends LoginResponse {
  const LoginSession(this.result);

  final LoginResultDto result;
}

/// Falta el segundo factor.
final class LoginChallenge extends LoginResponse {
  const LoginChallenge(this.challenge);

  final MfaChallengeDto challenge;
}

/// `POST /auth/prelogin` responde solo los parámetros de derivación.
class PreloginResultDto {
  const PreloginResultDto(this.kdf);

  factory PreloginResultDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return PreloginResultDto(KdfParamsDto.fromJson(r.child('kdf').asMap()));
  }

  final KdfParamsDto kdf;
}

/// `POST /auth/register` responde el correo con el que se creó la cuenta.
class RegisterResultDto {
  const RegisterResultDto(this.email);

  factory RegisterResultDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return RegisterResultDto(r.child('email').asString());
  }

  final String email;
}

/// `POST /auth/password/reset/bundle`: lo necesario para restablecer conservando las notas.
class PasswordResetBundleDto {
  const PasswordResetBundleDto({
    required this.userId,
    required this.recoveryWrappedMasterKey,
    required this.kdf,
    required this.mfaEnabled,
  });

  factory PasswordResetBundleDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return PasswordResetBundleDto(
      userId: r.child('userId').asString(),
      recoveryWrappedMasterKey: r.child('recoveryWrappedMasterKey').asString(),
      kdf: KdfParamsDto.fromJson(r.child('kdf').asMap()),
      mfaEnabled: r.child('mfaEnabled').asBool(),
    );
  }

  final String userId;
  final Sealed recoveryWrappedMasterKey;
  final KdfParamsDto kdf;
  final bool mfaEnabled;
}

/// Información del dispositivo que inicia sesión (para la lista de dispositivos).
class DeviceInfoDto {
  const DeviceInfoDto({required this.name, required this.platform});

  final String name;
  final DevicePlatform platform;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'platform': platform.wire,
  };
}

/// Cuerpo de `POST /auth/register`.
class RegisterRequestDto {
  const RegisterRequestDto({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.acceptedTerms,
    required this.authKey,
    required this.recoveryAuth,
    required this.keys,
  });

  final String userId;
  final String fullName;
  final String email;
  final bool acceptedTerms;
  final String authKey;
  final String recoveryAuth;
  final KeyBundleDto keys;

  Map<String, Object?> toJson() => <String, Object?>{
    'userId': userId,
    'fullName': fullName,
    'email': email,
    'acceptedTerms': acceptedTerms,
    'authKey': authKey,
    'recoveryAuth': recoveryAuth,
    'keys': keys.toJson(),
  };
}

/// Cuerpo de `POST /auth/login`.
class LoginInputDto {
  const LoginInputDto({
    required this.email,
    required this.authKey,
    this.device,
  });

  final String email;
  final String authKey;
  final DeviceInfoDto? device;

  Map<String, Object?> toJson() => <String, Object?>{
    'email': email,
    'authKey': authKey,
    if (device != null) 'device': device!.toJson(),
  };
}

/// Cuerpo de `POST /me/password`.
class PasswordChangeRequestDto {
  const PasswordChangeRequestDto({
    required this.currentAuthKey,
    required this.newAuthKey,
    required this.keys,
  });

  final String currentAuthKey;
  final String newAuthKey;
  final KeyBundleDto keys;

  Map<String, Object?> toJson() => <String, Object?>{
    'currentAuthKey': currentAuthKey,
    'newAuthKey': newAuthKey,
    'keys': keys.toJson(),
  };
}

/// Cuerpo de `POST /auth/password/reset`.
class PasswordResetRequestDto {
  const PasswordResetRequestDto({
    required this.token,
    required this.mode,
    required this.newAuthKey,
    required this.recoveryAuth,
    required this.keys,
    this.mfaCode,
    this.disableMfa,
  });

  final String token;
  final PasswordResetMode mode;
  final String newAuthKey;
  final String recoveryAuth;
  final KeyBundleDto keys;
  final String? mfaCode;
  final bool? disableMfa;

  Map<String, Object?> toJson() => <String, Object?>{
    'token': token,
    'mode': mode.wire,
    'newAuthKey': newAuthKey,
    'recoveryAuth': recoveryAuth,
    'keys': keys.toJson(),
    if (mfaCode != null) 'mfaCode': mfaCode,
    if (disableMfa != null) 'disableMfa': disableMfa,
  };
}

/// Cuerpo de `PUT /keys/recovery`.
class RecoveryKeyRotationDto {
  const RecoveryKeyRotationDto({
    required this.authKey,
    required this.recoveryAuth,
    required this.recoveryWrappedMasterKey,
  });

  final String authKey;
  final String recoveryAuth;
  final Sealed recoveryWrappedMasterKey;

  Map<String, Object?> toJson() => <String, Object?>{
    'authKey': authKey,
    'recoveryAuth': recoveryAuth,
    'recoveryWrappedMasterKey': recoveryWrappedMasterKey,
  };
}
