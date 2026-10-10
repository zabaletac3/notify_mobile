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
}
