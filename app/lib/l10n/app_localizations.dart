import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// No description provided for @appTitle.
  ///
  /// In es, this message translates to:
  /// **'AxoNote'**
  String get appTitle;

  /// No description provided for @validationRequired.
  ///
  /// In es, this message translates to:
  /// **'Este campo es obligatorio.'**
  String get validationRequired;

  /// No description provided for @validationInvalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un correo válido.'**
  String get validationInvalidEmail;

  /// No description provided for @validationPasswordTooShort.
  ///
  /// In es, this message translates to:
  /// **'Usa al menos 8 caracteres.'**
  String get validationPasswordTooShort;

  /// No description provided for @validationPasswordsDontMatch.
  ///
  /// In es, this message translates to:
  /// **'Las contraseñas no coinciden.'**
  String get validationPasswordsDontMatch;

  /// No description provided for @validationTermsRequired.
  ///
  /// In es, this message translates to:
  /// **'Debes aceptar los términos para continuar.'**
  String get validationTermsRequired;

  /// No description provided for @validationNameTooShort.
  ///
  /// In es, this message translates to:
  /// **'Escribe tu nombre.'**
  String get validationNameTooShort;

  /// No description provided for @validationNameTooLong.
  ///
  /// In es, this message translates to:
  /// **'El nombre es demasiado largo (máximo 30 caracteres).'**
  String get validationNameTooLong;

  /// No description provided for @validationNameTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una carpeta con ese nombre.'**
  String get validationNameTaken;

  /// No description provided for @validationInvalidCode.
  ///
  /// In es, this message translates to:
  /// **'El código debe tener 6 dígitos.'**
  String get validationInvalidCode;

  /// No description provided for @validationInvalidToken.
  ///
  /// In es, this message translates to:
  /// **'El enlace no es válido o ya venció.'**
  String get validationInvalidToken;

  /// No description provided for @validationEmailTaken.
  ///
  /// In es, this message translates to:
  /// **'Ya existe una cuenta con ese correo.'**
  String get validationEmailTaken;

  /// No description provided for @validationWrongPassword.
  ///
  /// In es, this message translates to:
  /// **'La contraseña no es correcta.'**
  String get validationWrongPassword;

  /// No description provided for @validationSamePassword.
  ///
  /// In es, this message translates to:
  /// **'La nueva contraseña debe ser distinta de la actual.'**
  String get validationSamePassword;

  /// No description provided for @validationInvalidRecoveryKey.
  ///
  /// In es, this message translates to:
  /// **'La clave de recuperación no es correcta.'**
  String get validationInvalidRecoveryKey;

  /// No description provided for @validationInvalidPayload.
  ///
  /// In es, this message translates to:
  /// **'Ese ajuste ya no se puede cambiar desde aquí.'**
  String get validationInvalidPayload;

  /// No description provided for @validationWipeNotConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Confirma que entiendes que se borrarán tus notas.'**
  String get validationWipeNotConfirmed;

  /// No description provided for @errorNetwork.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Tus cambios se guardarán y se sincronizarán al volver.'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In es, this message translates to:
  /// **'No pudimos conectar con el servidor. Inténtalo de nuevo en unos minutos.'**
  String get errorServer;

  /// No description provided for @errorUnauthorized.
  ///
  /// In es, this message translates to:
  /// **'Correo o contraseña incorrectos.'**
  String get errorUnauthorized;

  /// No description provided for @errorEmailNotVerified.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu correo para poder iniciar sesión.'**
  String get errorEmailNotVerified;

  /// No description provided for @errorGoogleDisabled.
  ///
  /// In es, this message translates to:
  /// **'El acceso con Google no está disponible.'**
  String get errorGoogleDisabled;

  /// No description provided for @errorGoogleEmailUnverified.
  ///
  /// In es, this message translates to:
  /// **'El correo de tu cuenta de Google no está verificado.'**
  String get errorGoogleEmailUnverified;

  /// No description provided for @errorAccountDeleted.
  ///
  /// In es, this message translates to:
  /// **'Esta cuenta está en proceso de eliminación. Restablece la contraseña para recuperarla.'**
  String get errorAccountDeleted;

  /// No description provided for @errorForbidden.
  ///
  /// In es, this message translates to:
  /// **'No tienes permiso para hacer esto.'**
  String get errorForbidden;

  /// No description provided for @errorSessionExpired.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión expiró. Inicia sesión de nuevo.'**
  String get errorSessionExpired;

  /// No description provided for @errorLocked.
  ///
  /// In es, this message translates to:
  /// **'La app está bloqueada. Ingresa tu contraseña.'**
  String get errorLocked;

  /// No description provided for @errorDecrypt.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descifrar esta nota.'**
  String get errorDecrypt;

  /// No description provided for @errorDeviceRevoked.
  ///
  /// In es, this message translates to:
  /// **'Se cerró la sesión en este dispositivo.'**
  String get errorDeviceRevoked;

  /// No description provided for @errorNotFound.
  ///
  /// In es, this message translates to:
  /// **'No encontramos lo que buscabas.'**
  String get errorNotFound;

  /// No description provided for @errorValidation.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos ingresados.'**
  String get errorValidation;

  /// No description provided for @errorConflict.
  ///
  /// In es, this message translates to:
  /// **'Esta nota se editó en otro dispositivo.'**
  String get errorConflict;

  /// No description provided for @errorMfaAlreadyEnabled.
  ///
  /// In es, this message translates to:
  /// **'La verificación en dos pasos ya está activada.'**
  String get errorMfaAlreadyEnabled;

  /// No description provided for @errorMfaNotPending.
  ///
  /// In es, this message translates to:
  /// **'No hay una configuración de verificación pendiente.'**
  String get errorMfaNotPending;

  /// No description provided for @errorMfaNotEnabled.
  ///
  /// In es, this message translates to:
  /// **'La verificación en dos pasos no está activada.'**
  String get errorMfaNotEnabled;

  /// No description provided for @errorRateLimited.
  ///
  /// In es, this message translates to:
  /// **'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.'**
  String get errorRateLimited;

  /// No description provided for @errorUnknown.
  ///
  /// In es, this message translates to:
  /// **'Algo salió mal. Inténtalo de nuevo.'**
  String get errorUnknown;

  /// No description provided for @errorKdfUnsupported.
  ///
  /// In es, this message translates to:
  /// **'Actualiza AxoNote para iniciar sesión.'**
  String get errorKdfUnsupported;

  /// No description provided for @welcomeTagline.
  ///
  /// In es, this message translates to:
  /// **'Tus notas, claras y siempre contigo.'**
  String get welcomeTagline;

  /// No description provided for @welcomeCreateAccount.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get welcomeCreateAccount;

  /// No description provided for @welcomeHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'Ya tengo una cuenta'**
  String get welcomeHaveAccount;

  /// No description provided for @welcomeTerms.
  ///
  /// In es, this message translates to:
  /// **'Al continuar aceptas los Términos de uso y la Política de privacidad.'**
  String get welcomeTerms;

  /// No description provided for @onboardSkip.
  ///
  /// In es, this message translates to:
  /// **'Omitir'**
  String get onboardSkip;

  /// No description provided for @onboardNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get onboardNext;

  /// No description provided for @onboardStart.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get onboardStart;

  /// No description provided for @onboard1Title.
  ///
  /// In es, this message translates to:
  /// **'Escribe sin distracciones'**
  String get onboard1Title;

  /// No description provided for @onboard1Body.
  ///
  /// In es, this message translates to:
  /// **'Un editor limpio con listas, checklists y formato cuando lo necesitas.'**
  String get onboard1Body;

  /// No description provided for @onboard2Title.
  ///
  /// In es, this message translates to:
  /// **'Todo en su carpeta'**
  String get onboard2Title;

  /// No description provided for @onboard2Body.
  ///
  /// In es, this message translates to:
  /// **'Organiza tus notas con carpetas y etiquetas, y encuéntralas al instante.'**
  String get onboard2Body;

  /// No description provided for @onboard3Title.
  ///
  /// In es, this message translates to:
  /// **'En todos tus dispositivos'**
  String get onboard3Title;

  /// No description provided for @onboard3Body.
  ///
  /// In es, this message translates to:
  /// **'Tus notas se sincronizan entre Linux, Windows y Android.'**
  String get onboard3Body;

  /// No description provided for @registerTitle.
  ///
  /// In es, this message translates to:
  /// **'Crea tu cuenta'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Guarda tus notas y sincronízalas en todos tus dispositivos.'**
  String get registerSubtitle;

  /// No description provided for @fieldName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get fieldName;

  /// No description provided for @fieldNameHint.
  ///
  /// In es, this message translates to:
  /// **'Cómo quieres que te llamemos'**
  String get fieldNameHint;

  /// No description provided for @fieldEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get fieldEmail;

  /// No description provided for @fieldEmailHint.
  ///
  /// In es, this message translates to:
  /// **'nombre@correo.com'**
  String get fieldEmailHint;

  /// No description provided for @fieldPassword.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get fieldPassword;

  /// No description provided for @fieldPasswordHintMin.
  ///
  /// In es, this message translates to:
  /// **'Mínimo 8 caracteres'**
  String get fieldPasswordHintMin;

  /// No description provided for @fieldPasswordHint.
  ///
  /// In es, this message translates to:
  /// **'Tu contraseña'**
  String get fieldPasswordHint;

  /// No description provided for @passwordHelper.
  ///
  /// In es, this message translates to:
  /// **'Usa letras, números y un símbolo para mayor seguridad.'**
  String get passwordHelper;

  /// No description provided for @termsAccept.
  ///
  /// In es, this message translates to:
  /// **'Acepto los Términos de uso y la Política de privacidad de AxoNote.'**
  String get termsAccept;

  /// No description provided for @createAccountButton.
  ///
  /// In es, this message translates to:
  /// **'Crear cuenta'**
  String get createAccountButton;

  /// No description provided for @haveAccountPrompt.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes cuenta?'**
  String get haveAccountPrompt;

  /// No description provided for @logIn.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión'**
  String get logIn;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido de vuelta'**
  String get loginTitle;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get loginButton;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotPasswordLink;

  /// No description provided for @newHerePrompt.
  ///
  /// In es, this message translates to:
  /// **'¿Eres nuevo?'**
  String get newHerePrompt;

  /// No description provided for @createAnAccount.
  ///
  /// In es, this message translates to:
  /// **'Crea una cuenta'**
  String get createAnAccount;

  /// No description provided for @verifyTitle.
  ///
  /// In es, this message translates to:
  /// **'Verifica tu correo'**
  String get verifyTitle;

  /// No description provided for @verifySentTo.
  ///
  /// In es, this message translates to:
  /// **'Enviamos un código de 6 dígitos a {email}. Ingrésalo para continuar.'**
  String verifySentTo(Object email);

  /// No description provided for @verifySentPrefix.
  ///
  /// In es, this message translates to:
  /// **'Enviamos un código de 6 dígitos a '**
  String get verifySentPrefix;

  /// No description provided for @verifySentSuffix.
  ///
  /// In es, this message translates to:
  /// **'. Ingrésalo para continuar.'**
  String get verifySentSuffix;

  /// No description provided for @verifyButton.
  ///
  /// In es, this message translates to:
  /// **'Verificar'**
  String get verifyButton;

  /// No description provided for @verifyChangeEmail.
  ///
  /// In es, this message translates to:
  /// **'Cambiar correo'**
  String get verifyChangeEmail;

  /// No description provided for @verifyNoCodeQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿No llegó?'**
  String get verifyNoCodeQuestion;

  /// No description provided for @verifyResendCounter.
  ///
  /// In es, this message translates to:
  /// **'Reenviar código en {time}'**
  String verifyResendCounter(Object time);

  /// No description provided for @verifyResendLink.
  ///
  /// In es, this message translates to:
  /// **'Reenviar código'**
  String get verifyResendLink;

  /// No description provided for @verifyResendIn.
  ///
  /// In es, this message translates to:
  /// **'¿No llegó? Reenviar código en {time}'**
  String verifyResendIn(Object time);

  /// No description provided for @verifyResend.
  ///
  /// In es, this message translates to:
  /// **'¿No llegó? Reenviar código'**
  String get verifyResend;

  /// No description provided for @recoveryKeyTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu clave de recuperación'**
  String get recoveryKeyTitle;

  /// No description provided for @recoveryKeyIntro.
  ///
  /// In es, this message translates to:
  /// **'Es la única forma de recuperar tus notas si olvidas la contraseña. Guárdala en un lugar seguro: no se volverá a mostrar.'**
  String get recoveryKeyIntro;

  /// No description provided for @recoveryKeyHelper.
  ///
  /// In es, this message translates to:
  /// **'Puedes copiarla marcándola como dato sensible.'**
  String get recoveryKeyHelper;

  /// No description provided for @recoveryKeyCopy.
  ///
  /// In es, this message translates to:
  /// **'Copiar clave'**
  String get recoveryKeyCopy;

  /// No description provided for @recoveryKeyCopied.
  ///
  /// In es, this message translates to:
  /// **'Clave copiada'**
  String get recoveryKeyCopied;

  /// No description provided for @recoveryKeyConfirmLabel.
  ///
  /// In es, this message translates to:
  /// **'Ya la guardé en un lugar seguro'**
  String get recoveryKeyConfirmLabel;

  /// No description provided for @recoveryKeyContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get recoveryKeyContinue;

  /// No description provided for @twoFactorTitle.
  ///
  /// In es, this message translates to:
  /// **'Verificación en dos pasos'**
  String get twoFactorTitle;

  /// No description provided for @twoFactorBody.
  ///
  /// In es, this message translates to:
  /// **'Ingresa el código de tu aplicación de autenticación o uno de tus códigos de respaldo.'**
  String get twoFactorBody;

  /// No description provided for @fieldMfaCode.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get fieldMfaCode;

  /// No description provided for @fieldMfaCodeHint.
  ///
  /// In es, this message translates to:
  /// **'123456 o XXXXX-XXXXX'**
  String get fieldMfaCodeHint;

  /// No description provided for @twoFactorButton.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get twoFactorButton;

  /// No description provided for @twoFactorBackToLogin.
  ///
  /// In es, this message translates to:
  /// **'Volver a iniciar sesión'**
  String get twoFactorBackToLogin;

  /// No description provided for @forgotTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste tu contraseña?'**
  String get forgotTitle;

  /// No description provided for @forgotSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una nueva.'**
  String get forgotSubtitle;

  /// No description provided for @forgotSend.
  ///
  /// In es, this message translates to:
  /// **'Enviar enlace'**
  String get forgotSend;

  /// No description provided for @forgotBackToLogin.
  ///
  /// In es, this message translates to:
  /// **'Volver a iniciar sesión'**
  String get forgotBackToLogin;

  /// No description provided for @forgotSentTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu correo'**
  String get forgotSentTitle;

  /// No description provided for @forgotSentBody.
  ///
  /// In es, this message translates to:
  /// **'Si existe una cuenta con {email}, recibirás un enlace para restablecer tu contraseña en unos minutos.'**
  String forgotSentBody(Object email);

  /// No description provided for @forgotSentPrefix.
  ///
  /// In es, this message translates to:
  /// **'Si existe una cuenta con '**
  String get forgotSentPrefix;

  /// No description provided for @forgotSentSuffix.
  ///
  /// In es, this message translates to:
  /// **', recibirás un enlace para restablecer tu contraseña en unos minutos.'**
  String get forgotSentSuffix;

  /// No description provided for @forgotSentResend.
  ///
  /// In es, this message translates to:
  /// **'¿No lo recibiste?'**
  String get forgotSentResend;

  /// No description provided for @forgotSentResendLink.
  ///
  /// In es, this message translates to:
  /// **'Reenviar enlace'**
  String get forgotSentResendLink;

  /// No description provided for @unlockTitle.
  ///
  /// In es, this message translates to:
  /// **'Desbloquea AxoNote'**
  String get unlockTitle;

  /// No description provided for @unlockPasswordBody.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu contraseña para leer tus notas.'**
  String get unlockPasswordBody;

  /// No description provided for @unlockButton.
  ///
  /// In es, this message translates to:
  /// **'Desbloquear'**
  String get unlockButton;

  /// No description provided for @unlockBiometric.
  ///
  /// In es, this message translates to:
  /// **'Usar biometría o el teléfono'**
  String get unlockBiometric;

  /// No description provided for @unlockSignOut.
  ///
  /// In es, this message translates to:
  /// **'Cerrar sesión'**
  String get unlockSignOut;

  /// No description provided for @unlockBiometricPrompt.
  ///
  /// In es, this message translates to:
  /// **'Desbloquea AxoNote'**
  String get unlockBiometricPrompt;

  /// No description provided for @sessionExpiredTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión expiró'**
  String get sessionExpiredTitle;

  /// No description provided for @sessionExpiredBody.
  ///
  /// In es, this message translates to:
  /// **'Por seguridad cerramos tu sesión. Inicia sesión de nuevo para seguir sincronizando. Tus notas guardadas en este dispositivo siguen aquí.'**
  String get sessionExpiredBody;

  /// No description provided for @sessionExpiredOffline.
  ///
  /// In es, this message translates to:
  /// **'Seguir sin conexión'**
  String get sessionExpiredOffline;

  /// No description provided for @sessionExpiredLogin.
  ///
  /// In es, this message translates to:
  /// **'Iniciar sesión'**
  String get sessionExpiredLogin;

  /// No description provided for @signedOutNotice.
  ///
  /// In es, this message translates to:
  /// **'Se cerró la sesión en este dispositivo.'**
  String get signedOutNotice;

  /// No description provided for @mfaExpiredNotice.
  ///
  /// In es, this message translates to:
  /// **'La verificación tardó demasiado. Inicia sesión de nuevo.'**
  String get mfaExpiredNotice;

  /// No description provided for @serverErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No pudimos conectar con el servidor'**
  String get serverErrorTitle;

  /// No description provided for @serverErrorBody.
  ///
  /// In es, this message translates to:
  /// **'Algo falló de nuestro lado. Tus notas están a salvo en este dispositivo. Inténtalo de nuevo en unos minutos.'**
  String get serverErrorBody;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @errorCodeLabel.
  ///
  /// In es, this message translates to:
  /// **'Código de error {code}'**
  String errorCodeLabel(Object code);

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Un momento…'**
  String get loading;

  /// No description provided for @derivingPassword.
  ///
  /// In es, this message translates to:
  /// **'Protegiendo tu contraseña…'**
  String get derivingPassword;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
