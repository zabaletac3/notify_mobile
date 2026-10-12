import 'package:flutter/services.dart';

import 'axonote_platform.dart';
import 'errors.dart';
import 'types.dart';

/// Implementación real sobre un [MethodChannel] hacia `AxonotePlatformPlugin.kt`. Traduce los
/// códigos de [PlatformException] del lado Kotlin a los errores tipados de `errors.dart`; nunca
/// deja pasar el mensaje nativo tal cual (podría describir el fallo con detalle de implementación,
/// pero no lleva material secreto: aun así no se expone a la interfaz).
class MethodChannelAxonotePlatform extends AxonotePlatform {
  MethodChannelAxonotePlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('axonote_platform');

  final MethodChannel _channel;

  @override
  Future<void> storeMasterKey({
    required String userId,
    required Uint8List bytes,
    required bool requireAuth,
    String? prompt,
  }) async {
    try {
      await _channel.invokeMethod<void>('storeMasterKey', {
        'userId': userId,
        'bytes': bytes,
        'requireAuth': requireAuth,
        'prompt': prompt,
      });
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<Uint8List> loadMasterKey({
    required String userId,
    required String prompt,
  }) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>('loadMasterKey', {
        'userId': userId,
        'prompt': prompt,
      });
      if (result == null) {
        throw const AxonotePlatformFailure('loadMasterKey sin resultado');
      }
      return result;
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> deleteMasterKey({required String userId}) async {
    try {
      await _channel.invokeMethod<void>('deleteMasterKey', {'userId': userId});
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<bool> hasStoredMasterKey({
    required String userId,
    required bool requireAuth,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('hasStoredMasterKey', {
        'userId': userId,
        'requireAuth': requireAuth,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<AuthAvailability> authAvailability() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'authAvailability',
      );
      if (result == null) {
        throw const AxonotePlatformFailure('authAvailability sin resultado');
      }
      return AuthAvailability(
        biometricStrong: result['biometricStrong'] == true,
        deviceCredential: result['deviceCredential'] == true,
        enrolled: result['enrolled'] == true,
      );
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<void> copySensitive(String text) async {
    try {
      await _channel.invokeMethod<void>('copySensitive', {'text': text});
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<String> deviceModel() async {
    try {
      final result = await _channel.invokeMethod<String>('deviceModel');
      return (result == null || result.isEmpty) ? 'Android' : result;
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  /// Códigos que envía `AxonotePlatformPlugin.kt` (ver su doc). Cualquier código desconocido se
  /// trata como [AxonotePlatformFailure] con un mensaje fijo, nunca con el texto nativo completo.
  AxonotePlatformError _mapError(PlatformException e) {
    switch (e.code) {
      case 'auth_cancelled':
        return const AuthCancelled();
      case 'auth_not_enrolled':
        return const AuthNotEnrolled();
      case 'key_invalidated':
        return const KeyInvalidated();
      case 'auth_locked_out':
        return const AuthLockedOut(permanent: false);
      case 'auth_locked_out_permanent':
        return const AuthLockedOut(permanent: true);
      case 'no_stored_key':
        return const NoStoredKey();
      default:
        return AxonotePlatformFailure(e.code);
    }
  }
}
