import 'dart:typed_data';

import 'axonote_platform.dart';
import 'errors.dart';
import 'types.dart';

class _StoredKey {
  _StoredKey(this.bytes, this.requireAuth, this.enrollmentEpoch);

  Uint8List bytes;
  bool requireAuth;

  /// Generación de biometría vigente cuando se guardó esta clave. Si ya no coincide con la
  /// generación actual de [FakeAxonotePlatform], la clave quedó invalidada (huella nueva).
  int enrollmentEpoch;
}

/// Implementación en memoria de [AxonotePlatform] para pruebas unitarias (Vault, gestor de
/// bloqueo): no toca ningún canal nativo. Simula el comportamiento del Keystore real que describe
/// el plan §5.2, incluida la invalidación al "registrar una huella nueva" (`invalidateByEnrollment`)
/// y los modos de fallo que se pueden forzar con `nextAuthResult`.
class FakeAxonotePlatform extends AxonotePlatform {
  final Map<String, _StoredKey> _store = {};

  /// Generación de biometría actual del dispositivo simulado. `invalidateByEnrollment` la avanza.
  int _enrollmentEpoch = 0;

  AuthAvailability authAvailabilityValue = const AuthAvailability(
    biometricStrong: true,
    deviceCredential: true,
    enrolled: true,
  );

  /// Próximo resultado de cualquier operación que requiera autenticación (`storeMasterKey` con
  /// `requireAuth: true`, o `loadMasterKey` sobre una clave guardada con `requireAuth: true`). Por
  /// defecto `null`: autentica con éxito. Se consume una sola vez.
  AxonotePlatformError? nextAuthResult;

  bool secure = false;

  /// Simula que la persona registró una biometría nueva: invalida cualquier clave guardada con
  /// `requireAuth: true` (plan §5.2: "si la clave quedó invalidada (huella nueva) ... se borra y
  /// se pide la contraseña").
  void invalidateByEnrollment() => _enrollmentEpoch++;

  @override
  Future<void> storeMasterKey({
    required String userId,
    required Uint8List bytes,
    required bool requireAuth,
    String? prompt,
  }) async {
    if (requireAuth) {
      final forced = nextAuthResult;
      nextAuthResult = null;
      if (forced != null) throw forced;
      if (!authAvailabilityValue.enrolled) {
        throw const AuthNotEnrolled();
      }
    }
    _store[userId] = _StoredKey(
      Uint8List.fromList(bytes),
      requireAuth,
      _enrollmentEpoch,
    );
  }

  @override
  Future<Uint8List> loadMasterKey({
    required String userId,
    required String prompt,
  }) async {
    final stored = _store[userId];
    if (stored == null) throw const NoStoredKey();
    if (stored.requireAuth) {
      if (stored.enrollmentEpoch != _enrollmentEpoch) {
        _store.remove(userId);
        throw const KeyInvalidated();
      }
      final forced = nextAuthResult;
      nextAuthResult = null;
      if (forced != null) throw forced;
      if (!authAvailabilityValue.enrolled) {
        throw const AuthNotEnrolled();
      }
    }
    return Uint8List.fromList(stored.bytes);
  }

  @override
  Future<void> deleteMasterKey({required String userId}) async {
    _store.remove(userId);
  }

  @override
  Future<AuthAvailability> authAvailability() async => authAvailabilityValue;

  @override
  Future<void> setSecure(bool value) async {
    secure = value;
  }

  /// Último texto copiado con [copySensitive], para comprobar en pruebas qué se marcó como
  /// sensible. Nunca se expone así en la implementación real.
  String? lastCopiedSensitive;

  @override
  Future<void> copySensitive(String text) async {
    lastCopiedSensitive = text;
  }
}
