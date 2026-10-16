import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';

/// Argon2id falso y rápido: determinista para (contraseña, sal), sin librería nativa. Permite que
/// `createAccountKeys`/`unlockWithPassword` reales funcionen en las pruebas de estado sin gastar
/// segundos.
class FakeArgon2id implements crypto.Argon2idDeriver {
  @override
  Future<Uint8List> derive({
    required Uint8List password,
    required Uint8List salt,
    required int memoryKiB,
    required int iterations,
  }) async {
    var h = 0x811c9dc5;
    for (final b in <int>[...password, ...salt]) {
      h = ((h ^ b) * 16777619) & 0xffffffff;
    }
    final out = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      out[i] = ((h >> ((i % 4) * 8)) ^ (i * 131)) & 0xff;
    }
    return out;
  }
}

/// Repositorio de autenticación falso: no toca la red. Se configura con el estado que debe
/// devolver cada llamada y registra lo que recibió.
class FakeAuthRepository implements AuthRepository {
  User? currentUser;
  KeyBundle? loginBundle;
  LoginOutcome? loginOutcome;
  LoginResult? mfaResult;
  KeyBundle? keysBundle;
  KdfParams? preloginKdf;
  AppError? preloginError;
  AppError? loginError;
  AppError? verifyError;
  AppError? registerError;
  AppError? currentSessionError;
  AppError? requestResetError;

  final List<String> registeredEmails = [];
  final List<String> verifiedCodes = [];
  final List<String> resetEmails = [];
  String? lastRegisteredUserId;
  int logoutCalls = 0;
  int resendCalls = 0;

  @override
  Future<KdfParams> prelogin(String email) async {
    if (preloginError != null) throw AppFailure(preloginError!);
    return preloginKdf ??
        const KdfParams(
          alg: 'argon2id',
          memoryKiB: 1024,
          iterations: 1,
          parallelism: 1,
          salt: 'AAAAAAAAAAAAAAAAAAAAAA',
        );
  }

  @override
  Future<RegisterResult> register(RegisterRequest input) async {
    if (registerError != null) throw AppFailure(registerError!);
    lastRegisteredUserId = input.userId;
    registeredEmails.add(input.email);
    return RegisterResult(input.email);
  }

  @override
  Future<User> verifyEmail({
    required String email,
    required String code,
    required KeyBundle keys,
  }) async {
    if (verifyError != null) throw AppFailure(verifyError!);
    verifiedCodes.add(code);
    return currentUser ??
        User(
          id: lastRegisteredUserId ?? fixedUserId,
          email: email,
          fullName: 'Integración',
          emailVerified: true,
          hasGoogle: false,
          createdAt: DateTime(2026, 1, 1),
        );
  }

  @override
  Future<void> resendVerificationCode(String email) async {
    resendCalls++;
  }

  @override
  Future<LoginOutcome> login({
    required String email,
    required String authKey,
  }) async {
    if (loginError != null) throw AppFailure(loginError!);
    return loginOutcome ??
        LoginSucceeded(
          LoginResult(
            user: currentUser!,
            expiresAt: DateTime(2026, 1, 1),
            keys: loginBundle!,
          ),
        );
  }

  @override
  Future<LoginResult> loginMfa({
    required String mfaToken,
    required String code,
  }) async {
    if (loginError != null) throw AppFailure(loginError!);
    return mfaResult!;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
  }

  @override
  Future<User?> currentSession() async {
    if (currentSessionError != null) throw AppFailure(currentSessionError!);
    return currentUser;
  }

  @override
  Future<KeyBundle> keyBundle() async => keysBundle ?? loginBundle!;

  @override
  Future<void> requestPasswordReset(String email) async {
    if (requestResetError != null) throw AppFailure(requestResetError!);
    resetEmails.add(email);
  }

  AppError? updateProfileError;
  AppError? emailChangeError;
  AppError? confirmEmailChangeError;
  AppError? changePasswordError;
  AppError? deleteAccountError;
  String emailChangeResult = 'nuevo@correo.com';
  bool deleteAccountCalled = false;

  @override
  Future<User> updateProfile(String fullName) async {
    if (updateProfileError != null) throw AppFailure(updateProfileError!);
    final base = currentUser;
    final updated = User(
      id: base?.id ?? fixedUserId,
      email: base?.email ?? 'persona@example.com',
      fullName: fullName,
      emailVerified: base?.emailVerified ?? true,
      hasGoogle: base?.hasGoogle ?? false,
      createdAt: base?.createdAt ?? DateTime(2026, 1, 1),
    );
    currentUser = updated;
    return updated;
  }

  @override
  Future<String> requestEmailChange({
    required String newEmail,
    required String authKey,
  }) async {
    if (emailChangeError != null) throw AppFailure(emailChangeError!);
    return emailChangeResult;
  }

  @override
  Future<User> confirmEmailChange({
    required String email,
    required String code,
  }) async {
    if (confirmEmailChangeError != null) {
      throw AppFailure(confirmEmailChangeError!);
    }
    final base = currentUser;
    final updated = User(
      id: base?.id ?? fixedUserId,
      email: email,
      fullName: base?.fullName ?? 'Persona',
      emailVerified: true,
      hasGoogle: base?.hasGoogle ?? false,
      createdAt: base?.createdAt ?? DateTime(2026, 1, 1),
    );
    currentUser = updated;
    return updated;
  }

  @override
  Future<void> changePassword({
    required String currentAuthKey,
    required String newAuthKey,
    required KeyBundle keys,
  }) async {
    if (changePasswordError != null) throw AppFailure(changePasswordError!);
  }

  @override
  Future<void> deleteAccount(String authKey) async {
    if (deleteAccountError != null) throw AppFailure(deleteAccountError!);
    deleteAccountCalled = true;
  }

  bool mfaEnabled = false;
  AppError? mfaStatusError;

  @override
  Future<MfaStatus> mfaStatus() async {
    if (mfaStatusError != null) throw AppFailure(mfaStatusError!);
    return MfaStatus(
      enabled: mfaEnabled,
      enabledAt: mfaEnabled ? DateTime(2026, 1, 1) : null,
      recoveryCodesLeft: mfaEnabled ? 10 : 0,
    );
  }

  MfaSetup mfaSetupResult = const MfaSetup(
    secret: 'JBSWY3DPEHPK3PXP',
    otpauthUri: 'otpauth://totp/AxoNote:p@e.com?secret=JBSWY3DPEHPK3PXP',
  );
  List<String> recoveryCodesResult = const ['AAAA-1111', 'BBBB-2222'];
  AppError? mfaOpError;
  bool rotateRecoveryCalled = false;

  @override
  Future<MfaSetup> mfaSetup(String authKey) async {
    if (mfaOpError != null) throw AppFailure(mfaOpError!);
    return mfaSetupResult;
  }

  @override
  Future<List<String>> mfaEnable(String code) async {
    if (mfaOpError != null) throw AppFailure(mfaOpError!);
    mfaEnabled = true;
    return recoveryCodesResult;
  }

  @override
  Future<void> mfaDisable({
    required String authKey,
    required String code,
  }) async {
    if (mfaOpError != null) throw AppFailure(mfaOpError!);
    mfaEnabled = false;
  }

  @override
  Future<List<String>> mfaRegenerateCodes({
    required String authKey,
    required String code,
  }) async {
    if (mfaOpError != null) throw AppFailure(mfaOpError!);
    return recoveryCodesResult;
  }

  @override
  Future<void> rotateRecoveryKey({
    required String authKey,
    required String recoveryAuth,
    required String recoveryWrappedMasterKey,
  }) async {
    if (mfaOpError != null) throw AppFailure(mfaOpError!);
    rotateRecoveryCalled = true;
  }

  /// `userId` fijo por defecto cuando las pruebas no registran una cuenta.
  static String fixedUserId = 'u1';
}

/// Preferencias de la cuenta en memoria (implementa también [VaultActivityStore]).
class FakeVaultPrefs implements VaultPrefsRepository, VaultActivityStore {
  CachedSession? session;
  bool onboardingSeen = false;
  AppSettings appSettings = const AppSettings();
  final Map<String, LockSettings> settings = {};
  final Map<String, DateTime> lastActive = {};

  @override
  Future<CachedSession?> cachedSession() async => session;

  @override
  Future<AppSettings> readAppSettings(String userId) async => appSettings;

  @override
  Future<void> writeAppSettings(String userId, AppSettings value) async {
    appSettings = value;
  }

  @override
  Future<bool> readOnboardingSeen() async => onboardingSeen;

  @override
  Future<void> writeOnboardingSeen() async {
    onboardingSeen = true;
  }

  @override
  Future<LockSettings> readLockSettings(String userId) async =>
      settings[userId] ?? const LockSettings();

  @override
  Future<void> writeLockSettings(String userId, LockSettings value) async {
    settings[userId] = value;
  }

  @override
  Future<DateTime?> readLastActiveAt(String userId) async => lastActive[userId];

  @override
  Future<void> clearSession() async {
    session = null;
  }

  @override
  Future<DateTime?> read(String userId) async => lastActive[userId];

  @override
  Future<void> write(String userId, DateTime? at) async {
    if (at == null) {
      lastActive.remove(userId);
    } else {
      lastActive[userId] = at;
    }
  }
}

/// Borrado local falso: registra a qué cuentas se les pidió limpiar.
class FakeCleaner implements LocalDataCleaner {
  final List<String> wiped = [];

  @override
  Future<void> wipe(String userId) async => wiped.add(userId);
}
