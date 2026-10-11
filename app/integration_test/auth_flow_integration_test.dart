@Tags(<String>['integration'])
library;

import 'dart:io';

import 'package:axonote_app/app/session.dart';
import 'package:axonote_app/bootstrap/providers.dart';
import 'package:axonote_app/data/secure/secure_store.dart';
import 'package:axonote_app/features/auth/state/auth_controller.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/features/vault/state/timer_factory.dart';
import 'package:axonote_app/features/vault/state/vault_lock.dart';
import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/features/auth/support/fakes.dart';

/// Prueba de integración del ciclo de cuenta contra el backend local (plan §10, Fase 8).
/// **No corre en la suite normal** (tag `integration`; vive en `integration_test/`).
///
/// Preparación (el backend no se toca), como la fase 4:
///   1. En `notify_backend`: `make up-podman`, `make migrate` y `make run` con `MAIL_PROVIDER=log`.
///      Redirige la salida de errores del proceso a un fichero.
///   2. Exporta `AXONOTE_API_URL` (por defecto `http://localhost:8080/v1`) y `AXONOTE_MAIL_LOG`
///      (el fichero con el log donde se imprime el código).
///   3. `flutter test integration_test/auth_flow_integration_test.dart --tags integration`.
///
/// Hace: registro → verificación → clave de recuperación → cerrar sesión → inicio de sesión →
/// bloqueo → desbloqueo. Usa el cliente HTTP real y Argon2id ligero (parámetros del servidor).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final apiUrl = Platform.environment['AXONOTE_API_URL'];
  final mailLog = Platform.environment['AXONOTE_MAIL_LOG'];

  test(
    'registro → verificación → clave → cerrar sesión → login → bloqueo → desbloqueo',
    () async {
      final container = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(FakeSecureStore()),
          apiUrlProvider.overrideWithValue(
            (apiUrl == null || apiUrl.isEmpty)
                ? 'http://localhost:8080/v1'
                : apiUrl,
          ),
          deviceNameProvider.overrideWithValue('Integración'),
          argon2idProvider.overrideWithValue(FakeArgon2id()),
          kdfBaseProvider.overrideWithValue(crypto.lightKdf),
          vaultActivityStoreProvider.overrideWith(
            (ref) => ref.watch(secureVaultPrefsProvider),
          ),
          vaultTimerFactoryProvider.overrideWithValue(
            FakeTimerFactory(FakeClock()),
          ),
          localDataCleanerProvider.overrideWithValue(FakeCleaner()),
          clockProvider.overrideWithValue(FakeClock()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(authControllerProvider.notifier);
      final email = 'intg-${DateTime.now().microsecondsSinceEpoch}@example.com';
      const password = 'Secret123!';

      // 1. Registro.
      final registered = await controller.register(
        RegisterInput(
          fullName: 'Integración',
          email: email,
          password: password,
          acceptedTerms: true,
        ),
      );
      expect(registered.isOk, isTrue);

      // 2. Verificación con el código del log del backend.
      final code = await _waitForCode(mailLog!, email);
      final verified = await controller.verify(code);
      expect(verified.isOk, isTrue);
      expect(
        container.read(authControllerProvider).pendingRecoveryKey,
        isNotNull,
        reason: 'la clave de recuperación se muestra una vez',
      );
      expect(container.read(sessionProvider), AxoSession.unlocked);

      // 3. Cerrar sesión.
      await controller.logout();
      expect(container.read(sessionProvider), AxoSession.noSession);

      // 4. Iniciar sesión.
      final loggedIn = await controller.login(
        LoginInput(email: email, password: password),
      );
      expect(loggedIn.isOk, isTrue);
      expect(container.read(sessionProvider), AxoSession.unlocked);

      // 5. Bloquear y desbloquear con la contraseña.
      container.read(vaultLockControllerProvider).lock();
      expect(container.read(sessionProvider), AxoSession.locked);
      final unlocked = await controller.unlock(password);
      expect(unlocked.isOk, isTrue);
      expect(container.read(sessionProvider), AxoSession.unlocked);
    },
    timeout: const Timeout(Duration(minutes: 2)),
    skip: mailLog == null || mailLog.isEmpty
        ? 'Requiere AXONOTE_MAIL_LOG con la salida del backend'
        : null,
  );
}

/// Espera a que el log del backend contenga el código de verificación de [email].
Future<String> _waitForCode(String path, String email) async {
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(deadline)) {
    final file = File(path);
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      final at = content.indexOf('Para: $email');
      if (at >= 0) {
        final match = RegExp(r'código de verificación es (\d{6})')
            .firstMatch(content.substring(at));
        if (match != null) return match.group(1)!;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError('No se encontró el código de verificación para $email.');
}
