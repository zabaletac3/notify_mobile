import 'dart:typed_data';

import 'errors.dart';
import 'method_channel_axonote_platform.dart';
import 'types.dart';

/// Canal de métodos propio de AxoNote (plan §5.2): Android Keystore, biometría y endurecimiento
/// de pantalla. Única puerta de entrada al código nativo (`axonote_platform` es el único paquete
/// del workspace con código Kotlin, ver A8 del plan).
///
/// La app habla siempre con [AxonotePlatform.instance]; las pruebas unitarias lo sustituyen por
/// una implementación falsa (`FakeAxonotePlatform`) sin tocar este `import`.
abstract class AxonotePlatform {
  static AxonotePlatform instance = MethodChannelAxonotePlatform();

  /// Guarda `bytes` (32 B: la clave maestra) cifrados con una clave de Android Keystore propia de
  /// `userId`. Genera la clave de Keystore de nuevo cada vez (sustituye cualquier valor previo de
  /// esa cuenta), por si `requireAuth` cambió. Es atómico: si algo falla a medio camino (se
  /// cancela la biometría, no hay actividad, etc.), lo que hubiera guardado antes para `userId`
  /// queda intacto, nunca a medias.
  ///
  /// El método channel copia `bytes` al cruzar a Kotlin: esa copia nativa se pone a cero en
  /// cuanto termina de cifrarla (con éxito o sin él), pero el `Uint8List` de este lado (el
  /// original, en la VM de Dart) no se ve afectado por eso. Quien llama (normalmente con
  /// `masterKey.bytes` de un `SecretKeyBytes`) sigue siendo responsable de su propio ciclo de
  /// vida igual que siempre: lo borra quien sea dueño de ese `SecretKeyBytes` (el `Vault`, al
  /// bloquear), no esta llamada.
  ///
  /// Con `requireAuth: true` la clave de Keystore exige autenticación (biometría o, en API ≥ 30,
  /// también la credencial del dispositivo) para cada uso — también para este cifrado inicial —
  /// así que puede mostrar un cuadro de autenticación con el texto de `prompt` (ver nota de
  /// `docs/decisions.md`, Fase 5, sobre esta diferencia con la firma literal del plan). Con
  /// `requireAuth: false` cifra sin pedir nada.
  ///
  /// Lanza [AuthCancelled], [AuthNotEnrolled], [AuthLockedOut] o [AxonotePlatformFailure].
  Future<void> storeMasterKey({
    required String userId,
    required Uint8List bytes,
    required bool requireAuth,
    String? prompt,
  });

  /// Recupera la clave maestra guardada para `userId`. Si se guardó con `requireAuth: true`,
  /// muestra el cuadro de autenticación nativo con el texto de `prompt` antes de descifrar. Los
  /// bytes que devuelve, a diferencia de los que recibe [storeMasterKey], **no** se ponen a cero
  /// en el lado Kotlin: tienen que cruzar intactos hasta aquí. Quien llame (el gestor de
  /// bloqueo) los envuelve de inmediato en un `SecretKeyBytes`, que ya sabe borrarse a sí mismo.
  ///
  /// Lanza [NoStoredKey] si no hay nada guardado, [KeyInvalidated] si la clave quedó invalidada
  /// (biometría nueva desde que se guardó, o el texto cifrado ya no corresponde a la clave: en
  /// ambos casos ya se borró en el Keystore), [AuthCancelled], [AuthNotEnrolled],
  /// [AuthLockedOut] o [AxonotePlatformFailure].
  Future<Uint8List> loadMasterKey({required String userId, required String prompt});

  /// Borra la clave de Keystore y lo guardado de `userId`. No lanza si no había nada.
  Future<void> deleteMasterKey({required String userId});

  /// Qué puede usar este dispositivo, ahora mismo, para autenticar (plan §5.2).
  Future<AuthAvailability> authAvailability();

  /// Activa o desactiva `FLAG_SECURE` en la actividad actual (plan §5.4): oculta el contenido en
  /// la vista de recientes y bloquea las capturas de pantalla mientras esté activo.
  Future<void> setSecure(bool secure);

  /// Copia `text` al portapapeles marcándolo como sensible (plan §5.4: "el portapapeles marca
  /// como sensible lo copiado de pantallas de claves"). En Android ≥ 13 el sistema oculta la vista
  /// previa de ese contenido; en versiones anteriores no hay nada que pedir y equivale a una copia
  /// normal. Usar en vez de `Clipboard.setData` de Flutter para la clave de recuperación, los
  /// códigos de respaldo y el secreto TOTP.
  Future<void> copySensitive(String text);
}
