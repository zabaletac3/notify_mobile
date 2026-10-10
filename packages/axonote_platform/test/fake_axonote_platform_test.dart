import 'dart:typed_data';

import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeAxonotePlatform platform;

  setUp(() => platform = FakeAxonotePlatform());

  test('guarda y carga sin requireAuth', () async {
    await platform.storeMasterKey(
      userId: 'u1',
      bytes: Uint8List.fromList([1, 2, 3]),
      requireAuth: false,
    );
    final loaded = await platform.loadMasterKey(userId: 'u1', prompt: 'x');
    expect(loaded, Uint8List.fromList([1, 2, 3]));
  });

  test('loadMasterKey sin storeMasterKey previo lanza NoStoredKey', () async {
    expect(
      () => platform.loadMasterKey(userId: 'ninguna', prompt: 'x'),
      throwsA(isA<NoStoredKey>()),
    );
  });

  test('deleteMasterKey borra lo guardado', () async {
    await platform.storeMasterKey(
      userId: 'u1',
      bytes: Uint8List.fromList([1]),
      requireAuth: false,
    );
    await platform.deleteMasterKey(userId: 'u1');
    expect(
      () => platform.loadMasterKey(userId: 'u1', prompt: 'x'),
      throwsA(isA<NoStoredKey>()),
    );
  });

  test('deleteMasterKey sin nada guardado no lanza', () async {
    await platform.deleteMasterKey(userId: 'nadie');
  });

  test('storeMasterKeyCallCount cuenta cada llamada, incluso si falla', () async {
    expect(platform.storeMasterKeyCallCount, 0);
    await platform.storeMasterKey(
      userId: 'u1',
      bytes: Uint8List.fromList([1]),
      requireAuth: false,
    );
    expect(platform.storeMasterKeyCallCount, 1);

    platform.nextAuthResult = const AuthCancelled();
    await expectLater(
      platform.storeMasterKey(
        userId: 'u1',
        bytes: Uint8List.fromList([2]),
        requireAuth: true,
      ),
      throwsA(isA<AuthCancelled>()),
    );
    expect(platform.storeMasterKeyCallCount, 2);
  });

  group('requireAuth: true', () {
    test('carga con éxito cuando no se fuerza ningún error', () async {
      await platform.storeMasterKey(
        userId: 'u1',
        bytes: Uint8List.fromList([5, 6]),
        requireAuth: true,
      );
      final loaded = await platform.loadMasterKey(
        userId: 'u1',
        prompt: 'Desbloquea',
      );
      expect(loaded, Uint8List.fromList([5, 6]));
    });

    test('nextAuthResult fuerza un AuthCancelled en el siguiente intento', () async {
      await platform.storeMasterKey(
        userId: 'u1',
        bytes: Uint8List.fromList([5]),
        requireAuth: true,
      );
      platform.nextAuthResult = const AuthCancelled();
      await expectLater(
        platform.loadMasterKey(userId: 'u1', prompt: 'x'),
        throwsA(isA<AuthCancelled>()),
      );
      // Se consume una sola vez: el siguiente intento ya no falla.
      final loaded = await platform.loadMasterKey(userId: 'u1', prompt: 'x');
      expect(loaded, Uint8List.fromList([5]));
    });

    test(
      'nextAuthResult fuerza AuthLockedOut (bloqueo temporal) en storeMasterKey',
      () async {
        platform.nextAuthResult = const AuthLockedOut(permanent: false);
        await expectLater(
          platform.storeMasterKey(
            userId: 'u1',
            bytes: Uint8List.fromList([1]),
            requireAuth: true,
          ),
          throwsA(
            isA<AuthLockedOut>().having((e) => e.permanent, 'permanent', isFalse),
          ),
        );
      },
    );

    test(
      'sin biometría ni credencial registrada, lanza AuthNotEnrolled',
      () async {
        platform.authAvailabilityValue = const AuthAvailability(
          biometricStrong: true,
          deviceCredential: false,
          enrolled: false,
        );
        await expectLater(
          platform.storeMasterKey(
            userId: 'u1',
            bytes: Uint8List.fromList([1]),
            requireAuth: true,
          ),
          throwsA(isA<AuthNotEnrolled>()),
        );
      },
    );

    test(
      'invalidateByEnrollment invalida una clave guardada con requireAuth '
      'y la borra (huella nueva, plan §5.2)',
      () async {
        await platform.storeMasterKey(
          userId: 'u1',
          bytes: Uint8List.fromList([7, 7, 7]),
          requireAuth: true,
        );
        platform.invalidateByEnrollment();
        await expectLater(
          platform.loadMasterKey(userId: 'u1', prompt: 'x'),
          throwsA(isA<KeyInvalidated>()),
        );
        // Tras invalidarse, se borró: un segundo intento ya no encuentra nada.
        await expectLater(
          platform.loadMasterKey(userId: 'u1', prompt: 'x'),
          throwsA(isA<NoStoredKey>()),
        );
      },
    );

    test(
      'invalidateByEnrollment no afecta a una clave guardada con requireAuth: false',
      () async {
        await platform.storeMasterKey(
          userId: 'u1',
          bytes: Uint8List.fromList([3]),
          requireAuth: false,
        );
        platform.invalidateByEnrollment();
        final loaded = await platform.loadMasterKey(userId: 'u1', prompt: 'x');
        expect(loaded, Uint8List.fromList([3]));
      },
    );
  });

  test('setSecure guarda el último valor pedido', () async {
    expect(platform.secure, isFalse);
    await platform.setSecure(true);
    expect(platform.secure, isTrue);
    await platform.setSecure(false);
    expect(platform.secure, isFalse);
  });

  test('copySensitive guarda el último texto copiado', () async {
    expect(platform.lastCopiedSensitive, isNull);
    await platform.copySensitive('AXON-0000-1111-2222');
    expect(platform.lastCopiedSensitive, 'AXON-0000-1111-2222');
  });

  test('authAvailability devuelve el valor configurado', () async {
    platform.authAvailabilityValue = const AuthAvailability(
      biometricStrong: false,
      deviceCredential: true,
      enrolled: true,
    );
    final result = await platform.authAvailability();
    expect(result.biometricStrong, isFalse);
    expect(result.deviceCredential, isTrue);
    expect(result.none, isFalse);
  });
}
