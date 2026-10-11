/// Qué puede usar el dispositivo para autenticar el acceso a la clave maestra (resultado de
/// `authAvailability()`, plan §5.2). No dice si una cuenta concreta ya activó biometría: eso lo
/// decide el ajuste `biometricLock` (§5.3), guardado aparte.
final class AuthAvailability {
  const AuthAvailability({
    required this.biometricStrong,
    required this.deviceCredential,
    required this.enrolled,
  });

  /// El hardware admite biometría de clase fuerte (huella, cara con clase 3) y la API lo permite.
  final bool biometricStrong;

  /// API ≥ 30: el dispositivo puede usar también el PIN/patrón/contraseña del teléfono para abrir
  /// la clave. En API 26–29 siempre es `false` (plan §5.2: "API 26–29: solo BIOMETRIC_STRONG").
  final bool deviceCredential;

  /// Hay al menos un autenticador (de los dos de arriba) realmente registrado ahora mismo. Si es
  /// `false`, aunque el hardware exista, no se puede pedir `requireAuth: true`: hay que guardar la
  /// clave con `requireAuth: false` o seguir pidiendo la contraseña.
  final bool enrolled;

  /// Ningún autenticador disponible: ni biometría ni credencial de dispositivo, o ninguno
  /// registrado.
  bool get none => !enrolled;

  @override
  String toString() =>
      'AuthAvailability(biometricStrong: $biometricStrong, '
      'deviceCredential: $deviceCredential, enrolled: $enrolled)';
}
