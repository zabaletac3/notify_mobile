/// Rutas del contrato que usa el cliente. Se declaran una sola vez y las usan tanto los clientes de
/// recurso como la prueba de contrato (`test/contract_test.dart`), que comprueba que cada
/// ruta + método existe en `contract/openapi.yaml`. Así el catálogo no puede divergir del uso real.
library;

/// Ruta + método HTTP del contrato.
class ApiRoute {
  const ApiRoute(this.method, this.pathTemplate);

  final String method;

  /// Plantilla con segmentos `{nombre}` (p. ej. `/notes/{noteId}/share`).
  final String pathTemplate;

  /// Sustituye los parámetros de la plantilla por sus valores.
  String resolve([Map<String, String> params = const {}]) {
    var path = pathTemplate;
    for (final entry in params.entries) {
      path = path.replaceAll('{${entry.key}}', entry.value);
    }
    return path;
  }
}

/// Todas las rutas que el cliente usa.
abstract final class ApiRoutes {
  // auth
  static const ApiRoute prelogin = ApiRoute('POST', '/auth/prelogin');
  static const ApiRoute register = ApiRoute('POST', '/auth/register');
  static const ApiRoute verifyEmail = ApiRoute('POST', '/auth/verify-email');
  static const ApiRoute resendCode = ApiRoute('POST', '/auth/resend-code');
  static const ApiRoute login = ApiRoute('POST', '/auth/login');
  static const ApiRoute loginMfa = ApiRoute('POST', '/auth/login/mfa');
  static const ApiRoute refresh = ApiRoute('POST', '/auth/refresh');
  static const ApiRoute logout = ApiRoute('POST', '/auth/logout');
  static const ApiRoute session = ApiRoute('GET', '/auth/session');
  static const ApiRoute passwordForgot = ApiRoute(
    'POST',
    '/auth/password/forgot',
  );
  static const ApiRoute passwordResetBundle = ApiRoute(
    'POST',
    '/auth/password/reset/bundle',
  );
  static const ApiRoute passwordReset = ApiRoute(
    'POST',
    '/auth/password/reset',
  );

  // account
  static const ApiRoute me = ApiRoute('GET', '/me');
  static const ApiRoute updateProfile = ApiRoute('PATCH', '/me');
  static const ApiRoute deleteAccount = ApiRoute('POST', '/me/delete');
  static const ApiRoute emailChange = ApiRoute('POST', '/me/email-change');
  static const ApiRoute emailChangeConfirm = ApiRoute(
    'POST',
    '/me/email-change/confirm',
  );
  static const ApiRoute password = ApiRoute('POST', '/me/password');

  // keys
  static const ApiRoute keys = ApiRoute('GET', '/keys');
  static const ApiRoute recoveryKey = ApiRoute('PUT', '/keys/recovery');

  // notes y carpetas (solo lectura; la escritura va por /sync)
  static const ApiRoute notes = ApiRoute('GET', '/notes');
  static const ApiRoute note = ApiRoute('GET', '/notes/{noteId}');
  static const ApiRoute folders = ApiRoute('GET', '/folders');

  // sync
  static const ApiRoute sync = ApiRoute('POST', '/sync');

  // share
  static const ApiRoute share = ApiRoute('GET', '/notes/{noteId}/share');
  static const ApiRoute createShare = ApiRoute('PUT', '/notes/{noteId}/share');
  static const ApiRoute revokeShare = ApiRoute(
    'DELETE',
    '/notes/{noteId}/share',
  );
  static const ApiRoute updateSharePayload = ApiRoute(
    'PUT',
    '/notes/{noteId}/share/payload',
  );
  static const ApiRoute publicNote = ApiRoute('GET', '/public/notes/{slug}');

  // devices
  static const ApiRoute devices = ApiRoute('GET', '/devices');
  static const ApiRoute device = ApiRoute('DELETE', '/devices/{deviceId}');

  // mfa
  static const ApiRoute mfa = ApiRoute('GET', '/mfa');
  static const ApiRoute mfaSetup = ApiRoute('POST', '/mfa/totp/setup');
  static const ApiRoute mfaEnable = ApiRoute('POST', '/mfa/totp/enable');
  static const ApiRoute mfaDisable = ApiRoute('POST', '/mfa/totp/disable');
  static const ApiRoute mfaRecoveryCodes = ApiRoute(
    'POST',
    '/mfa/recovery-codes',
  );

  // settings y storage
  static const ApiRoute settings = ApiRoute('GET', '/settings');
  static const ApiRoute updateSettings = ApiRoute('PATCH', '/settings');
  static const ApiRoute storageUsage = ApiRoute('GET', '/storage/usage');

  /// Todas las rutas, para la prueba de contrato.
  static const List<ApiRoute> all = <ApiRoute>[
    prelogin,
    register,
    verifyEmail,
    resendCode,
    login,
    loginMfa,
    refresh,
    logout,
    session,
    passwordForgot,
    passwordResetBundle,
    passwordReset,
    me,
    updateProfile,
    deleteAccount,
    emailChange,
    emailChangeConfirm,
    password,
    keys,
    recoveryKey,
    notes,
    note,
    folders,
    sync,
    share,
    createShare,
    revokeShare,
    updateSharePayload,
    publicNote,
    devices,
    device,
    mfa,
    mfaSetup,
    mfaEnable,
    mfaDisable,
    mfaRecoveryCodes,
    settings,
    updateSettings,
    storageUsage,
  ];
}
