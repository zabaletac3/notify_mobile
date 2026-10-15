import 'dart:typed_data';

import 'package:axonote_app/app/session.dart';
import 'package:axonote_app/bootstrap/providers.dart';
import 'package:axonote_app/data/auth/session_events.dart';
import 'package:axonote_app/features/auth/state/auth_controller.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/features/vault/state/vault_lock.dart';
import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

ProviderContainer _container({
  required FakeAuthRepository repo,
  required FakeVaultPrefs prefs,
  FakeCleaner? cleaner,
  FakeAxonotePlatform? platform,
  Clock? clock,
}) {
  AxonotePlatform.instance = platform ?? FakeAxonotePlatform();
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      vaultPrefsProvider.overrideWithValue(prefs),
      argon2idProvider.overrideWithValue(FakeArgon2id()),
      deviceNameProvider.overrideWithValue('Test'),
      vaultActivityStoreProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(clock ?? FakeClock(DateTime(2026, 1, 1))),
      localDataCleanerProvider.overrideWithValue(cleaner ?? FakeCleaner()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Crea una cuenta real (con las funciones de `axonote_crypto` y el Argon2id falso) y devuelve lo
/// necesario para configurar el repositorio falso.
Future<
  ({
    String userId,
    String password,
    crypto.SecretKeyBytes masterKey,
    KeyBundle domainBundle,
  })
>
_account({String password = 'Secret123!'}) async {
  final account = await crypto.createAccountKeys(
    password: password,
    userId: 'u1',
    argon2id: FakeArgon2id(),
    kdfBase: crypto.lightKdf,
  );
  return (
    userId: account.userId,
    password: password,
    masterKey: account.masterKey,
    domainBundle: KeyBundle(
      kdf: KdfParams(
        alg: account.keys.kdf.alg,
        memoryKiB: account.keys.kdf.memoryKiB,
        iterations: account.keys.kdf.iterations,
        parallelism: account.keys.kdf.parallelism,
        salt: account.keys.kdf.salt,
      ),
      wrappedMasterKey: account.keys.wrappedMasterKey,
      recoveryWrappedMasterKey: account.keys.recoveryWrappedMasterKey,
      keysVersion: account.keys.keysVersion,
    ),
  );
}

User _user(String id) => User(
  id: id,
  email: 'persona@example.com',
  fullName: 'Persona',
  emailVerified: true,
  hasGoogle: false,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('registro y verificación', () {
    test(
      'registro válido deja el correo pendiente y arranca el enfriamiento',
      () async {
        final repo = FakeAuthRepository();
        final prefs = FakeVaultPrefs();
        final container = _container(repo: repo, prefs: prefs);
        final controller = container.read(authControllerProvider.notifier);

        final result = await controller.register(
          const RegisterInput(
            fullName: 'Persona',
            email: 'Persona@Example.COM',
            password: 'Secret123!',
            acceptedTerms: true,
          ),
        );
        expect(result.isOk, isTrue);
        final state = container.read(authControllerProvider);
        expect(state.pendingEmail, 'persona@example.com');
        expect(state.resendAvailableAt, isNotNull);
        expect(controller.resendRemaining(), 60);
        expect(repo.registeredEmails.single, 'persona@example.com');
      },
    );

    test(
      'registro inválido devuelve errores por campo y no llama al servidor',
      () async {
        final repo = FakeAuthRepository();
        final container = _container(repo: repo, prefs: FakeVaultPrefs());
        final controller = container.read(authControllerProvider.notifier);

        final result = await controller.register(
          const RegisterInput(
            fullName: 'A',
            email: 'no',
            password: 'corta',
            acceptedTerms: false,
          ),
        );
        expect(result.isOk, isFalse);
        expect(container.read(authControllerProvider).fieldErrors, {
          'fullName': 'name-too-short',
          'email': 'invalid-email',
          'password': 'password-too-short',
          'acceptedTerms': 'terms-required',
        });
        expect(repo.registeredEmails, isEmpty);
      },
    );

    test('verificación válida desbloquea el cofre y muestra la clave de recuperación', () async {
      final repo = FakeAuthRepository();
      final prefs = FakeVaultPrefs();
      final container = _container(repo: repo, prefs: prefs);
      final controller = container.read(authControllerProvider.notifier);

      await controller.register(
        const RegisterInput(
          fullName: 'Persona',
          email: 'persona@example.com',
          password: 'Secret123!',
          acceptedTerms: true,
        ),
      );
      final result = await controller.verify('123456');

      expect(result.isOk, isTrue);
      expect(repo.verifiedCodes, ['123456']);
      expect(container.read(sessionProvider), AxoSession.unlocked);
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.pendingEmail, isNull);
      expect(state.pendingRecoveryKey, isNotNull);
    });

    test('el reenvío respeta el enfriamiento', () async {
      final clock = FakeClock(DateTime(2026, 1, 1));
      final repo = FakeAuthRepository();
      final container = _container(
        repo: repo,
        prefs: FakeVaultPrefs(),
        clock: clock,
      );
      final controller = container.read(authControllerProvider.notifier);
      await controller.register(
        const RegisterInput(
          fullName: 'Persona',
          email: 'persona@example.com',
          password: 'Secret123!',
          acceptedTerms: true,
        ),
      );

      final tooSoon = await controller.resendCode();
      expect(tooSoon.isOk, isFalse);
      expect((tooSoon as Err).error, isA<RateLimitedError>());
      expect(repo.resendCalls, 0);

      clock.advance(const Duration(seconds: 61));
      final ok = await controller.resendCode();
      expect(ok.isOk, isTrue);
      expect(repo.resendCalls, 1);
    });
  });

  group('inicio de sesión', () {
    test('loguear sin MFA desbloquea el cofre', () async {
      final account = await _account();
      final repo = FakeAuthRepository()
        ..preloginKdf = account.domainBundle.kdf
        ..loginBundle = account.domainBundle
        ..currentUser = _user(account.userId);
      final container = _container(repo: repo, prefs: FakeVaultPrefs());
      final controller = container.read(authControllerProvider.notifier);

      final result = await controller.login(
        const LoginInput(email: 'persona@example.com', password: 'Secret123!'),
      );
      expect(result.isOk, isTrue);
      expect(container.read(sessionProvider), AxoSession.unlocked);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
    });

    test('con MFA pide el segundo paso y luego desbloquea', () async {
      final account = await _account();
      final user = _user(account.userId);
      final repo = FakeAuthRepository()
        ..preloginKdf = account.domainBundle.kdf
        ..currentUser = user
        ..loginOutcome = LoginMfaRequired(
          MfaChallenge(
            mfaToken: 'token',
            expiresAt: DateTime(2026, 1, 1, 0, 5),
          ),
        )
        ..mfaResult = LoginResult(
          user: user,
          expiresAt: DateTime(2026, 1, 1),
          keys: account.domainBundle,
        );
      final container = _container(repo: repo, prefs: FakeVaultPrefs());
      // Arranque ya resuelto (sin sesión): es el estado desde el que se llega al inicio de sesión.
      container.read(sessionProvider.notifier).set(AxoSession.noSession);
      final controller = container.read(authControllerProvider.notifier);

      final first = await controller.login(
        const LoginInput(email: 'persona@example.com', password: 'Secret123!'),
      );
      expect(first.isOk, isTrue);
      expect(container.read(authControllerProvider).mfaPending, isTrue);
      expect(container.read(sessionProvider), AxoSession.noSession);

      final second = await controller.verifyMfa('123456');
      expect(second.isOk, isTrue);
      expect(container.read(sessionProvider), AxoSession.unlocked);
      expect(container.read(authControllerProvider).mfaPending, isFalse);
    });

    test('credenciales incorrectas devuelven error sin abrir sesión', () async {
      final repo = FakeAuthRepository()
        ..preloginKdf = const KdfParams(
          alg: 'argon2id',
          memoryKiB: 1024,
          iterations: 1,
          parallelism: 1,
          salt: 'AAAAAAAAAAAAAAAAAAAAAA',
        )
        ..loginError = const UnauthorizedError(code: 'invalid-credentials');
      final container = _container(repo: repo, prefs: FakeVaultPrefs());
      container.read(sessionProvider.notifier).set(AxoSession.noSession);
      final controller = container.read(authControllerProvider.notifier);

      final result = await controller.login(
        const LoginInput(email: 'persona@example.com', password: 'mala'),
      );
      expect(result.isOk, isFalse);
      expect((result as Err).error, isA<UnauthorizedError>());
      expect(container.read(sessionProvider), AxoSession.noSession);
    });
  });

  group('desbloqueo', () {
    Future<ProviderContainer> loggedIn() async {
      final account = await _account();
      final repo = FakeAuthRepository()
        ..preloginKdf = account.domainBundle.kdf
        ..loginBundle = account.domainBundle
        ..keysBundle = account.domainBundle
        ..currentUser = _user(account.userId);
      final container = _container(repo: repo, prefs: FakeVaultPrefs());
      await container
          .read(authControllerProvider.notifier)
          .login(
            const LoginInput(
              email: 'persona@example.com',
              password: 'Secret123!',
            ),
          );
      return container;
    }

    test('contraseña correcta desbloquea', () async {
      final container = await loggedIn();
      container.read(vaultLockControllerProvider).lock();
      expect(container.read(sessionProvider), AxoSession.locked);

      final result = await container
          .read(authControllerProvider.notifier)
          .unlock('Secret123!');
      expect(result.isOk, isTrue);
      expect(container.read(sessionProvider), AxoSession.unlocked);
    });

    test('contraseña incorrecta marca el campo y suma el fallo', () async {
      final container = await loggedIn();
      container.read(vaultLockControllerProvider).lock();

      final result = await container
          .read(authControllerProvider.notifier)
          .unlock('mala');
      expect(result.isOk, isFalse);
      final state = container.read(authControllerProvider);
      expect(state.fieldErrors['password'], 'wrong-password');
      expect(state.unlockFailures, 1);
      expect(container.read(sessionProvider), AxoSession.locked);
    });

    test('tras 5 fallos cierra la sesión', () async {
      final container = await loggedIn();
      container.read(vaultLockControllerProvider).lock();
      final controller = container.read(authControllerProvider.notifier);
      for (var i = 0; i < 5; i++) {
        await controller.unlock('mala');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(container.read(sessionProvider), AxoSession.noSession);
    });
  });

  group('cierre de sesión y arranque', () {
    test('cerrar sesión limpia la copia local', () async {
      final account = await _account();
      final cleaner = FakeCleaner();
      final repo = FakeAuthRepository()
        ..preloginKdf = account.domainBundle.kdf
        ..loginBundle = account.domainBundle
        ..currentUser = _user(account.userId);
      final container = _container(
        repo: repo,
        prefs: FakeVaultPrefs(),
        cleaner: cleaner,
      );
      final controller = container.read(authControllerProvider.notifier);
      await controller.login(
        const LoginInput(email: 'persona@example.com', password: 'Secret123!'),
      );

      await controller.logout();
      expect(container.read(sessionProvider), AxoSession.noSession);
      expect(cleaner.wiped, [account.userId]);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.anonymous,
      );
    });

    test('device-revoked por el canal de eventos cierra y limpia', () async {
      final account = await _account();
      final cleaner = FakeCleaner();
      final repo = FakeAuthRepository()
        ..preloginKdf = account.domainBundle.kdf
        ..loginBundle = account.domainBundle
        ..currentUser = _user(account.userId);
      final container = _container(
        repo: repo,
        prefs: FakeVaultPrefs(),
        cleaner: cleaner,
      );
      await container
          .read(authControllerProvider.notifier)
          .login(
            const LoginInput(
              email: 'persona@example.com',
              password: 'Secret123!',
            ),
          );

      container.read(sessionEventBusProvider).emit(SessionEvent.deviceRevoked);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(sessionProvider), AxoSession.noSession);
      expect(cleaner.wiped, contains(account.userId));
      expect(
        container.read(authControllerProvider).notice,
        AuthNotice.deviceRevoked,
      );
    });

    test('arranque sin sesión guardada queda anónimo', () async {
      final container = _container(
        repo: FakeAuthRepository(),
        prefs: FakeVaultPrefs(),
      );
      await container.read(authControllerProvider.notifier).bootstrap();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.anonymous,
      );
    });

    test('arranque con clave recordada desbloquea sin contraseña', () async {
      final platform = FakeAxonotePlatform();
      await platform.storeMasterKey(
        userId: 'u1',
        bytes: Uint8List(32),
        requireAuth: false,
      );
      final prefs = FakeVaultPrefs()
        ..session = const CachedSession(
          userId: 'u1',
          email: 'persona@example.com',
        )
        ..settings['u1'] = const LockSettings(
          biometricLock: false,
          lockOnExit: false,
          lockTimeout: LockTimeout.never,
        );
      final repo = FakeAuthRepository()..currentUser = _user('u1');
      final container = _container(
        repo: repo,
        prefs: prefs,
        platform: platform,
      );

      await container.read(authControllerProvider.notifier).bootstrap();
      expect(container.read(sessionProvider), AxoSession.unlocked);
    });

    test('arranque con sesión vencida queda expirada', () async {
      final prefs = FakeVaultPrefs()
        ..session = const CachedSession(userId: 'u1', email: 'p@e.com');
      final repo = FakeAuthRepository()
        ..currentSessionError = const SessionExpiredError();
      final container = _container(repo: repo, prefs: prefs);

      await container.read(authControllerProvider.notifier).bootstrap();
      expect(container.read(authControllerProvider).status, AuthStatus.expired);
      expect(container.read(sessionProvider), AxoSession.noSession);
    });
  });

  group('restablecimiento', () {
    test(
      'solicitar el enlace guarda el correo y marca resetRequested',
      () async {
        final repo = FakeAuthRepository();
        final container = _container(repo: repo, prefs: FakeVaultPrefs());
        final result = await container
            .read(authControllerProvider.notifier)
            .forgotPassword('persona@example.com');
        expect(result.isOk, isTrue);
        final state = container.read(authControllerProvider);
        expect(state.resetRequested, isTrue);
        expect(state.resetEmail, 'persona@example.com');
        expect(repo.resetEmails, ['persona@example.com']);
      },
    );

    test('correo inválido no llama al servidor', () async {
      final repo = FakeAuthRepository();
      final container = _container(repo: repo, prefs: FakeVaultPrefs());
      final result = await container
          .read(authControllerProvider.notifier)
          .forgotPassword('no');
      expect(result.isOk, isFalse);
      expect(repo.resetEmails, isEmpty);
    });
  });
}
