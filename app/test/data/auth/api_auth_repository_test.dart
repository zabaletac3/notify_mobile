// Pruebas de `ApiAuthRepository` (capa de datos) con un dio guionizado: cubre el mapeo de cada
// operación del contrato y el canal de eventos de sesión, sin red real (plan §4.2 y §11).
import 'package:axonote_api/axonote_api.dart';
import 'package:axonote_app/data/auth/api_auth_repository.dart';
import 'package:axonote_app/data/auth/session_events.dart';
import 'package:axonote_app/data/secure/account_secure_store.dart';
import 'package:axonote_app/data/secure/secure_store.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../remote/fake_dio.dart';

const _now = '2026-01-02T03:04:05.000Z';

Map<String, Object?> _kdfJson() => const {
  'alg': 'argon2id',
  'memoryKiB': 65536,
  'iterations': 3,
  'parallelism': 1,
  'salt': 'c2FsdHNhbHRzYWx0c2FsdA',
};

Map<String, Object?> _keysJson() => {
  'kdf': _kdfJson(),
  'wrappedMasterKey': 'a1.iv.ct',
  'recoveryWrappedMasterKey': 'a1.iv.ct2',
  'keysVersion': 1,
};

Map<String, Object?> _userJson({String email = 'a@b.c'}) => {
  'id': 'u1',
  'email': email,
  'fullName': 'Ana',
  'emailVerified': true,
  'hasGoogle': false,
  'createdAt': _now,
};

const _sealed = 'a1.aaaaaaaaaaaaaaaa.bbbb';

KeyBundle _keyBundle() => const KeyBundle(
  kdf: KdfParams(
    alg: 'argon2id',
    memoryKiB: 65536,
    iterations: 3,
    parallelism: 1,
    salt: 'c2FsdHNhbHRzYWx0c2FsdA',
  ),
  wrappedMasterKey: _sealed,
  recoveryWrappedMasterKey: _sealed,
  keysVersion: 1,
);

class _Harness {
  _Harness(this.repo, this.adapter, this.account, this.events);

  final ApiAuthRepository repo;
  final FakeAdapter adapter;
  final AccountSecureStore account;
  final SessionEventBus events;
}

Future<_Harness> _build(
  Future<ResponseBody> Function(RequestOptions options) handler,
) async {
  final adapter = FakeAdapter(handler);
  final tokens = MemoryTokenStore();
  // Sesión ya iniciada: las rutas de cuenta exigen token (AuthMode por defecto). El token no
  // vence para que no se intente renovar.
  await tokens.write(
    const StoredTokens(
      accessToken: 'at',
      refreshToken: 'rt',
      expiresAt: '2099-01-01T00:00:00.000Z',
    ),
  );
  final http = HttpClient(
    HttpClientOptions(
      baseUrl: 'http://localhost:8080/v1',
      tokens: tokens,
      dio: dioWith(adapter),
    ),
  );
  final account = AccountSecureStore(FakeSecureStore());
  final events = SessionEventBus();
  final repo = ApiAuthRepository(
    http: http,
    account: account,
    events: events,
    deviceName: 'Test',
  );
  return _Harness(repo, adapter, account, events);
}

void main() {
  test('prelogin devuelve los parámetros del KDF', () async {
    final h = await _build((o) async => jsonResponse(200, {'kdf': _kdfJson()}));
    final kdf = await h.repo.prelogin('a@b.c');
    expect(kdf.alg, 'argon2id');
    expect(kdf.memoryKiB, 65536);
    expect(h.adapter.requests.single.path, endsWith('/auth/prelogin'));
  });

  test('register devuelve el correo', () async {
    final h = await _build((o) async => jsonResponse(200, {'email': 'a@b.c'}));
    final result = await h.repo.register(
      RegisterRequest(
        userId: 'u1',
        fullName: 'Ana',
        email: 'a@b.c',
        acceptedTerms: true,
        authKey: 'auth',
        recoveryAuth: 'rec',
        keys: _keyBundle(),
      ),
    );
    expect(result.email, 'a@b.c');
    expect(h.adapter.requests.single.path, endsWith('/auth/register'));
  });

  test('verifyEmail guarda la sesión y devuelve el usuario', () async {
    final h = await _build(
      (o) async => jsonResponse(200, {
        'user': _userJson(),
        'expiresAt': _now,
        'accessToken': 'at',
        'refreshToken': 'rt',
      }),
    );
    final user = await h.repo.verifyEmail(
      email: 'a@b.c',
      code: '123456',
      keys: _keyBundle(),
    );
    expect(user.id, 'u1');
    expect(await h.account.readUserId(), 'u1');
    expect(await h.account.readKeyBundleJson(), isNotNull);
  });

  test('resendVerificationCode no falla', () async {
    final h = await _build((o) async => jsonResponse(204, null));
    await h.repo.resendVerificationCode('a@b.c');
    expect(h.adapter.requests.single.path, endsWith('/auth/resend-code'));
  });

  test(
    'login con sesión guarda los tokens y devuelve LoginSucceeded',
    () async {
      final h = await _build(
        (o) async => jsonResponse(200, {
          'user': _userJson(),
          'expiresAt': _now,
          'keys': _keysJson(),
          'accessToken': 'at',
          'refreshToken': 'rt',
        }),
      );
      final outcome = await h.repo.login(email: 'a@b.c', authKey: 'auth');
      expect(outcome, isA<LoginSucceeded>());
      expect(await h.account.readUserId(), 'u1');
    },
  );

  test('login con segundo factor devuelve LoginMfaRequired', () async {
    final h = await _build(
      (o) async => jsonResponse(200, {
        'mfaRequired': true,
        'mfaToken': 'tok',
        'expiresAt': _now,
      }),
    );
    final outcome = await h.repo.login(email: 'a@b.c', authKey: 'auth');
    expect(outcome, isA<LoginMfaRequired>());
    expect((outcome as LoginMfaRequired).challenge.mfaToken, 'tok');
  });

  test('loginMfa completa la sesión', () async {
    final h = await _build(
      (o) async => jsonResponse(200, {
        'user': _userJson(),
        'expiresAt': _now,
        'keys': _keysJson(),
        'accessToken': 'at',
        'refreshToken': 'rt',
      }),
    );
    final result = await h.repo.loginMfa(mfaToken: 'tok', code: '123456');
    expect(result.user.id, 'u1');
    expect(await h.account.readUserId(), 'u1');
  });

  test('logout limpia la sesión local', () async {
    final h = await _build((o) async {
      if (o.path.endsWith('/auth/login')) {
        return jsonResponse(200, {
          'user': _userJson(),
          'expiresAt': _now,
          'keys': _keysJson(),
          'accessToken': 'at',
          'refreshToken': 'rt',
        });
      }
      return jsonResponse(204, null);
    });
    await h.repo.login(email: 'a@b.c', authKey: 'auth');
    expect(await h.account.readUserId(), 'u1');
    await h.repo.logout();
    expect(await h.account.readUserId(), isNull);
  });

  test('currentSession devuelve el usuario de la sesión vigente', () async {
    final h = await _build(
      (o) async => jsonResponse(200, {'user': _userJson(), 'expiresAt': _now}),
    );
    final user = await h.repo.currentSession();
    expect(user?.id, 'u1');
  });

  test('keyBundle consulta al servidor y luego usa la caché', () async {
    var calls = 0;
    final h = await _build((o) async {
      calls++;
      return jsonResponse(200, _keysJson());
    });
    final first = await h.repo.keyBundle();
    final second = await h.repo.keyBundle();
    expect(first.keysVersion, 1);
    expect(second.keysVersion, 1);
    expect(calls, 1); // la segunda sale de la caché
  });

  test('requestPasswordReset no falla', () async {
    final h = await _build((o) async => jsonResponse(204, null));
    await h.repo.requestPasswordReset('a@b.c');
    expect(h.adapter.requests.single.path, endsWith('/auth/password/forgot'));
  });

  test('updateProfile devuelve el usuario actualizado', () async {
    final h = await _build((o) async => jsonResponse(200, _userJson()));
    final user = await h.repo.updateProfile('Ana P');
    expect(user.id, 'u1');
    expect(h.adapter.requests.single.method, 'PATCH');
  });

  test('requestEmailChange devuelve el correo pendiente', () async {
    final h = await _build(
      (o) async => jsonResponse(200, {'email': 'nuevo@b.c'}),
    );
    final email = await h.repo.requestEmailChange(
      newEmail: 'nuevo@b.c',
      authKey: 'auth',
    );
    expect(email, 'nuevo@b.c');
  });

  test('confirmEmailChange actualiza el correo de la sesión', () async {
    final h = await _build((o) async {
      if (o.path.endsWith('/auth/login')) {
        return jsonResponse(200, {
          'user': _userJson(),
          'expiresAt': _now,
          'keys': _keysJson(),
          'accessToken': 'at',
          'refreshToken': 'rt',
        });
      }
      return jsonResponse(200, _userJson(email: 'nuevo@b.c'));
    });
    await h.repo.login(email: 'a@b.c', authKey: 'auth');
    final user = await h.repo.confirmEmailChange(
      email: 'nuevo@b.c',
      code: '123456',
    );
    expect(user.email, 'nuevo@b.c');
    expect(await h.account.readEmail(), 'nuevo@b.c');
  });

  test('changePassword actualiza el KeyBundle en caché', () async {
    final h = await _build((o) async => jsonResponse(204, null));
    await h.repo.changePassword(
      currentAuthKey: 'old',
      newAuthKey: 'new',
      keys: _keyBundle(),
    );
    expect(await h.account.readKeyBundleJson(), isNotNull);
  });

  test('deleteAccount no falla', () async {
    final h = await _build((o) async => jsonResponse(204, null));
    await h.repo.deleteAccount('auth');
    expect(h.adapter.requests.single.path, endsWith('/me/delete'));
  });

  test('MFA: estado, setup, enable, disable y regenerar', () async {
    final h = await _build((o) async {
      final p = o.path;
      if (p.endsWith('/mfa')) {
        return jsonResponse(200, {
          'enabled': true,
          'enabledAt': _now,
          'recoveryCodesLeft': 8,
        });
      }
      if (p.endsWith('/mfa/totp/setup')) {
        return jsonResponse(200, {
          'secret': 'SECRET',
          'otpauthUri': 'otpauth://totp/x',
        });
      }
      if (p.endsWith('/mfa/totp/enable') || p.endsWith('/mfa/recovery-codes')) {
        return jsonResponse(200, {
          'recoveryCodes': ['ABCDE-23456', 'FGHIJ-67890'],
        });
      }
      return jsonResponse(204, null); // disable
    });
    expect((await h.repo.mfaStatus()).enabled, isTrue);
    expect((await h.repo.mfaSetup('auth')).secret, 'SECRET');
    expect((await h.repo.mfaEnable('123456')), hasLength(2));
    await h.repo.mfaDisable(authKey: 'auth', code: '123456');
    expect(
      await h.repo.mfaRegenerateCodes(authKey: 'auth', code: '123456'),
      hasLength(2),
    );
  });

  test('rotateRecoveryKey no falla', () async {
    final h = await _build((o) async => jsonResponse(204, null));
    await h.repo.rotateRecoveryKey(
      authKey: 'auth',
      recoveryAuth: 'rec',
      recoveryWrappedMasterKey: _sealed,
    );
    expect(h.adapter.requests.single.method, 'PUT');
  });

  test('un device-revoked limpia la sesión y publica el evento', () async {
    final h = await _build((o) async {
      if (o.path.endsWith('/auth/login')) {
        return jsonResponse(200, {
          'user': _userJson(),
          'expiresAt': _now,
          'keys': _keysJson(),
          'accessToken': 'at',
          'refreshToken': 'rt',
        });
      }
      return jsonResponse(401, {'kind': 'device-revoked'});
    });
    await h.repo.login(email: 'a@b.c', authKey: 'auth');
    final event = h.events.stream.first;
    await expectLater(h.repo.prelogin('a@b.c'), throwsA(isA<AppFailure>()));
    expect(await event, SessionEvent.deviceRevoked);
    expect(await h.account.readUserId(), isNull);
  });
}
