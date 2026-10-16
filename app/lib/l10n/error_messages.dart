import 'package:axonote_domain/axonote_domain.dart';

import 'app_localizations.dart';

/// Textos de interfaz en español para códigos de validación y errores, portados de
/// `notify_web/src/lib/core/messages.ts`. La lógica trabaja con códigos; aquí se traducen.

/// Mensaje corto para un error del dominio (usa su `kind` y, si es `forbidden`, su `code`).
String errorMessageFor(AppLocalizations l10n, AppError error) => errorMessage(
  l10n,
  kind: error.kind,
  code: error is ForbiddenError ? error.code?.wire : null,
);

/// Mensaje de un código de validación (o el propio código si no hay texto).
String? validationMessage(AppLocalizations l10n, String? code) {
  switch (code) {
    case null:
      return null;
    case 'required':
      return l10n.validationRequired;
    case 'invalid-email':
      return l10n.validationInvalidEmail;
    case 'password-too-short':
      return l10n.validationPasswordTooShort;
    case 'passwords-dont-match':
      return l10n.validationPasswordsDontMatch;
    case 'terms-required':
      return l10n.validationTermsRequired;
    case 'name-too-short':
      return l10n.validationNameTooShort;
    case 'name-too-long':
      return l10n.validationNameTooLong;
    case 'name-taken':
      return l10n.validationNameTaken;
    case 'invalid-code':
      return l10n.validationInvalidCode;
    case 'invalid-token':
      return l10n.validationInvalidToken;
    case 'email-taken':
      return l10n.validationEmailTaken;
    case 'wrong-password':
      return l10n.validationWrongPassword;
    case 'same-password':
      return l10n.validationSamePassword;
    case 'invalid-recovery-key':
      return l10n.validationInvalidRecoveryKey;
    case 'invalid-payload':
      return l10n.validationInvalidPayload;
    case 'wipe-not-confirmed':
      return l10n.validationWipeNotConfirmed;
    default:
      return code;
  }
}

/// Mensaje corto para un aviso, según el `kind` (y el `code`) de un error.
String errorMessage(
  AppLocalizations l10n, {
  required String kind,
  String? code,
}) {
  switch (kind) {
    case 'network':
      return l10n.errorNetwork;
    case 'server':
      return l10n.errorServer;
    case 'unauthorized':
      return l10n.errorUnauthorized;
    case 'forbidden':
      switch (code) {
        case 'email-not-verified':
          return l10n.errorEmailNotVerified;
        case 'google-disabled':
          return l10n.errorGoogleDisabled;
        case 'google-email-unverified':
          return l10n.errorGoogleEmailUnverified;
        case 'account-deleted':
          return l10n.errorAccountDeleted;
        default:
          return l10n.errorForbidden;
      }
    case 'session-expired':
      return l10n.errorSessionExpired;
    case 'locked':
      return l10n.errorLocked;
    case 'decrypt':
      return l10n.errorDecrypt;
    case 'device-revoked':
      return l10n.errorDeviceRevoked;
    case 'not-found':
      return l10n.errorNotFound;
    case 'validation':
      return l10n.errorValidation;
    case 'conflict':
      switch (code) {
        case 'mfa-already-enabled':
          return l10n.errorMfaAlreadyEnabled;
        case 'mfa-not-pending':
          return l10n.errorMfaNotPending;
        case 'mfa-not-enabled':
          return l10n.errorMfaNotEnabled;
        default:
          return l10n.errorConflict;
      }
    case 'rate-limited':
      return l10n.errorRateLimited;
    default:
      return l10n.errorUnknown;
  }
}
