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

  /// `userId` fijo por defecto cuando las pruebas no registran una cuenta.
  static String fixedUserId = 'u1';
}

/// Preferencias de la cuenta en memoria (implementa también [VaultActivityStore]).
class FakeVaultPrefs implements VaultPrefsRepository, VaultActivityStore {
  CachedSession? session;
  bool onboardingSeen = false;
  final Map<String, LockSettings> settings = {};
  final Map<String, DateTime> lastActive = {};

  @override
  Future<CachedSession?> cachedSession() async => session;

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
