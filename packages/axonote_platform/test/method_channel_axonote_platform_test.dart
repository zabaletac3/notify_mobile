import 'dart:typed_data';

import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('axonote_platform');
  late MethodChannelAxonotePlatform platform;
  final log = <MethodCall>[];

  void respondWith(Object? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          log.add(call);
          return handler(call);
        });
  }

  setUp(() {
    log.clear();
    platform = MethodChannelAxonotePlatform(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('storeMasterKey', () {
    test('envía userId, bytes, requireAuth y prompt', () async {
      respondWith((_) => null);
      await platform.storeMasterKey(
        userId: 'u1',
        bytes: Uint8List.fromList([1, 2, 3]),
        requireAuth: true,
        prompt: 'Confirma tu identidad',
      );
      expect(log, hasLength(1));
      expect(log.single.method, 'storeMasterKey');
      expect(log.single.arguments, {
        'userId': 'u1',
        'bytes': Uint8List.fromList([1, 2, 3]),
        'requireAuth': true,
        'prompt': 'Confirma tu identidad',
      });
    });
  });

  group('loadMasterKey', () {
    test('devuelve los bytes que entrega el canal', () async {
      respondWith((_) => Uint8List.fromList([9, 8, 7]));
      final result = await platform.loadMasterKey(
        userId: 'u1',
        prompt: 'Desbloquea AxoNote',
      );
      expect(result, Uint8List.fromList([9, 8, 7]));
    });
  });

  group('authAvailability', () {
    test('traduce el mapa del canal', () async {
      respondWith(
        (_) => {
          'biometricStrong': true,
          'deviceCredential': false,
          'enrolled': true,
        },
      );
      final result = await platform.authAvailability();
      expect(result.biometricStrong, isTrue);
      expect(result.deviceCredential, isFalse);
      expect(result.enrolled, isTrue);
    });
  });

  group('setSecure', () {
    test('envía el valor pedido', () async {
      respondWith((_) => null);
      await platform.setSecure(true);
      expect(log.single.method, 'setSecure');
      expect(log.single.arguments, {'secure': true});
    });
  });

  group('copySensitive', () {
    test('envía el texto a copiar', () async {
      respondWith((_) => null);
      await platform.copySensitive('clave-de-recuperación');
      expect(log.single.method, 'copySensitive');
      expect(log.single.arguments, {'text': 'clave-de-recuperación'});
    });
  });

  group('mapeo de errores', () {
    Future<void> throwsMapped(String code, Matcher matcher) async {
      respondWith(
        (_) => throw PlatformException(code: code, message: 'detalle nativo'),
      );
      await expectLater(
        platform.loadMasterKey(userId: 'u1', prompt: 'x'),
        throwsA(matcher),
      );
    }

    test('auth_cancelled → AuthCancelled', () async {
      await throwsMapped('auth_cancelled', isA<AuthCancelled>());
    });

    test('auth_not_enrolled → AuthNotEnrolled', () async {
      await throwsMapped('auth_not_enrolled', isA<AuthNotEnrolled>());
    });

    test('key_invalidated → KeyInvalidated', () async {
      await throwsMapped('key_invalidated', isA<KeyInvalidated>());
    });

    test('auth_locked_out → AuthLockedOut(permanent: false)', () async {
      await throwsMapped(
        'auth_locked_out',
        isA<AuthLockedOut>().having((e) => e.permanent, 'permanent', isFalse),
      );
    });

    test(
      'auth_locked_out_permanent → AuthLockedOut(permanent: true)',
      () async {
        await throwsMapped(
          'auth_locked_out_permanent',
          isA<AuthLockedOut>().having((e) => e.permanent, 'permanent', isTrue),
        );
      },
    );

    test('no_stored_key → NoStoredKey', () async {
      await throwsMapped('no_stored_key', isA<NoStoredKey>());
    });

    test('un código desconocido se trata como fallo genérico', () async {
      respondWith(
        (_) => throw PlatformException(
          code: 'algo_no_previsto',
          message: 'no debe verse en AxonotePlatformFailure.message',
        ),
      );
      try {
        await platform.loadMasterKey(userId: 'u1', prompt: 'x');
        fail('debía lanzar');
      } on AxonotePlatformFailure catch (e) {
        // El mensaje nativo nunca se expone tal cual: solo el código.
        expect(e.message, 'algo_no_previsto');
        expect(e.message, isNot(contains('no debe verse')));
      }
    });
  });
}
