import 'dart:typed_data';

import 'axonote_platform.dart';
import 'errors.dart';
import 'types.dart';

class _StoredKey {
  _StoredKey(this.bytes, this.requireAuth, this.invalidationEpoch);

  Uint8List bytes;
  bool requireAuth;

  /// Generación de validez vigente cuando se guardó esta clave. Si ya no coincide con la
  /// generación actual de [FakeAxonotePlatform], la clave quedó invalidada.
  int invalidationEpoch;
}

/// Implementación en memoria de [AxonotePlatform] para pruebas unitarias (Vault, gestor de
/// bloqueo): no toca ningún canal nativo. Simula el comportamiento del Keystore real que describe
/// el plan §5.2, incluida la invalidación de una clave guardada (`invalidateStoredKey`) y los
/// modos de fallo que se pueden forzar con `nextAuthResult`.
///
/// `invalidateStoredKey` simula un camino real de invalidación (p. ej. quitar el bloqueo de
/// pantalla seguro del dispositivo), no "registrar una huella nueva": con `requireAuth`, la clave
/// real pide biometría o credencial del dispositivo a la vez (API ≥ 30) y una huella nueva ya NO
/// la invalida (decisión de 2026-10-11, ver `docs/decisions.md` en el repo de la app). El único
/// caso donde una huella nueva sí invalida sigue siendo API 26-29 con clave puramente biométrica,
/// que este fake no modela por separado.
class FakeAxonotePlatform extends AxonotePlatform {
  final Map<String, _StoredKey> _store = {};

  /// Generación de validez actual del dispositivo simulado. `invalidateStoredKey` la avanza.
  int _invalidationEpoch = 0;

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

  /// Cuántas veces se llamó a [storeMasterKey] desde que se creó (o desde el último reinicio a
  /// mano). Para pruebas que necesitan comprobar que algo NO vuelve a guardar innecesariamente,
  /// sin que comprobarlo consuma [nextAuthResult] (a diferencia de mirar si sigue guardado con
  /// [loadMasterKey]).
  int storeMasterKeyCallCount = 0;

  /// Simula un camino real de invalidación de la clave guardada (p. ej. quitar el bloqueo de
  /// pantalla seguro del dispositivo; ver `MasterKeyInvalidatedException` en `MasterKeyStore.kt`):
  /// invalida cualquier clave guardada con `requireAuth: true` (plan §5.2: "si la clave quedó
  /// invalidada ... se borra y se pide la contraseña"). No simula "registrar una huella nueva":
  /// con la clave combinada que usa esta app (biometría o credencial, API ≥ 30) eso ya no invalida
  /// nada (decisión de 2026-10-11, `docs/decisions.md`).
  void invalidateStoredKey() => _invalidationEpoch++;

  @override
  Future<void> storeMasterKey({
    required String userId,
    required Uint8List bytes,
    required bool requireAuth,
    String? prompt,
  }) async {
    storeMasterKeyCallCount++;
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
      _invalidationEpoch,
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
      if (stored.invalidationEpoch != _invalidationEpoch) {
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
