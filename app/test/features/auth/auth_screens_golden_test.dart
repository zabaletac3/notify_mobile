import 'package:axonote_app/bootstrap/providers.dart';
import 'package:axonote_app/features/auth/state/auth_controller.dart';
import 'package:axonote_app/features/auth/ui/forgot_password_screen.dart';
import 'package:axonote_app/features/auth/ui/forgot_password_sent_screen.dart';
import 'package:axonote_app/features/auth/ui/login_screen.dart';
import 'package:axonote_app/features/auth/ui/onboarding_screen.dart';
import 'package:axonote_app/features/auth/ui/register_screen.dart';
import 'package:axonote_app/features/auth/ui/server_error_screen.dart';
import 'package:axonote_app/features/auth/ui/two_factor_screen.dart';
import 'package:axonote_app/features/auth/ui/unlock_screen.dart';
import 'package:axonote_app/features/auth/ui/verify_screen.dart';
import 'package:axonote_app/features/auth/ui/welcome_screen.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/features/vault/state/timer_factory.dart';
import 'package:axonote_app/features/vault/state/vault_lock.dart';
import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/ui/components.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Carga la fuente Inter (empaquetada) para que los goldens de pantalla usen la tipografía real.
Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.otf'));
  }
  await loader.load();
}

ProviderContainer _container({
  required FakeAuthRepository repo,
  required FakeVaultPrefs prefs,
}) {
  AxonotePlatform.instance = FakeAxonotePlatform();
  final clock = FakeClock(DateTime(2026, 1, 1));
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      vaultPrefsProvider.overrideWithValue(prefs),
      argon2idProvider.overrideWithValue(FakeArgon2id()),
      deviceNameProvider.overrideWithValue('Test'),
      vaultActivityStoreProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(clock),
      vaultTimerFactoryProvider.overrideWithValue(FakeTimerFactory(clock)),
      localDataCleanerProvider.overrideWithValue(FakeCleaner()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _app(ProviderContainer container, Widget home, ThemeData theme) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

Future<void> _golden(
  WidgetTester tester,
  String name,
  Widget Function() home, {
  required ProviderContainer Function() make,
  Future<void> Function(ProviderContainer container)? seed,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);

  for (final (mode, theme) in [
    ('light', AxoTheme.light()),
    ('dark', AxoTheme.dark()),
  ]) {
    final container = make();
    if (seed != null) await seed(container);
    await tester.pumpWidget(_app(container, home(), theme));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/screens-$name-$mode.png'),
    );
  }
}

Future<({String userId, KeyBundle bundle, User user})> _account() async {
  final account = await crypto.createAccountKeys(
    password: 'Secret123!',
    userId: 'u1',
    argon2id: FakeArgon2id(),
    kdfBase: crypto.lightKdf,
  );
  final bundle = KeyBundle(
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
  );
  return (
    userId: account.userId,
    bundle: bundle,
    user: User(
      id: account.userId,
      email: 'persona@example.com',
      fullName: 'Persona',
      emailVerified: true,
      hasGoogle: false,
      createdAt: DateTime(2026, 1, 1),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadInter);

  testWidgets('bienvenida', (t) async {
    await _golden(
      t,
      'welcome',
      () => const WelcomeScreen(),
      make: () =>
          _container(repo: FakeAuthRepository(), prefs: FakeVaultPrefs()),
    );
  });

  testWidgets('introducción', (t) async {
    await _golden(
      t,
      'onboarding',
      () => const OnboardingScreen(),
      make: () =>
          _container(repo: FakeAuthRepository(), prefs: FakeVaultPrefs()),
    );
  });

  testWidgets('registro', (t) async {
    await _golden(
      t,
      'register',
      () => const RegisterScreen(),
      make: () =>
          _container(repo: FakeAuthRepository(), prefs: FakeVaultPrefs()),
    );
  });

  testWidgets('inicio de sesión', (t) async {
    await _golden(
      t,
      'login',
      () => const LoginScreen(),
      make: () =>
          _container(repo: FakeAuthRepository(), prefs: FakeVaultPrefs()),
    );
  });

  testWidgets('recuperar contraseña', (t) async {
    await _golden(
      t,
      'forgot-password',
      () => const ForgotPasswordScreen(),
      make: () =>
          _container(repo: FakeAuthRepository(), prefs: FakeVaultPrefs()),
    );
  });

  testWidgets('recuperar contraseña enviado', (t) async {
    await _golden(
      t,
      'forgot-password-sent',
      () => const ForgotPasswordSentScreen(),
      make: () =>
          _container(repo: FakeAuthRepository(), prefs: FakeVaultPrefs()),
      seed: (c) => c
          .read(authControllerProvider.notifier)
          .forgotPassword('persona@example.com'),
    );
  });

  testWidgets('verificación de correo', (t) async {
    await _golden(
      t,
      'verify',
      () => const VerifyScreen(),
      make: () =>
          _container(repo: FakeAuthRepository(), prefs: FakeVaultPrefs()),
      seed: (c) => c
          .read(authControllerProvider.notifier)
          .register(
            const RegisterInput(
              fullName: 'Persona',
              email: 'persona@example.com',
              password: 'Secret123!',
              acceptedTerms: true,
            ),
          ),
    );
  });

  testWidgets('segundo factor', (t) async {
    await _golden(
      t,
      'two-factor',
      () => const TwoFactorScreen(),
      make: () {
        final repo = FakeAuthRepository();
        return _container(repo: repo, prefs: FakeVaultPrefs());
      },
      seed: (c) async {
        final account = await _account();
        final repo = c.read(authRepositoryProvider) as FakeAuthRepository;
        repo
          ..preloginKdf = account.bundle.kdf
          ..currentUser = account.user
          ..loginOutcome = LoginMfaRequired(
            MfaChallenge(
              mfaToken: 'token',
              expiresAt: DateTime(2026, 1, 1, 0, 5),
            ),
          );
        await c
            .read(authControllerProvider.notifier)
            .login(
              const LoginInput(
                email: 'persona@example.com',
                password: 'Secret123!',
              ),
            );
      },
    );
  });

  testWidgets('desbloqueo', (t) async {
    await _golden(
      t,
      'unlock',
      () => const UnlockScreen(),
      make: () =>
          _container(repo: FakeAuthRepository(), prefs: FakeVaultPrefs()),
    );
  });

  testWidgets('error de servidor', (t) async {
    await _golden(
      t,
      'server-error',
      () => const ServerErrorScreen(code: 500),
      make: () =>
          _container(repo: FakeAuthRepository(), prefs: FakeVaultPrefs()),
    );
  });

  testWidgets('diálogo de sesión expirada', (t) async {
    await _golden(
      t,
      'session-expired',
      () => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: AxoDialog(
              icon: 'lock',
              title: 'Tu sesión expiró',
              content: Text(
                'Por seguridad cerramos tu sesión. Inicia sesión de nuevo para seguir sincronizando. Tus notas guardadas en este dispositivo siguen aquí.',
              ),
              actions: [
                AxoButton(
                  label: 'Seguir sin conexión',
                  variant: AxoButtonVariant.outline,
                  onPressed: _noop,
                ),
                AxoButton(label: 'Iniciar sesión', onPressed: _noop),
              ],
            ),
          ),
        ),
      ),
      make: () =>
          _container(repo: FakeAuthRepository(), prefs: FakeVaultPrefs()),
    );
  });
}

void _noop() {}
