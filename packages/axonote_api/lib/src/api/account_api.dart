import '../http_client.dart';
import '../json.dart';
import '../models/auth.dart';
import '../models/misc.dart';
import '../routes.dart';

/// Cliente del perfil y las credenciales de la cuenta (`/me`).
class AccountApi {
  const AccountApi(this._http);

  final HttpClient _http;

  /// Perfil de la cuenta actual.
  Future<UserDto> me() {
    return _http.request<UserDto>(
      ApiRoutes.me.method,
      ApiRoutes.me.pathTemplate,
      decode: UserDto.fromJson,
    );
  }

  /// Cambia el nombre visible.
  Future<UserDto> updateProfile(String fullName) {
    return _http.request<UserDto>(
      ApiRoutes.updateProfile.method,
      ApiRoutes.updateProfile.pathTemplate,
      body: <String, Object?>{'fullName': fullName},
      decode: UserDto.fromJson,
    );
  }

  /// Pide cambiar el correo: exige la prueba de la contraseña y envía un código al correo nuevo.
  Future<String> requestEmailChange(String newEmail, String authKey) {
    return _http.request<String>(
      ApiRoutes.emailChange.method,
      ApiRoutes.emailChange.pathTemplate,
      body: <String, Object?>{'newEmail': newEmail, 'authKey': authKey},
      decode: (json) => JsonReader(json).child('email').asString(),
    );
  }

  /// Confirma el correo nuevo con el código.
  Future<UserDto> confirmEmailChange(String email, String code) {
    return _http.request<UserDto>(
      ApiRoutes.emailChangeConfirm.method,
      ApiRoutes.emailChangeConfirm.pathTemplate,
      body: <String, Object?>{'email': email, 'code': code},
      decode: UserDto.fromJson,
    );
  }

  /// Cambia la contraseña (exige la prueba de la actual).
  Future<void> changePassword(PasswordChangeRequestDto input) {
    return _http.request<void>(
      ApiRoutes.password.method,
      ApiRoutes.password.pathTemplate,
      body: input.toJson(),
      decode: (_) {},
    );
  }

  /// Elimina la cuenta y limpia la sesión local.
  Future<void> deleteAccount(String authKey) async {
    await _http.request<void>(
      ApiRoutes.deleteAccount.method,
      ApiRoutes.deleteAccount.pathTemplate,
      body: <String, Object?>{'authKey': authKey},
      decode: (_) {},
    );
    await _http.clearSession();
  }
}

/// Cliente de las claves cifradas de la cuenta (`/keys`).
class KeysApi {
  const KeysApi(this._http);

  final HttpClient _http;

  /// Claves cifradas de la cuenta con sesión vigente.
  Future<KeyBundleDto> keys() {
    return _http.request<KeyBundleDto>(
      ApiRoutes.keys.method,
      ApiRoutes.keys.pathTemplate,
      decode: KeyBundleDto.fromJson,
    );
  }

  /// Cambia la clave de recuperación (la anterior deja de servir).
  Future<void> rotateRecoveryKey(RecoveryKeyRotationDto input) {
    return _http.request<void>(
      ApiRoutes.recoveryKey.method,
      ApiRoutes.recoveryKey.pathTemplate,
      body: input.toJson(),
      decode: (_) {},
    );
  }
}

/// Cliente de los dispositivos y sesiones activas (`/devices`).
class DeviceApi {
  const DeviceApi(this._http);

  final HttpClient _http;

  /// Dispositivos con sesión activa.
  Future<List<DeviceDto>> list() {
    return _http.request<List<DeviceDto>>(
      ApiRoutes.devices.method,
      ApiRoutes.devices.pathTemplate,
      decode: (json) => [
        for (final item in JsonReader(json).asList())
          DeviceDto.fromJson(item.asMap()),
      ],
    );
  }

  /// Cierra la sesión de otro dispositivo.
  Future<void> remove(String deviceId) {
    return _http.request<void>(
      ApiRoutes.device.method,
      ApiRoutes.device.resolve({'deviceId': Uri.encodeComponent(deviceId)}),
      decode: (_) {},
    );
  }
}

/// Cliente de las preferencias (`/settings`).
class SettingsApi {
  const SettingsApi(this._http);

  final HttpClient _http;

  /// Preferencias de la cuenta.
  Future<AppSettingsDto> get() {
    return _http.request<AppSettingsDto>(
      ApiRoutes.settings.method,
      ApiRoutes.settings.pathTemplate,
      decode: AppSettingsDto.fromJson,
    );
  }

  /// Cambia preferencias. `twoFactor` es de solo lectura: el servidor lo rechaza.
  Future<AppSettingsDto> update(AppSettingsPatchDto patch) {
    return _http.request<AppSettingsDto>(
      ApiRoutes.updateSettings.method,
      ApiRoutes.updateSettings.pathTemplate,
      body: patch.toJson(),
      decode: AppSettingsDto.fromJson,
    );
  }
}

/// Cliente del uso de espacio (`/storage/usage`).
class StorageApi {
  const StorageApi(this._http);

  final HttpClient _http;

  /// Espacio usado frente a la cuota.
  Future<StorageUsageDto> usage() {
    return _http.request<StorageUsageDto>(
      ApiRoutes.storageUsage.method,
      ApiRoutes.storageUsage.pathTemplate,
      decode: StorageUsageDto.fromJson,
    );
  }
}
