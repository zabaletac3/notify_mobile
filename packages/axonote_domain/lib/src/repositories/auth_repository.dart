import '../auth.dart';

/// Acceso a las operaciones de cuenta y sesión (`/auth/*`, `/keys`). Lo implementa `app/lib/data`
/// (HTTP); el estado solo conoce esta interfaz (plan §4.2). Los métodos lanzan `AppFailure`.
///
/// **La contraseña nunca cruza esta interfaz.** El estado deriva `authKey`/`kek` con
/// `axonote_crypto` y aquí solo viaja la prueba ya derivada.
abstract interface class AuthRepository {
  /// Parámetros de Argon2id de una cuenta (ruta pública).
  Future<KdfParams> prelogin(String email);

  /// Crea la cuenta (sin verificar) y envía el código al correo.
  Future<RegisterResult> register(RegisterRequest input);

  /// Verifica el correo con el código y deja la sesión iniciada. [keys] son las claves de la cuenta
  /// recién creada (ya en memoria tras el registro), que se guardan para el desbloqueo sin red.
  Future<User> verifyEmail({
    required String email,
    required String code,
    required KeyBundle keys,
  });

  /// Reenvía el código de verificación (máx. 1 cada 60 s).
  Future<void> resendVerificationCode(String email);

  /// Inicia sesión con la prueba derivada de la contraseña. Devuelve la sesión o un reto de segundo
  /// paso.
  Future<LoginOutcome> login({required String email, required String authKey});

  /// Completa el segundo paso (código TOTP o de respaldo) y deja la sesión iniciada.
  Future<LoginResult> loginMfa({
    required String mfaToken,
    required String code,
  });

  /// Cierra la sesión en el servidor y borra los tokens locales (mejor esfuerzo sin red).
  Future<void> logout();

  /// Sesión vigente según el servidor. `null` si ya no hay sesión; lanza `network` si no hay red.
  Future<User?> currentSession();

  /// Claves de la cuenta para desbloquear sin red. Usa la copia guardada si la hay; si no, las pide
  /// al servidor y las guarda.
  Future<KeyBundle> keyBundle();

  /// Pide el enlace de restablecimiento. Siempre resuelve, exista o no la cuenta.
  Future<void> requestPasswordReset(String email);
}
