// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'AxoNote';

  @override
  String get validationRequired => 'Este campo es obligatorio.';

  @override
  String get validationInvalidEmail => 'Ingresa un correo válido.';

  @override
  String get validationPasswordTooShort => 'Usa al menos 8 caracteres.';

  @override
  String get validationPasswordsDontMatch => 'Las contraseñas no coinciden.';

  @override
  String get validationTermsRequired =>
      'Debes aceptar los términos para continuar.';

  @override
  String get validationNameTooShort => 'Escribe tu nombre.';

  @override
  String get validationNameTooLong =>
      'El nombre es demasiado largo (máximo 30 caracteres).';

  @override
  String get validationNameTaken => 'Ya existe una carpeta con ese nombre.';

  @override
  String get validationInvalidCode => 'El código debe tener 6 dígitos.';

  @override
  String get validationInvalidToken => 'El enlace no es válido o ya venció.';

  @override
  String get validationEmailTaken => 'Ya existe una cuenta con ese correo.';

  @override
  String get validationWrongPassword => 'La contraseña no es correcta.';

  @override
  String get validationSamePassword =>
      'La nueva contraseña debe ser distinta de la actual.';

  @override
  String get validationInvalidRecoveryKey =>
      'La clave de recuperación no es correcta.';

  @override
  String get validationInvalidPayload =>
      'Ese ajuste ya no se puede cambiar desde aquí.';

  @override
  String get validationWipeNotConfirmed =>
      'Confirma que entiendes que se borrarán tus notas.';

  @override
  String get errorNetwork =>
      'Sin conexión. Tus cambios se guardarán y se sincronizarán al volver.';

  @override
  String get errorServer =>
      'No pudimos conectar con el servidor. Inténtalo de nuevo en unos minutos.';

  @override
  String get errorUnauthorized => 'Correo o contraseña incorrectos.';

  @override
  String get errorEmailNotVerified =>
      'Verifica tu correo para poder iniciar sesión.';

  @override
  String get errorGoogleDisabled => 'El acceso con Google no está disponible.';

  @override
  String get errorGoogleEmailUnverified =>
      'El correo de tu cuenta de Google no está verificado.';

  @override
  String get errorAccountDeleted =>
      'Esta cuenta está en proceso de eliminación. Restablece la contraseña para recuperarla.';

  @override
  String get errorForbidden => 'No tienes permiso para hacer esto.';

  @override
  String get errorSessionExpired => 'Tu sesión expiró. Inicia sesión de nuevo.';

  @override
  String get errorLocked => 'La app está bloqueada. Ingresa tu contraseña.';

  @override
  String get errorDecrypt => 'No se pudo descifrar esta nota.';

  @override
  String get errorDeviceRevoked => 'Se cerró la sesión en este dispositivo.';

  @override
  String get errorNotFound => 'No encontramos lo que buscabas.';

  @override
  String get errorValidation => 'Revisa los datos ingresados.';

  @override
  String get errorConflict => 'Esta nota se editó en otro dispositivo.';

  @override
  String get errorMfaAlreadyEnabled =>
      'La verificación en dos pasos ya está activada.';

  @override
  String get errorMfaNotPending =>
      'No hay una configuración de verificación pendiente.';

  @override
  String get errorMfaNotEnabled =>
      'La verificación en dos pasos no está activada.';

  @override
  String get errorRateLimited =>
      'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.';

  @override
  String get errorUnknown => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get errorKdfUnsupported => 'Actualiza AxoNote para iniciar sesión.';

  @override
  String get welcomeTagline => 'Tus notas, claras y siempre contigo.';

  @override
  String get welcomeCreateAccount => 'Crear cuenta';

  @override
  String get welcomeHaveAccount => 'Ya tengo una cuenta';

  @override
  String get welcomeTerms =>
      'Al continuar aceptas los Términos de uso y la Política de privacidad.';

  @override
  String get onboardSkip => 'Omitir';

  @override
  String get onboardNext => 'Siguiente';

  @override
  String get onboardStart => 'Empezar';

  @override
  String get onboard1Title => 'Escribe sin distracciones';

  @override
  String get onboard1Body =>
      'Un editor limpio con listas, checklists y formato cuando lo necesitas.';

  @override
  String get onboard2Title => 'Todo en su carpeta';

  @override
  String get onboard2Body =>
      'Organiza tus notas con carpetas y etiquetas, y encuéntralas al instante.';

  @override
  String get onboard3Title => 'En todos tus dispositivos';

  @override
  String get onboard3Body =>
      'Tus notas se sincronizan entre Linux, Windows y Android.';

  @override
  String get registerTitle => 'Crea tu cuenta';

  @override
  String get registerSubtitle =>
      'Guarda tus notas y sincronízalas en todos tus dispositivos.';

  @override
  String get fieldName => 'Nombre';

  @override
  String get fieldNameHint => 'Cómo quieres que te llamemos';

  @override
  String get fieldEmail => 'Correo electrónico';

  @override
  String get fieldEmailHint => 'nombre@correo.com';

  @override
  String get fieldPassword => 'Contraseña';

  @override
  String get fieldPasswordHintMin => 'Mínimo 8 caracteres';

  @override
  String get fieldPasswordHint => 'Tu contraseña';

  @override
  String get passwordHelper =>
      'Usa letras, números y un símbolo para mayor seguridad.';

  @override
  String get termsAccept =>
      'Acepto los Términos de uso y la Política de privacidad de AxoNote.';

  @override
  String get termsPrefix => 'Acepto los ';

  @override
  String get termsUsage => 'Términos de uso';

  @override
  String get termsConjunction => ' y la ';

  @override
  String get termsPrivacy => 'Política de privacidad';

  @override
  String get termsSuffix => ' de AxoNote.';

  @override
  String get createAccountButton => 'Crear cuenta';

  @override
  String get haveAccountPrompt => '¿Ya tienes cuenta?';

  @override
  String get logIn => 'Inicia sesión';

  @override
  String get loginTitle => 'Bienvenido de vuelta';

  @override
  String get loginButton => 'Iniciar sesión';

  @override
  String get forgotPasswordLink => '¿Olvidaste tu contraseña?';

  @override
  String get newHerePrompt => '¿Eres nuevo?';

  @override
  String get createAnAccount => 'Crea una cuenta';

  @override
  String get verifyTitle => 'Verifica tu correo';

  @override
  String verifySentTo(Object email) {
    return 'Enviamos un código de 6 dígitos a $email. Ingrésalo para continuar.';
  }

  @override
  String get verifySentPrefix => 'Enviamos un código de 6 dígitos a ';

  @override
  String get verifySentSuffix => '. Ingrésalo para continuar.';

  @override
  String get verifyButton => 'Verificar';

  @override
  String get verifyChangeEmail => 'Cambiar correo';

  @override
  String get verifyNoCodeQuestion => '¿No llegó?';

  @override
  String verifyResendCounter(Object time) {
    return 'Reenviar código en $time';
  }

  @override
  String get verifyResendLink => 'Reenviar código';

  @override
  String verifyResendIn(Object time) {
    return '¿No llegó? Reenviar código en $time';
  }

  @override
  String get verifyResend => '¿No llegó? Reenviar código';

  @override
  String get recoveryKeyTitle => 'Tu clave de recuperación';

  @override
  String get recoveryKeyIntro =>
      'Es la única forma de recuperar tus notas si olvidas la contraseña. Guárdala en un lugar seguro: no se volverá a mostrar.';

  @override
  String get recoveryKeyHelper =>
      'Puedes copiarla marcándola como dato sensible.';

  @override
  String get recoveryKeyCopy => 'Copiar clave';

  @override
  String get recoveryKeyCopied => 'Clave copiada';

  @override
  String get recoveryKeyConfirmLabel => 'Ya la guardé en un lugar seguro';

  @override
  String get recoveryKeyContinue => 'Continuar';

  @override
  String get twoFactorTitle => 'Verificación en dos pasos';

  @override
  String get twoFactorBody =>
      'Ingresa el código de tu aplicación de autenticación o uno de tus códigos de respaldo.';

  @override
  String get fieldMfaCode => 'Código';

  @override
  String get fieldMfaCodeHint => '123456 o XXXXX-XXXXX';

  @override
  String get twoFactorButton => 'Continuar';

  @override
  String get twoFactorBackToLogin => 'Volver a iniciar sesión';

  @override
  String get forgotTitle => '¿Olvidaste tu contraseña?';

  @override
  String get forgotSubtitle =>
      'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una nueva.';

  @override
  String get forgotSend => 'Enviar enlace';

  @override
  String get forgotBackToLogin => 'Volver a iniciar sesión';

  @override
  String get forgotSentTitle => 'Revisa tu correo';

  @override
  String forgotSentBody(Object email) {
    return 'Si existe una cuenta con $email, recibirás un enlace para restablecer tu contraseña en unos minutos.';
  }

  @override
  String get forgotSentPrefix => 'Si existe una cuenta con ';

  @override
  String get forgotSentSuffix =>
      ', recibirás un enlace para restablecer tu contraseña en unos minutos.';

  @override
  String get forgotSentResend => '¿No lo recibiste?';

  @override
  String get forgotSentResendLink => 'Reenviar enlace';

  @override
  String get unlockTitle => 'Desbloquea AxoNote';

  @override
  String get unlockPasswordBody => 'Ingresa tu contraseña para leer tus notas.';

  @override
  String get unlockButton => 'Desbloquear';

  @override
  String get unlockBiometric => 'Usar biometría o el teléfono';

  @override
  String get unlockSignOut => 'Cerrar sesión';

  @override
  String get unlockBiometricPrompt => 'Desbloquea AxoNote';

  @override
  String get sessionExpiredTitle => 'Tu sesión expiró';

  @override
  String get sessionExpiredBody =>
      'Por seguridad cerramos tu sesión. Inicia sesión de nuevo para seguir sincronizando. Tus notas guardadas en este dispositivo siguen aquí.';

  @override
  String get sessionExpiredOffline => 'Seguir sin conexión';

  @override
  String get sessionExpiredLogin => 'Iniciar sesión';

  @override
  String get signedOutNotice => 'Se cerró la sesión en este dispositivo.';

  @override
  String get mfaExpiredNotice =>
      'La verificación tardó demasiado. Inicia sesión de nuevo.';

  @override
  String get serverErrorTitle => 'No pudimos conectar con el servidor';

  @override
  String get serverErrorBody =>
      'Algo falló de nuestro lado. Tus notas están a salvo en este dispositivo. Inténtalo de nuevo en unos minutos.';

  @override
  String get retry => 'Reintentar';

  @override
  String errorCodeLabel(Object code) {
    return 'Código de error $code';
  }

  @override
  String get loading => 'Un momento…';

  @override
  String get derivingPassword => 'Protegiendo tu contraseña…';
}
