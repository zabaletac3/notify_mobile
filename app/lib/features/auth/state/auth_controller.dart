import 'dart:async';

import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/session.dart';
import '../../../bootstrap/providers.dart';
import '../../../data/auth/session_events.dart';
import '../../vault/state/clock.dart';
import '../../vault/state/vault_lock.dart';
import 'auth_state.dart';
import 'vault_lifecycle.dart';

/// Texto del cuadro de biometría al desbloquear al arrancar (sin `BuildContext` todavía).
const String _startupUnlockPrompt = 'Desbloquea AxoNote';

/// Sesión y flujos de cuenta (plan §10, Fase 8): registro → verificación → inicio de sesión →
/// segundo paso → desbloqueo → restablecimiento. Cada acción valida, llama al repositorio y
/// devuelve un [ActionResult] (nunca lanza); los errores por campo quedan en `fieldErrors`.
///
/// Sigue el comportamiento de `notify_web/src/lib/features/auth/state/auth.svelte.ts`, sin Google
/// (fuera de v1, D5) ni dispositivos de confianza (también fuera).
class AuthController extends Notifier<AuthState> {
  /// Claves de una cuenta recién creada, a la espera de verificar el correo.
  ({
    String userId,
    crypto.SecretKeyBytes masterKey,
    String recoveryKey,
    crypto.KeyBundle keys,
  })?
  _pendingSetup;

  /// Login a la espera del segundo paso. La `kek` (derivada de la contraseña) se guarda **solo en
  /// memoria** para no repetir Argon2id. Se borra al terminar, al fallar el ticket y al cerrar
  /// sesión.
  ({String token, crypto.SecretKeyBytes kek, DateTime expiresAt})? _pendingMfa;

  @override
  AuthState build() {
    final subscription = ref
        .read(sessionEventBusProvider)
        .stream
        .listen(_onSessionEvent);
    ref.onDispose(subscription.cancel);
    return const AuthState();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);
  VaultPrefsRepository get _prefs => ref.read(vaultPrefsProvider);
  VaultLockController get _vault => ref.read(vaultLockControllerProvider);
  Clock get _clock => ref.read(clockProvider);
  VaultLifecycle get _lifecycle => ref.read(vaultLifecycleProvider);
  LocalDataCleaner get _cleaner => ref.read(localDataCleanerProvider);
  crypto.Argon2idDeriver get _argon2id => ref.read(argon2idProvider);
  crypto.KdfBase get _kdfBase => ref.read(kdfBaseProvider);

  void _setSession(AxoSession value) =>
      ref.read(sessionProvider.notifier).set(value);

  /// Arranque en frío del cofre (plan §5.3). Lee el almacén seguro (sesión y ajustes de bloqueo) y
  /// decide el estado de navegación: `noSession` (onboarding/bienvenida), `locked` (desbloqueo
  /// local, aunque no haya red) o `unlocked` (clave recordada y bloqueo no vencido). Nunca deja el
  /// estado en `restoring`: si algo inesperado falla, cae a `noSession` para no quedarse en la
  /// pantalla de arranque.
  Future<void> bootstrap() async {
    try {
      // La marca de introducción se conoce antes de decidir la pantalla.
      final onboardingSeen = await _prefs.readOnboardingSeen();
      ref.read(onboardingSeenProvider.notifier).set(onboardingSeen);

      final cached = await _prefs.cachedSession();
      if (cached == null) {
        state = const AuthState(status: AuthStatus.anonymous);
        _setSession(AxoSession.noSession);
        return;
      }

      User? user;
      var expired = false;
      try {
        user = await _repo.currentSession();
      } on AppFailure catch (e) {
        switch (e.error) {
          case SessionExpiredError():
            expired = true;
          case DeviceRevokedError():
            await _endSession(cached.userId, AuthNotice.deviceRevoked);
            return;
          default:
            // Sin red u otro fallo transitorio: se sigue en local (desbloqueo sin red).
            user = null;
        }
      }

      if (expired) {
        state = state.copyWith(
          status: AuthStatus.expired,
          notice: () => AuthNotice.signedOutElsewhere,
        );
        _setSession(AxoSession.noSession);
        return;
      }

      if (user == null) {
        // Hay sesión guardada pero el servidor no la confirma (sin red o token caducado): se
        // ofrece el desbloqueo local en vez de mandar a la introducción.
        await _beforeUnlock(cached.userId);
        state = state.copyWith(status: AuthStatus.authenticated);
        _setSession(AxoSession.locked);
        return;
      }

      final settings = await _prefs.readLockSettings(cached.userId);
      await _beforeUnlock(cached.userId, settings);

      if (await _canAutoUnlock(settings, cached.userId)) {
        try {
          final unlocked = await _vault.unlockWithStoredKey(
            userId: cached.userId,
            prompt: _startupUnlockPrompt,
          );
          if (unlocked) {
            state = state.copyWith(
              status: AuthStatus.authenticated,
              user: () => user,
              notice: () => null,
            );
            await _onUnlocked(cached.userId);
            return;
          }
        } catch (_) {
          // Biometría cancelada, clave invalidada, etc.: se cae al desbloqueo con contraseña.
        }
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: () => user,
      );
      _setSession(AxoSession.locked);
    } on Object {
      // Nunca dejar la app en «restaurando».
      _setSession(AxoSession.noSession);
    }
  }

  /// Marca que la introducción ya se vio (al terminarla o saltarla) para no repetirla. Persiste en
  /// el almacén seguro; si la escritura falla, la marca vive al menos en memoria.
  Future<void> markOnboardingSeen() async {
    ref.read(onboardingSeenProvider.notifier).set(true);
    try {
      await _prefs.writeOnboardingSeen();
    } catch (_) {}
  }

  void clearErrors() {
    state = state.copyWith(error: () => null, fieldErrors: const {});
  }

  /// Segundos que faltan para poder reenviar el código (0 = ya se puede).
  int resendRemaining() {
    final availableAt = state.resendAvailableAt;
    if (availableAt == null) return 0;
    final remaining =
        availableAt.difference(_clock.now()).inMilliseconds / 1000;
    return remaining <= 0 ? 0 : remaining.ceil();
  }

  Future<ActionResult> register(RegisterInput input) async {
    final validation = validateRegister(input);
    if (validation is Invalid) return _rejectValidation(validation.errors);
    state = state.copyWith(
      busy: true,
      deriving: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final account = await crypto.createAccountKeys(
        password: input.password,
        userId: newId(),
        argon2id: _argon2id,
        kdfBase: _kdfBase,
      );
      _pendingSetup = (
        userId: account.userId,
        masterKey: account.masterKey,
        recoveryKey: account.recoveryKey,
        keys: account.keys,
      );
      final result = await _repo.register(
        RegisterRequest(
          userId: account.userId,
          fullName: input.fullName.trim(),
          email: input.email.trim().toLowerCase(),
          acceptedTerms: input.acceptedTerms,
          authKey: account.authKey,
          recoveryAuth: account.recoveryAuth,
          keys: _domainBundle(account.keys),
        ),
      );
      _startCooldown();
      state = state.copyWith(
        busy: false,
        deriving: false,
        pendingEmail: () => result.email,
      );
      return actionOk;
    } on AppFailure catch (e) {
      return _rejectFailure(e.error);
    } catch (_) {
      return _rejectFailure(const UnknownError());
    }
  }

  Future<ActionResult> verify(String code) async {
    final email = state.pendingEmail;
    if (email == null) {
      return _rejectFailure(const NotFoundError(entity: 'pending-email'));
    }
    final validation = validateVerificationCode(code);
    if (validation is Invalid) return _rejectValidation(validation.errors);
    state = state.copyWith(
      busy: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final setup = _pendingSetup;
      if (setup == null) {
        return _rejectFailure(const NotFoundError(entity: 'pending-setup'));
      }
      final user = await _repo.verifyEmail(
        email: email,
        code: code,
        keys: _domainBundle(setup.keys),
      );
      _pendingSetup = null;
      if (setup.userId == user.id) {
        await _unlockVault(setup.userId, setup.masterKey);
      }
      state = state.copyWith(
        busy: false,
        status: AuthStatus.authenticated,
        user: () => user,
        pendingEmail: () => null,
        pendingRecoveryKey: () => setup.recoveryKey,
        notice: () => null,
      );
      return actionOk;
    } on AppFailure catch (e) {
      return _rejectFailure(e.error);
    } catch (_) {
      return _rejectFailure(const UnknownError());
    }
  }

  Future<ActionResult> resendCode() async {
    final email = state.pendingEmail;
    if (email == null) {
      return _rejectFailure(const NotFoundError(entity: 'pending-email'));
    }
    if (resendRemaining() > 0) {
      return _rejectFailure(const RateLimitedError());
    }
    state = state.copyWith(
      busy: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      await _repo.resendVerificationCode(email);
      _startCooldown();
      state = state.copyWith(busy: false);
      return actionOk;
    } on AppFailure catch (e) {
      return _rejectFailure(e.error);
    }
  }

  /// Vuelve al registro desde la verificación (cambiar correo).
  void changeEmail() {
    state = state.copyWith(pendingEmail: () => null);
  }

  /// Cambia el nombre visible (fase 11.2).
  Future<ActionResult> updateProfile(String fullName) async {
    final validation = validateProfileName(fullName);
    if (validation is Invalid) return _rejectValidation(validation.errors);
    state = state.copyWith(
      busy: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final user = await _repo.updateProfile(fullName.trim());
      state = state.copyWith(busy: false, user: () => user);
      return actionOk;
    } on AppFailure catch (e) {
      return _rejectFailure(e.error);
    } catch (_) {
      return _rejectFailure(const UnknownError());
    }
  }

  /// Pide cambiar el correo: deriva la prueba de la contraseña actual y pide el código al correo
  /// nuevo. Deja [AuthState.pendingEmailChange] para el segundo paso.
  Future<ActionResult> requestEmailChange(
    String newEmail,
    String password,
  ) async {
    final validation = validateEmailChange(newEmail, password);
    if (validation is Invalid) return _rejectValidation(validation.errors);
    final userId = state.user?.id ?? (await _prefs.cachedSession())?.userId;
    if (userId == null) return _rejectFailure(const SessionExpiredError());
    state = state.copyWith(
      busy: true,
      deriving: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final bundle = await _repo.keyBundle();
      final authKey = await crypto.deriveAuthKey(
        password,
        _cryptoKdf(bundle.kdf),
        _argon2id,
      );
      final email = await _repo.requestEmailChange(
        newEmail: newEmail.trim().toLowerCase(),
        authKey: authKey,
      );
      state = state.copyWith(
        busy: false,
        deriving: false,
        pendingEmailChange: () => email,
      );
      return actionOk;
    } on crypto.KdfUnsupported {
      return _rejectFailure(const UnknownError(message: 'kdf-unsupported'));
    } on AppFailure catch (e) {
      return _rejectFailure(e.error);
    } catch (_) {
      return _rejectFailure(const UnknownError());
    }
  }

  /// Confirma el correo nuevo con el código.
  Future<ActionResult> confirmEmailChange(String code) async {
    final email = state.pendingEmailChange;
    if (email == null) {
      return _rejectFailure(
        const NotFoundError(entity: 'pending-email-change'),
      );
    }
    final validation = validateVerificationCode(code);
    if (validation is Invalid) return _rejectValidation(validation.errors);
    state = state.copyWith(
      busy: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final user = await _repo.confirmEmailChange(email: email, code: code);
      state = state.copyWith(
        busy: false,
        user: () => user,
        pendingEmailChange: () => null,
      );
      return actionOk;
    } on AppFailure catch (e) {
      return _rejectFailure(e.error);
    } catch (_) {
      return _rejectFailure(const UnknownError());
    }
  }

  /// Cancela el cambio de correo pendiente.
  void cancelEmailChange() {
    state = state.copyWith(pendingEmailChange: () => null);
  }

  /// Cambia la contraseña (la clave maestra no cambia; las notas no se vuelven a cifrar).
  Future<ActionResult> changePassword(
    String currentPassword,
    String newPassword,
    String confirmation,
  ) async {
    final validation = validateNewPassword(newPassword, confirmation);
    if (validation is Invalid) return _rejectValidation(validation.errors);
    if (currentPassword.isEmpty) {
      return _rejectValidation(const {'currentPassword': 'required'});
    }
    final userId = state.user?.id ?? (await _prefs.cachedSession())?.userId;
    if (userId == null) return _rejectFailure(const SessionExpiredError());
    state = state.copyWith(
      busy: true,
      deriving: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final bundle = await _repo.keyBundle();
      final keys = await crypto.changePasswordKeys(
        currentPassword: currentPassword,
        newPassword: newPassword,
        userId: userId,
        current: _cryptoBundle(bundle),
        argon2id: _argon2id,
      );
      try {
        await _repo.changePassword(
          currentAuthKey: keys.currentAuthKey,
          newAuthKey: keys.newAuthKey,
          keys: _domainBundle(keys.keys),
        );
      } finally {
        keys.masterKey.dispose();
      }
      state = state.copyWith(busy: false, deriving: false, unlockFailures: 0);
      return actionOk;
    } on crypto.KdfUnsupported {
      return _rejectFailure(const UnknownError(message: 'kdf-unsupported'));
    } on crypto.DecryptError {
      return _rejectFailure(
        const ValidationError({'currentPassword': 'wrong-password'}),
      );
    } on crypto.CryptoFormatError {
      return _rejectFailure(
        const ValidationError({'currentPassword': 'wrong-password'}),
      );
    } on AppFailure catch (e) {
      return _rejectFailure(e.error);
    } catch (_) {
      return _rejectFailure(const UnknownError());
    }
  }

  /// Elimina la cuenta (exige la contraseña). Cierra la sesión local al terminar.
  Future<ActionResult> deleteAccount(String password) async {
    if (password.isEmpty) {
      return _rejectValidation(const {'password': 'required'});
    }
    final userId = state.user?.id ?? (await _prefs.cachedSession())?.userId;
    if (userId == null) return _rejectFailure(const SessionExpiredError());
    state = state.copyWith(
      busy: true,
      deriving: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final bundle = await _repo.keyBundle();
      final authKey = await crypto.deriveAuthKey(
        password,
        _cryptoKdf(bundle.kdf),
        _argon2id,
      );
      await _repo.deleteAccount(authKey);
      await _endSession(userId, null);
      return actionOk;
    } on crypto.KdfUnsupported {
      return _rejectFailure(const UnknownError(message: 'kdf-unsupported'));
    } on AppFailure catch (e) {
      return _rejectFailure(e.error);
    } catch (_) {
      return _rejectFailure(const UnknownError());
    }
  }

  /// Deriva la prueba de la contraseña actual (o `null` si no hay cuenta).
  Future<String?> _currentAuthKey(String password) async {
    final userId = state.user?.id ?? (await _prefs.cachedSession())?.userId;
    if (userId == null) return null;
    final bundle = await _repo.keyBundle();
    return crypto.deriveAuthKey(password, _cryptoKdf(bundle.kdf), _argon2id);
  }

  /// Genera un secreto TOTP pendiente de confirmar (fase 11.3).
  Future<Result<MfaSetup>> mfaSetup(String password) async {
    state = state.copyWith(
      busy: true,
      deriving: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final authKey = await _currentAuthKey(password);
      if (authKey == null) {
        state = state.copyWith(busy: false, deriving: false);
        return const Err(SessionExpiredError());
      }
      final setup = await _repo.mfaSetup(authKey);
      state = state.copyWith(busy: false, deriving: false);
      return Ok(setup);
    } on crypto.KdfUnsupported {
      state = state.copyWith(busy: false, deriving: false);
      return const Err(UnknownError(message: 'kdf-unsupported'));
    } on AppFailure catch (e) {
      _rejectFailure(e.error);
      return Err(e.error);
    } catch (_) {
      _rejectFailure(const UnknownError());
      return const Err(UnknownError());
    }
  }

  /// Confirma el código TOTP y activa la verificación; devuelve los códigos de respaldo.
  Future<Result<List<String>>> mfaEnable(String code) async {
    state = state.copyWith(
      busy: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final codes = await _repo.mfaEnable(code);
      state = state.copyWith(busy: false);
      return Ok(codes);
    } on AppFailure catch (e) {
      _rejectFailure(e.error);
      return Err(e.error);
    } catch (_) {
      _rejectFailure(const UnknownError());
      return const Err(UnknownError());
    }
  }

  /// Desactiva la verificación (contraseña + código).
  Future<ActionResult> mfaDisable(String password, String code) async {
    state = state.copyWith(
      busy: true,
      deriving: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final authKey = await _currentAuthKey(password);
      if (authKey == null) {
        state = state.copyWith(busy: false, deriving: false);
        return actionErr(const SessionExpiredError());
      }
      await _repo.mfaDisable(authKey: authKey, code: code);
      state = state.copyWith(busy: false, deriving: false);
      return actionOk;
    } on crypto.KdfUnsupported {
      state = state.copyWith(busy: false, deriving: false);
      return actionErr(const UnknownError(message: 'kdf-unsupported'));
    } on AppFailure catch (e) {
      _rejectFailure(e.error);
      return actionErr(e.error);
    } catch (_) {
      _rejectFailure(const UnknownError());
      return actionErr(const UnknownError());
    }
  }

  /// Regenera los códigos de respaldo (contraseña + código).
  Future<Result<List<String>>> mfaRegenerateCodes(
    String password,
    String code,
  ) async {
    state = state.copyWith(
      busy: true,
      deriving: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final authKey = await _currentAuthKey(password);
      if (authKey == null) {
        state = state.copyWith(busy: false, deriving: false);
        return const Err(SessionExpiredError());
      }
      final codes = await _repo.mfaRegenerateCodes(
        authKey: authKey,
        code: code,
      );
      state = state.copyWith(busy: false, deriving: false);
      return Ok(codes);
    } on crypto.KdfUnsupported {
      state = state.copyWith(busy: false, deriving: false);
      return const Err(UnknownError(message: 'kdf-unsupported'));
    } on AppFailure catch (e) {
      _rejectFailure(e.error);
      return Err(e.error);
    } catch (_) {
      _rejectFailure(const UnknownError());
      return const Err(UnknownError());
    }
  }

  /// Rota la clave de recuperación (exige la contraseña). Devuelve la clave nueva.
  Future<Result<String>> rotateRecoveryKey(String password) async {
    final userId = state.user?.id ?? (await _prefs.cachedSession())?.userId;
    if (userId == null) return const Err(SessionExpiredError());
    state = state.copyWith(
      busy: true,
      deriving: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final bundle = await _repo.keyBundle();
      final rotated = await crypto.rotateRecoveryKeys(
        password: password,
        userId: userId,
        keys: _cryptoBundle(bundle),
        argon2id: _argon2id,
      );
      await _repo.rotateRecoveryKey(
        authKey: rotated.authKey,
        recoveryAuth: rotated.recoveryAuth,
        recoveryWrappedMasterKey: rotated.recoveryWrappedMasterKey,
      );
      state = state.copyWith(
        busy: false,
        deriving: false,
        pendingRecoveryKey: () => rotated.recoveryKey,
      );
      return Ok(rotated.recoveryKey);
    } on crypto.KdfUnsupported {
      state = state.copyWith(busy: false, deriving: false);
      return const Err(UnknownError(message: 'kdf-unsupported'));
    } on crypto.DecryptError {
      final failure = _rejectFailure(
        const ValidationError({'password': 'wrong-password'}),
      );
      return Err((failure as Err).error);
    } on crypto.CryptoFormatError {
      final failure = _rejectFailure(
        const ValidationError({'password': 'wrong-password'}),
      );
      return Err((failure as Err).error);
    } on AppFailure catch (e) {
      _rejectFailure(e.error);
      return Err(e.error);
    } catch (_) {
      _rejectFailure(const UnknownError());
      return const Err(UnknownError());
    }
  }

  Future<ActionResult> login(LoginInput input) async {
    final validation = validateLogin(input);
    if (validation is Invalid) return _rejectValidation(validation.errors);
    state = state.copyWith(
      busy: true,
      deriving: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final kdf = await _repo.prelogin(input.email);
      final derived = await crypto.deriveFromPassword(
        input.password,
        _cryptoKdf(kdf),
        _argon2id,
      );
      final outcome = await _repo.login(
        email: input.email,
        authKey: derived.authKey,
      );
      switch (outcome) {
        case LoginMfaRequired():
          _pendingMfa = (
            token: outcome.challenge.mfaToken,
            kek: derived.kek,
            expiresAt: outcome.challenge.expiresAt,
          );
          state = state.copyWith(
            busy: false,
            deriving: false,
            mfaPending: true,
          );
          return actionOk;
        case LoginSucceeded():
          await _finishLogin(outcome.result, derived.kek);
          return actionOk;
      }
    } on crypto.KdfUnsupported {
      return _rejectFailure(const UnknownError(message: 'kdf-unsupported'));
    } on AppFailure catch (e) {
      if (e.error is ForbiddenError &&
          (e.error as ForbiddenError).code == ForbiddenCode.emailNotVerified) {
        state = state.copyWith(
          pendingEmail: () => input.email.trim().toLowerCase(),
        );
      }
      return _rejectFailure(e.error);
    } catch (_) {
      return _rejectFailure(const UnknownError());
    }
  }

  Future<ActionResult> verifyMfa(String code) async {
    final pending = _pendingMfa;
    if (pending == null) {
      return _rejectFailure(const NotFoundError(entity: 'mfa'));
    }
    final validation = validateMfaCode(code);
    if (validation is Invalid) return _rejectValidation(validation.errors);
    state = state.copyWith(
      busy: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final result = await _repo.loginMfa(mfaToken: pending.token, code: code);
      await _finishLogin(result, pending.kek);
      return actionOk;
    } on AppFailure catch (e) {
      if (_isExpiredMfaTicket(e.error)) {
        _clearPendingMfa();
        state = state.copyWith(notice: () => AuthNotice.mfaExpired);
      }
      return _rejectFailure(e.error);
    } catch (_) {
      return _rejectFailure(const UnknownError());
    }
  }

  /// Desbloquea con la contraseña (cuando la clave no se recordó o el cofre se bloqueó). Tras
  /// demasiados intentos fallidos, cierra la sesión.
  Future<ActionResult> unlock(String password) async {
    final userId = state.user?.id ?? (await _prefs.cachedSession())?.userId;
    if (userId == null) {
      return _rejectFailure(const SessionExpiredError());
    }
    if (password.isEmpty) {
      return _rejectValidation(const {'password': 'required'});
    }
    state = state.copyWith(
      busy: true,
      deriving: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      final bundle = await _repo.keyBundle();
      final unlocked = await crypto.unlockWithPassword(
        password: password,
        userId: userId,
        keys: _cryptoBundle(bundle),
        argon2id: _argon2id,
      );
      await _unlockVault(userId, unlocked.masterKey);
      state = state.copyWith(
        busy: false,
        deriving: false,
        status: AuthStatus.authenticated,
        notice: () => null,
        unlockFailures: 0,
      );
      return actionOk;
    } on crypto.KdfUnsupported {
      return _rejectFailure(const UnknownError(message: 'kdf-unsupported'));
    } on crypto.DecryptError {
      return _wrongPassword();
    } on crypto.CryptoFormatError {
      return _wrongPassword();
    } on AppFailure catch (e) {
      return _rejectFailure(e.error);
    } catch (_) {
      return _rejectFailure(const UnknownError());
    }
  }

  /// Desbloquea con la clave recordada (biometría o credencial del dispositivo). Devuelve un
  /// error suave si no hay nada guardado, para que la pantalla muestre la contraseña.
  Future<ActionResult> unlockWithStoredKey(String prompt) async {
    final userId = state.user?.id ?? (await _prefs.cachedSession())?.userId;
    if (userId == null) {
      return _rejectFailure(const SessionExpiredError());
    }
    final settings = await _prefs.readLockSettings(userId);
    await _beforeUnlock(userId, settings);
    try {
      final unlocked = await _vault.unlockWithStoredKey(
        userId: userId,
        prompt: prompt,
      );
      if (!unlocked) {
        return _rejectFailure(const NotFoundError(entity: 'master-key'));
      }
      state = state.copyWith(
        status: AuthStatus.authenticated,
        notice: () => null,
        unlockFailures: 0,
      );
      await _onUnlocked(userId);
      return actionOk;
    } catch (_) {
      return _rejectFailure(const UnknownError());
    }
  }

  Future<ActionResult> logout({AuthNotice? notice}) async {
    final userId = state.user?.id ?? (await _prefs.cachedSession())?.userId;
    await _endSession(userId, notice);
    return actionOk;
  }

  /// Pide el enlace de restablecimiento. Siempre «funciona» para no revelar qué correos existen.
  Future<ActionResult> forgotPassword(String email) async {
    final validation = validateEmail(email);
    if (validation is Invalid) return _rejectValidation(validation.errors);
    state = state.copyWith(
      busy: true,
      error: () => null,
      fieldErrors: const {},
    );
    try {
      await _repo.requestPasswordReset(email.trim());
      state = state.copyWith(
        busy: false,
        resetRequested: true,
        resetEmail: () => email.trim(),
      );
      return actionOk;
    } on AppFailure catch (e) {
      return _rejectFailure(e.error);
    }
  }

  /// La persona ya guardó la clave de recuperación: se borra de la memoria.
  void acknowledgeRecoveryKey() {
    state = state.copyWith(pendingRecoveryKey: () => null);
  }

  /// Descarta el aviso de sesión (p. ej. «seguir sin conexión» en el diálogo de sesión expirada).
  void clearNotice() {
    state = state.copyWith(notice: () => null);
  }

  // ─── Internos ───────────────────────────────────────────────────────────────

  static const int _maxUnlockAttempts = 5;

  Future<void> _finishLogin(
    LoginResult session,
    crypto.SecretKeyBytes kek,
  ) async {
    final userId = session.user.id;
    crypto.SecretKeyBytes masterKey;
    try {
      masterKey = await crypto.unwrap(
        kek,
        session.keys.wrappedMasterKey,
        crypto.masterKeyAad(userId, crypto.MasterKeyKind.password),
      );
    } catch (_) {
      throw const AppFailure(DecryptError());
    } finally {
      kek.dispose();
    }
    await _unlockVault(userId, masterKey);
    _clearPendingMfa();
    state = state.copyWith(
      busy: false,
      deriving: false,
      status: AuthStatus.authenticated,
      user: () => session.user,
      error: () => null,
      fieldErrors: const {},
      mfaPending: false,
      notice: () => null,
      unlockFailures: 0,
    );
  }

  /// Carga los ajustes y los deja en el gestor de bloqueo antes de desbloquear.
  Future<void> _beforeUnlock(String userId, [LockSettings? settings]) async {
    final resolved = settings ?? await _prefs.readLockSettings(userId);
    await _vault.updateSettings(resolved);
  }

  Future<void> _unlockVault(
    String userId,
    crypto.SecretKeyBytes masterKey,
  ) async {
    await _beforeUnlock(userId);
    await _vault.unlock(
      userId: userId,
      masterKey: masterKey,
      rememberOnThisDevice: true,
    );
    await _onUnlocked(userId);
  }

  Future<void> _onUnlocked(String userId) async {
    final hook = _lifecycle.onUnlocked;
    if (hook != null) await hook(userId, _vault.vault);
  }

  Future<void> _endSession(String? userId, AuthNotice? notice) async {
    _clearPendingMfa();
    _pendingSetup?.masterKey.dispose();
    _pendingSetup = null;
    if (userId != null) {
      await _vault.signOut(userId: userId);
      await _cleaner.wipe(userId);
    }
    try {
      await _repo.logout();
    } catch (_) {
      // Best-effort: sin red se limpia igual lo local.
    }
    state = const AuthState(status: AuthStatus.anonymous)
        .copyWith(notice: () => notice);
    final hook = _lifecycle.onSignedOut;
    if (hook != null) await hook(userId);
  }

  void _onSessionEvent(SessionEvent event) {
    switch (event) {
      case SessionEvent.expired:
        if (state.status == AuthStatus.authenticated) {
          state = state.copyWith(notice: () => AuthNotice.signedOutElsewhere);
        }
      case SessionEvent.deviceRevoked:
        final userId = state.user?.id;
        unawaited(_endSession(userId, AuthNotice.deviceRevoked));
    }
  }

  bool _isExpiredMfaTicket(AppError error) {
    if (error is SessionExpiredError) return true;
    if (error is ValidationError) return error.fields.containsKey('mfaToken');
    return false;
  }

  void _clearPendingMfa() {
    _pendingMfa?.kek.dispose();
    _pendingMfa = null;
  }

  /// Si el tiempo de bloqueo ya venció (o el ajuste exige bloqueo al salir), no se intenta el
  /// desbloqueo automático con la clave guardada.
  Future<bool> _canAutoUnlock(LockSettings settings, String userId) async {
    if (settings.lockOnExit) return false;
    switch (settings.lockTimeout) {
      case LockTimeout.immediately:
        return false;
      case LockTimeout.never:
        return true;
      case LockTimeout.oneMinute:
      case LockTimeout.fiveMinutes:
      case LockTimeout.fifteenMinutes:
        final after = settings.lockTimeout.after!;
        final lastActiveAt = await _prefs.readLastActiveAt(userId);
        if (lastActiveAt == null) return true;
        return _clock.now().difference(lastActiveAt) < after;
    }
  }

  void _startCooldown() {
    state = state.copyWith(
      resendAvailableAt: () => _clock.now().add(const Duration(seconds: 60)),
    );
  }

  ActionResult _rejectValidation(FieldErrors errors) {
    state = state.copyWith(
      busy: false,
      deriving: false,
      error: () => ValidationError(errors),
      fieldErrors: errors,
    );
    return actionErr(ValidationError(errors));
  }

  /// Un intento de desbloqueo con contraseña incorrecta. Tras [_maxUnlockAttempts] fallos seguidos,
  /// cierra la sesión.
  ActionResult _wrongPassword() {
    final failures = state.unlockFailures + 1;
    state = state.copyWith(
      busy: false,
      deriving: false,
      unlockFailures: failures,
      fieldErrors: const {'password': 'wrong-password'},
      error: () => const ValidationError({'password': 'wrong-password'}),
    );
    if (failures >= _maxUnlockAttempts) {
      unawaited(logout(notice: AuthNotice.signedOutElsewhere));
    }
    return actionErr(const ValidationError({'password': 'wrong-password'}));
  }

  ActionResult _rejectFailure(AppError error) {
    state = state.copyWith(
      busy: false,
      deriving: false,
      error: () => error,
      fieldErrors: error is ValidationError ? error.fields : state.fieldErrors,
    );
    return actionErr(error);
  }

  static crypto.KdfParams _cryptoKdf(KdfParams kdf) => crypto.KdfParams(
    alg: kdf.alg,
    memoryKiB: kdf.memoryKiB,
    iterations: kdf.iterations,
    parallelism: kdf.parallelism,
    salt: kdf.salt,
  );

  static crypto.KeyBundle _cryptoBundle(KeyBundle keys) => crypto.KeyBundle(
    kdf: _cryptoKdf(keys.kdf),
    wrappedMasterKey: keys.wrappedMasterKey,
    recoveryWrappedMasterKey: keys.recoveryWrappedMasterKey,
    keysVersion: keys.keysVersion,
  );

  static KeyBundle _domainBundle(crypto.KeyBundle keys) => KeyBundle(
    kdf: KdfParams(
      alg: keys.kdf.alg,
      memoryKiB: keys.kdf.memoryKiB,
      iterations: keys.kdf.iterations,
      parallelism: keys.kdf.parallelism,
      salt: keys.kdf.salt,
    ),
    wrappedMasterKey: keys.wrappedMasterKey,
    recoveryWrappedMasterKey: keys.recoveryWrappedMasterKey,
    keysVersion: keys.keysVersion,
  );
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
