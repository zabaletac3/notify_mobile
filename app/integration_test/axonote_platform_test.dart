// Pruebas instrumentadas de `axonote_platform` sobre el canal real (plan §5.2, «Hecho cuando» de
// la Fase 5). Se ejecutan en un dispositivo Android de verdad, nunca en el analizador de escritorio
// (necesitan Keystore y, en varias, el sensor de huella real).
//
// Cómo correrlas, ver la guía paso a paso: docs/guides/fase5-pruebas-manuales.md
//
//   flutter test integration_test/axonote_platform_test.dart -d <deviceId>
//
// Las que piden tocar el sensor (o registrar una huella nueva) están marcadas con `skip` por
// defecto para no colgarse esperando a una persona en una tanda automática; se activan con:
//
//   flutter test integration_test/axonote_platform_test.dart -d <deviceId> \
//     --dart-define=AXONOTE_MANUAL_BIOMETRIC_TESTS=true
import 'dart:typed_data';

import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// `true` solo cuando alguien pasó `--dart-define=AXONOTE_MANUAL_BIOMETRIC_TESTS=true` al
/// ejecutar: entonces sí se corren las pruebas que necesitan tocar el sensor (el motivo de por
/// qué están excluidas por defecto está en la cabecera de este fichero).
const _runManual = bool.fromEnvironment('AXONOTE_MANUAL_BIOMETRIC_TESTS');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelAxonotePlatform();

  // userId de prueba por caso: evita que una prueba deje una clave de Keystore que afecte a la
  // siguiente si algo falla a medio camino.
  Future<void> cleanUp(String userId) => platform.deleteMasterKey(userId: userId);

  group('sin requireAuth (automatizable, no toca el sensor)', () {
    const userId = 'fase5-sin-auth';

    tearDown(() => cleanUp(userId));

    testWidgets('guardar y cargar devuelve los mismos 32 bytes', (tester) async {
      final bytes = Uint8List.fromList(List.generate(32, (i) => i));
      await platform.storeMasterKey(
        userId: userId,
        bytes: bytes,
        requireAuth: false,
      );
      final loaded = await platform.loadMasterKey(
        userId: userId,
        prompt: 'no debería mostrarse',
      );
      expect(loaded, bytes);
    });

    testWidgets('borrar hace que cargar lance NoStoredKey', (tester) async {
      await platform.storeMasterKey(
        userId: userId,
        bytes: Uint8List(32),
        requireAuth: false,
      );
      await platform.deleteMasterKey(userId: userId);
      await expectLater(
        platform.loadMasterKey(userId: userId, prompt: 'x'),
        throwsA(isA<NoStoredKey>()),
      );
    });

    testWidgets('cargar sin haber guardado nunca lanza NoStoredKey', (tester) async {
      await expectLater(
        platform.loadMasterKey(userId: 'fase5-nunca-guardada', prompt: 'x'),
        throwsA(isA<NoStoredKey>()),
      );
    });

    testWidgets(
      'guardar dos veces sustituye la clave anterior (no quedan dos)',
      (tester) async {
        await platform.storeMasterKey(
          userId: userId,
          bytes: Uint8List.fromList(List.filled(32, 1)),
          requireAuth: false,
        );
        await platform.storeMasterKey(
          userId: userId,
          bytes: Uint8List.fromList(List.filled(32, 2)),
          requireAuth: false,
        );
        final loaded = await platform.loadMasterKey(userId: userId, prompt: 'x');
        expect(loaded, Uint8List.fromList(List.filled(32, 2)));
      },
    );
  });

  group('authAvailability y endurecimiento (automatizable)', () {
    testWidgets('authAvailability responde con una forma coherente', (tester) async {
      final result = await platform.authAvailability();
      // No se afirma nada sobre el hardware concreto del dispositivo (varía): solo que la
      // respuesta tiene sentido entre sí.
      if (result.enrolled) {
        expect(result.biometricStrong || result.deviceCredential, isTrue);
      }
    });

    testWidgets('setSecure no lanza (activar y desactivar FLAG_SECURE)', (
      tester,
    ) async {
      await platform.setSecure(true);
      await platform.setSecure(false);
    });

    testWidgets('copySensitive no lanza', (tester) async {
      await platform.copySensitive('texto de prueba, no es secreto real');
    });
  });

  group('con requireAuth: true (pide tocar el sensor — PASO A PASO 1 de la guía)', () {
    const userId = 'fase5-con-auth';

    tearDown(() => cleanUp(userId));

    testWidgets(
      'guardar pide biometría; al autenticar, cargar luego también la pide y '
      'devuelve los mismos bytes',
      (tester) async {
        final bytes = Uint8List.fromList(List.generate(32, (i) => 31 - i));
        await platform.storeMasterKey(
          userId: userId,
          bytes: bytes,
          requireAuth: true,
          prompt: 'Prueba Fase 5: confirma tu huella para guardar',
        );
        final loaded = await platform.loadMasterKey(
          userId: userId,
          prompt: 'Prueba Fase 5: confirma tu huella para cargar',
        );
        expect(loaded, bytes);
      },
      skip: !_runManual,
    );
  });

  group('cancelar la biometría (PASO A PASO 2 de la guía)', () {
    const userId = 'fase5-cancelar';

    tearDown(() => cleanUp(userId));

    testWidgets(
      'cancelar el cuadro de biometría (botón atrás o "Cancelar") lanza AuthCancelled',
      (tester) async {
        await platform.storeMasterKey(
          userId: userId,
          bytes: Uint8List(32),
          requireAuth: true,
          prompt: 'Prueba Fase 5: confirma tu huella para guardar',
        );
        await expectLater(
          platform.loadMasterKey(
            userId: userId,
            prompt: 'Prueba Fase 5: TOCA "CANCELAR" O EL BOTÓN ATRÁS AHORA',
          ),
          throwsA(isA<AuthCancelled>()),
        );
      },
      skip: !_runManual,
    );
  });

  group(
    'invalidación por huella nueva (PASO A PASO 3 de la guía — la más larga)',
    () {
      const userId = 'fase5-invalidada';

      tearDown(() => cleanUp(userId));

      testWidgets(
        'registrar una biometría nueva invalida la clave guardada: cargar '
        'lanza KeyInvalidated y ya no queda nada guardado',
        (tester) async {
          await platform.storeMasterKey(
            userId: userId,
            bytes: Uint8List(32),
            requireAuth: true,
            prompt: 'Prueba Fase 5: confirma tu huella para guardar',
          );
          // Entre el storeMasterKey de arriba y el loadMasterKey de abajo, la persona debe salir
          // de la app y registrar una huella nueva en Ajustes del sistema (ver la guía). La
          // prueba se queda esperando en el cuadro de biometría hasta que vuelva a abrir AxoNote.
          await expectLater(
            platform.loadMasterKey(
              userId: userId,
              prompt: 'Prueba Fase 5: huella nueva ya registrada',
            ),
            throwsA(isA<KeyInvalidated>()),
          );
          await expectLater(
            platform.loadMasterKey(userId: userId, prompt: 'x'),
            throwsA(isA<NoStoredKey>()),
          );
        },
        skip: !_runManual,
      );
    },
  );

  group(
    'cancelar al re-guardar conserva la clave anterior intacta '
    '(PASO A PASO 4 de la guía — atomicidad)',
    () {
      const userId = 'fase5-atomico';

      tearDown(() => cleanUp(userId));

      testWidgets(
        'guardar con auth y cancelar un segundo guardado no deja la cuenta '
        'inservible: la clave anterior sigue intacta',
        (tester) async {
          final original = Uint8List.fromList(List.generate(32, (i) => i));
          await platform.storeMasterKey(
            userId: userId,
            bytes: original,
            requireAuth: true,
            prompt: 'Prueba Fase 5 (atomicidad): confirma tu huella para guardar la ORIGINAL',
          );
          // Segundo intento de guardar (p. ej. al cambiar de contraseña): cancélalo.
          await expectLater(
            platform.storeMasterKey(
              userId: userId,
              bytes: Uint8List.fromList(List.filled(32, 9)),
              requireAuth: true,
              prompt:
                  'Prueba Fase 5 (atomicidad): TOCA "CANCELAR" O EL BOTÓN ATRÁS AHORA '
                  '(NO pongas el dedo)',
            ),
            throwsA(isA<AuthCancelled>()),
          );
          // La cuenta sigue teniendo la clave ORIGINAL, no `no_stored_key` ni un fallo genérico.
          final loaded = await platform.loadMasterKey(
            userId: userId,
            prompt: 'Prueba Fase 5 (atomicidad): confirma tu huella para cargar',
          );
          expect(loaded, original);
        },
        skip: !_runManual,
      );
    },
  );
}
