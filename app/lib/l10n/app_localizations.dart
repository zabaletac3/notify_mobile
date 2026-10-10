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
