import 'package:axonote_app/data/secure/account_secure_store.dart';
import 'package:axonote_app/data/secure/secure_store.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeSecureStore store;
  late AccountSecureStore account;

  setUp(() {
    store = FakeSecureStore();
    account = AccountSecureStore(store);
  });

  test('sin sesión guardada, todo lee null', () async {
    expect(await account.readUserId(), isNull);
    expect(await account.readEmail(), isNull);
    expect(await account.readAccessToken(), isNull);
    expect(await account.readRefreshToken(), isNull);
    expect(await account.readKeyBundleJson(), isNull);
  });

  test('saveSession guarda los cinco campos y se pueden releer', () async {
    await account.saveSession(
      const SessionData(
        userId: 'u1',
        email: 'persona@example.com',
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        keyBundleJson: '{"kdf":{}}',
      ),
    );
    expect(await account.readUserId(), 'u1');
    expect(await account.readEmail(), 'persona@example.com');
    expect(await account.readAccessToken(), 'access-1');
    expect(await account.readRefreshToken(), 'refresh-1');
    expect(await account.readKeyBundleJson(), '{"kdf":{}}');
  });

  test('updateTokens solo cambia los tokens', () async {
    await account.saveSession(
      const SessionData(
        userId: 'u1',
        email: 'persona@example.com',
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        keyBundleJson: '{}',
      ),
    );
    await account.updateTokens(
      accessToken: 'access-2',
      refreshToken: 'refresh-2',
    );
    expect(await account.readAccessToken(), 'access-2');
    expect(await account.readRefreshToken(), 'refresh-2');
    expect(await account.readUserId(), 'u1');
  });

  test('updateKeyBundleJson solo cambia el KeyBundle', () async {
    await account.saveSession(
      const SessionData(
        userId: 'u1',
        email: 'persona@example.com',
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        keyBundleJson: '{"keysVersion":1}',
      ),
    );
    await account.updateKeyBundleJson('{"keysVersion":2}');
    expect(await account.readKeyBundleJson(), '{"keysVersion":2}');
    expect(await account.readAccessToken(), 'access-1');
  });

  test(
    'clearSession borra la sesión pero no las preferencias de bloqueo',
    () async {
      await account.saveSession(
        const SessionData(
          userId: 'u1',
          email: 'persona@example.com',
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          keyBundleJson: '{}',
        ),
      );
      await account.writeLockSettings(
        'u1',
        const LockSettings(lockOnExit: true),
      );
      await account.clearSession();
      expect(await account.readUserId(), isNull);
      expect(await account.readAccessToken(), isNull);
      final prefs = await account.readLockSettings('u1');
      expect(prefs.lockOnExit, isTrue);
    },
  );

  test(
    'forgetAccount borra también las preferencias de bloqueo de esa cuenta',
    () async {
      await account.writeLockSettings(
        'u1',
        const LockSettings(lockOnExit: true),
      );
      await account.forgetAccount('u1');
      final prefs = await account.readLockSettings('u1');
      expect(prefs, const LockSettings());
    },
  );

  group('preferencias de bloqueo', () {
    test('sin nada guardado, da los valores por defecto', () async {
      expect(await account.readLockSettings('u1'), const LockSettings());
    });

    test(
      'writeLockSettings → readLockSettings conserva los tres campos',
      () async {
        const settings = LockSettings(
          biometricLock: false,
          lockOnExit: true,
          lockTimeout: LockTimeout.fiveMinutes,
        );
        await account.writeLockSettings('u1', settings);
        expect(await account.readLockSettings('u1'), settings);
      },
    );

    test('son por cuenta: no se mezclan entre userId distintos', () async {
      await account.writeLockSettings(
        'u1',
        const LockSettings(lockOnExit: true),
      );
      await account.writeLockSettings(
        'u2',
        const LockSettings(lockOnExit: false),
      );
      expect((await account.readLockSettings('u1')).lockOnExit, isTrue);
      expect((await account.readLockSettings('u2')).lockOnExit, isFalse);
    });

    test(
      'un valor guardado con otro formato se trata como si no hubiera nada',
      () async {
        await store.write('lockPrefs.u1', 'no es json');
        expect(await account.readLockSettings('u1'), const LockSettings());
      },
    );

    test('un campo con un tipo distinto del esperado también cae al valor por defecto', () async {
      await store.write('lockPrefs.u1', '{"biometricLock":"sí"}');
      expect(await account.readLockSettings('u1'), const LockSettings());
    });

    test('un lockTimeout desconocido cae al valor por defecto', () async {
      await store.write(
        'lockPrefs.u1',
        '{"biometricLock":true,"lockOnExit":false,"lockTimeout":"10m"}',
      );
      final prefs = await account.readLockSettings('u1');
      expect(prefs.lockTimeout, LockTimeout.oneMinute);
    });
  });
}
