import 'dart:typed_data';

import 'package:axonote_app/bootstrap/providers.dart';
import 'package:axonote_app/features/auth/state/auth_controller.dart';
import 'package:axonote_app/features/auth/ui/splash_screen.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/features/vault/state/vault_lock.dart';
import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/router/app_router.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

/// Arranque en frío (plan §5.3): con la sesión restaurada desde el almacén seguro, la app debe
/// llevar a `/unlock` (o `/notes` si el bloqueo no vencía), y sin sesión a la introducción solo la
/// primera vez; nunca debe quedarse en el onboarding teniendo cuenta. Regresión del fallo del ZTE.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('con sesión guardada va al desbloqueo', (tester) async {
    final prefs = FakeVaultPrefs()
      ..session = const CachedSession(userId: 'u1', email: 'p@e.com');
    final repo = FakeAuthRepository()..currentUser = _user();
    final container = _container(prefs: prefs, repo: repo);

    _phone(tester);
    await tester.pumpWidget(_app(container));
    // Mientras se lee el almacén seguro se ve el arranque, no onboarding ni desbloqueo.
    expect(find.byType(SplashScreen), findsOneWidget);

    await container.read(authControllerProvider.notifier).bootstrap();
    await tester.pumpAndSettle();

    expect(_loc(container), '/unlock');
  });

  testWidgets('sin red pero con sesión guardada va al desbloqueo', (
    tester,
  ) async {
    final prefs = FakeVaultPrefs()
      ..session = const CachedSession(userId: 'u1', email: 'p@e.com');
    final repo = FakeAuthRepository()
      ..currentSessionError = const NetworkError();
    final container = _container(prefs: prefs, repo: repo);

    await _start(tester, container);
    expect(_loc(container), '/unlock');
    expect(_loc(container), isNot('/onboarding'));
  });

  testWidgets('sin sesión la primera vez va a la introducción', (tester) async {
    final container = _container(
      prefs: FakeVaultPrefs(),
      repo: FakeAuthRepository(),
    );
    await _start(tester, container);
    expect(_loc(container), '/onboarding');
  });

  testWidgets('sin sesión con la introducción ya vista va a la bienvenida', (
    tester,
  ) async {
    final prefs = FakeVaultPrefs()..onboardingSeen = true;
    final container = _container(prefs: prefs, repo: FakeAuthRepository());
    await _start(tester, container);
    expect(_loc(container), '/welcome');
  });

  testWidgets('tras desbloquear va a las notas', (tester) async {
    final prefs = FakeVaultPrefs()
      ..session = const CachedSession(userId: 'u1', email: 'p@e.com')
      ..settings['u1'] = const LockSettings(
        biometricLock: false,
        lockOnExit: false,
        lockTimeout: LockTimeout.never,
      );
    final repo = FakeAuthRepository()..currentUser = _user();
    final container = _container(prefs: prefs, repo: repo);

    await _start(tester, container);
    expect(_loc(container), '/unlock');

    await container
        .read(vaultLockControllerProvider)
        .unlock(userId: 'u1', masterKey: crypto.SecretKeyBytes(Uint8List(32)));
    await tester.pumpAndSettle();

    expect(_loc(container), '/notes');
  });
}

User _user() => User(
  id: 'u1',
  email: 'persona@example.com',
  fullName: 'Persona',
  emailVerified: true,
  hasGoogle: false,
  createdAt: DateTime(2026, 1, 1),
);

ProviderContainer _container({
  required FakeVaultPrefs prefs,
  required FakeAuthRepository repo,
  FakeAxonotePlatform? platform,
}) {
  AxonotePlatform.instance = platform ?? FakeAxonotePlatform();
  final container = ProviderContainer(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
      vaultPrefsProvider.overrideWithValue(prefs),
      argon2idProvider.overrideWithValue(FakeArgon2id()),
      deviceNameProvider.overrideWithValue('Test'),
      vaultActivityStoreProvider.overrideWithValue(prefs),
      clockProvider.overrideWithValue(FakeClock(DateTime(2026, 1, 1))),
      localDataCleanerProvider.overrideWithValue(FakeCleaner()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AxoTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: container.read(routerProvider),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
}

Future<void> _start(WidgetTester tester, ProviderContainer container) async {
  _phone(tester);
  await tester.pumpWidget(_app(container));
  await container.read(authControllerProvider.notifier).bootstrap();
  await tester.pumpAndSettle();
}

String _loc(ProviderContainer container) => container
    .read(routerProvider)
    .routerDelegate
    .currentConfiguration
    .last
    .matchedLocation;
