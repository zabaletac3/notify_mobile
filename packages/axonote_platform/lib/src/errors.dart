/// Errores tipados del canal nativo (ver plan §5.2). Nunca llevan el mensaje nativo crudo ni
/// ningún material secreto: solo lo que la interfaz necesita para decidir qué mostrar.
sealed class AxonotePlatformError implements Exception {
  const AxonotePlatformError();
}

/// La persona canceló el cuadro de biometría o credencial (botón atrás, toque fuera, "cancelar").
final class AuthCancelled extends AxonotePlatformError {
  const AuthCancelled();

  @override
  String toString() => 'AuthCancelled';
}

/// El dispositivo no tiene biometría ni credencial (PIN/patrón/contraseña) configurada. La app
/// debe guardar la clave maestra con `requireAuth: false` o pedir la contraseña.
final class AuthNotEnrolled extends AxonotePlatformError {
  const AuthNotEnrolled();

  @override
  String toString() => 'AuthNotEnrolled';
}

/// La clave de Keystore quedó invalidada (se registró una huella u otra biometría nueva desde que
/// se guardó). Ya no se puede recuperar la clave maestra guardada: hay que borrarla y pedir la
/// contraseña de nuevo.
final class KeyInvalidated extends AxonotePlatformError {
  const KeyInvalidated();

  @override
  String toString() => 'KeyInvalidated';
}

/// Demasiados intentos fallidos: el sensor biométrico está bloqueado un tiempo (o permanentemente
/// hasta que se desbloquee el dispositivo con la credencial).
final class AuthLockedOut extends AxonotePlatformError {
  const AuthLockedOut({required this.permanent});

  /// `true` si el bloqueo exige la credencial del dispositivo para levantarse (no basta esperar).
  final bool permanent;

  @override
  String toString() => 'AuthLockedOut(permanent: $permanent)';
}

/// No había ninguna clave guardada para esa cuenta (`loadMasterKey` sin `storeMasterKey` previo, o
/// tras `deleteMasterKey`).
final class NoStoredKey extends AxonotePlatformError {
  const NoStoredKey();

  @override
  String toString() => 'NoStoredKey';
}

/// Fallo nativo no clasificado (hardware, Keystore, etc.). `message` es una descripción técnica
/// fija, sin datos de la persona ni material secreto: solo para diagnóstico.
final class AxonotePlatformFailure extends AxonotePlatformError {
  const AxonotePlatformFailure(this.message);

  final String message;

  @override
  String toString() => 'AxonotePlatformFailure: $message';
}
