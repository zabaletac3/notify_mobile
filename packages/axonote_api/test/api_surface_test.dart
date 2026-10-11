import 'package:axonote_api/axonote_api.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'support/fake_dio.dart';

/// Ejercita **todos** los métodos de recurso del cliente (salvo los de Google y dispositivos de
/// confianza) contra un adaptador guionizado, comprobando método, ruta y decodificación. Es lo que
/// sostiene la cobertura del paquete.
void main() {
  late FakeAdapter adapter;
  late HttpClient client;
  late List<String> routes;

  setUp(() async {
    routes = <String>[];
    adapter = FakeAdapter((options) async {
      routes.add('${options.method} ${options.uri.path}');
      return _route(options);
    });
    client = HttpClient(
      HttpClientOptions(
        baseUrl: 'http://localhost:8080/v1',
        tokens: MemoryTokenStore(),
        dio: dioWith(adapter),
        cloudflareAccessId: 'cf-id',
        cloudflareAccessSecret: 'cf-secret',
      ),
    );
    await client.saveTokens(
      expiresAt: DateTime.utc(2026, 10, 10, 10, 15),
      accessToken: 'access',
      refreshToken: 'refresh',
    );
  });

  test('AuthApi cubre todas sus rutas', () async {
    final auth = AuthApi(client, deviceName: 'ZTE');
    expect((await auth.prelogin('persona@example.com')).alg, 'argon2id');
    expect(
      (await auth.register(_registerRequest())).email,
      'persona@example.com',
    );

    final user = await auth.verifyEmail('persona@example.com', '123456');
    expect(user.id, 'u_1');
    expect(await client.hasSession, isTrue);

    await auth.resendVerificationCode('persona@example.com');

    final login = await auth.login('persona@example.com', 'authkey');
    expect(login, isA<LoginSession>());
    expect((login as LoginSession).result.keys.keysVersion, 1);

    final challenge = await auth.loginMfa('mfatoken', '123456');
    expect(challenge.user.id, 'u_1');

    expect((await auth.currentSession())!.user.id, 'u_1');
    expect(
      (await auth.login('persona@example.com', 'authkey-mfa')),
      isA<LoginChallenge>(),
    );

    await auth.requestPasswordReset('persona@example.com');
    expect((await auth.passwordResetBundle('tok')).mfaEnabled, isFalse);
    await auth.resetPassword(
      PasswordResetRequestDto(
        token: 'tok',
        mode: PasswordResetMode.wipe,
        newAuthKey: 'n',
        recoveryAuth: 'r',
        keys: _keys(),
        mfaCode: '123456',
        disableMfa: true,
      ),
    );
    expect(await client.hasSession, isFalse);
    await auth.logout();

    expect(routes, contains('POST /v1/auth/prelogin'));
    expect(routes, contains('POST /v1/auth/verify-email'));
    expect(routes, contains('POST /v1/auth/login'));
    expect(routes, contains('POST /v1/auth/login/mfa'));
    expect(routes, contains('GET /v1/auth/session'));
    expect(routes, contains('POST /v1/auth/password/reset'));
  });

  test('AccountApi, KeysApi, DeviceApi, SettingsApi y StorageApi', () async {
    final account = AccountApi(client);
    final keys = KeysApi(client);
    final devices = DeviceApi(client);
    final settings = SettingsApi(client);
    final storage = StorageApi(client);

    expect((await account.me()).id, 'u_1');
    expect((await account.updateProfile('Otro')).fullName, 'Persona');
    expect(
      await account.requestEmailChange('nuevo@example.com', 'authkey'),
      'nuevo@example.com',
    );
    expect(
      (await account.confirmEmailChange('nuevo@example.com', '123456')).id,
      'u_1',
    );
    await account.changePassword(
      PasswordChangeRequestDto(
        currentAuthKey: 'a',
        newAuthKey: 'b',
        keys: _keys(),
      ),
    );

    expect((await keys.keys()).keysVersion, 1);
    await keys.rotateRecoveryKey(
      const RecoveryKeyRotationDto(
        authKey: 'a',
        recoveryAuth: 'r',
        recoveryWrappedMasterKey: 'a1.AAAAAAAAAAAAAAAA.AAAA',
      ),
    );

    expect((await devices.list()).single.current, isTrue);
    await devices.remove('d_1');

    expect((await settings.get()).theme, ThemePreference.system);
    expect(
      (await settings.update(
        const AppSettingsPatchDto(theme: ThemePreference.dark),
      )).theme,
      ThemePreference.system,
    );

    expect((await storage.usage()).quotaBytes, 1073741824);

    // Borra al final: limpia la sesión local.
    await account.deleteAccount('authkey');

    expect(routes, contains('GET /v1/me'));
    expect(routes, contains('PATCH /v1/me'));
    expect(routes, contains('DELETE /v1/devices/d_1'));
    expect(routes, contains('PATCH /v1/settings'));
    expect(routes, contains('GET /v1/storage/usage'));
  });

  test('MfaApi', () async {
    final mfa = MfaApi(client);
    expect((await mfa.status()).enabled, isFalse);
    expect((await mfa.setup('authkey')).secret, 'SECRETO');
    expect((await mfa.enable('123456')).recoveryCodes, hasLength(1));
    await mfa.disable('authkey', '123456');
    expect(
      (await mfa.regenerateCodes('authkey', '123456')).recoveryCodes,
      hasLength(1),
    );
    expect(routes, contains('GET /v1/mfa'));
    expect(routes, contains('POST /v1/mfa/totp/setup'));
  });

  test('NotesApi, FoldersApi y ShareApi', () async {
    final notes = NotesApi(client);
    final folders = FoldersApi(client);
    final share = ShareApi(client);

    final page = await notes.list();
    expect(page.items.single.id, 'n_1');
    expect(page.nextCursor, isNull);
    await notes.list(
      trashed: true,
      updatedSince: DateTime.utc(2026, 1, 1),
      cursor: 'c1',
      limit: 10,
    );
    expect((await notes.get('n_1')).revision, 1);

    expect((await folders.list()).single.id, 'f_1');

    expect((await share.createLink('n_1', _shareInput())).slug, 'slug');
    await share.updateLinkPayload('n_1', 'a1.AAAAAAAAAAAAAAAA.AAAA');
    expect((await share.getLink('n_1'))!.noteId, 'n_1');
    expect(await share.getLink('sin-enlace'), isNull);
    await share.revokeLink('n_1');
    expect((await share.readPublic('slug')).updatedAt.year, 2026);

    expect(routes, contains('GET /v1/notes'));
    expect(routes, contains('GET /v1/notes/n_1'));
    expect(routes, contains('GET /v1/folders'));
    expect(routes, contains('PUT /v1/notes/n_1/share'));
    expect(routes, contains('GET /v1/public/notes/slug'));
  });

  test('SyncApi', () async {
    final sync = SyncApi(client);
    final response = await sync.sync(
      const SyncRequestDto(
        deviceId: 'd_1',
        deviceName: 'ZTE',
        cursor: 'c1',
        changes: <SyncChangeDto>[
          SyncChangeDto(
            entity: SyncEntity.note,
            id: 'n_1',
            op: SyncOp.upsert,
            baseRevision: 1,
            data: <String, Object?>{'payload': 'a1.AAAAAAAAAAAAAAAA.AAAA'},
          ),
          SyncChangeDto(
            entity: SyncEntity.folder,
            id: 'f_1',
            op: SyncOp.delete,
            baseRevision: 0,
          ),
        ],
      ),
    );
    expect(response.cursor, 'c2');
    expect(routes, contains('POST /v1/sync'));
  });

  test('logout limpia la sesión, y no lanza si la petición falla', () async {
    final auth = AuthApi(client);
    await auth.logout();
    expect(await client.hasSession, isFalse);

    final adapter = FakeAdapter(
      (options) async => options.uri.path == '/v1/auth/logout'
          ? jsonResponse(500, <String, Object?>{'kind': 'server'})
          : jsonResponse(200, <String, Object?>{}),
    );
    final c = HttpClient(
      HttpClientOptions(
        baseUrl: 'http://localhost:8080/v1',
        tokens: MemoryTokenStore(),
        dio: dioWith(adapter),
      ),
    );
    await c.saveTokens(
      expiresAt: DateTime.utc(2026),
      accessToken: 'a',
      refreshToken: 'r',
    );
    await AuthApi(c).logout();
    expect(await c.hasSession, isFalse);
  });
}

ResponseBody _route(RequestOptions options) {
  final key = '${options.method} ${options.uri.path}';
  switch (key) {
    case 'POST /v1/auth/prelogin':
      return jsonResponse(200, <String, Object?>{'kdf': _kdf()});
    case 'POST /v1/auth/register':
      return jsonResponse(201, <String, Object?>{
        'email': 'persona@example.com',
      });
    case 'POST /v1/auth/verify-email':
      return jsonResponse(200, _session(conTokens: true));
    case 'POST /v1/auth/resend-code':
      return emptyResponse(204);
    case 'POST /v1/auth/login':
      final body = options.data as Map?;
      if (body?['authKey'] == 'authkey-mfa') {
        return jsonResponse(200, <String, Object?>{
          'mfaRequired': true,
          'mfaToken': 'mfatoken',
          'expiresAt': '2026-10-10T10:15:00.000Z',
        });
      }
      return jsonResponse(200, _loginResult());
    case 'POST /v1/auth/login/mfa':
      return jsonResponse(200, _loginResult());
    case 'POST /v1/auth/refresh':
      return jsonResponse(200, <String, Object?>{
        'accessToken': 'new',
        'refreshToken': 'new-r',
        'expiresAt': '2026-10-10T10:15:00.000Z',
      });
    case 'POST /v1/auth/logout':
      return emptyResponse(204);
    case 'GET /v1/auth/session':
      return jsonResponse(200, _session());
    case 'POST /v1/auth/password/forgot':
      return emptyResponse(202);
    case 'POST /v1/auth/password/reset/bundle':
      return jsonResponse(200, <String, Object?>{
        'userId': 'u_1',
        'recoveryWrappedMasterKey': 'a1.AAAAAAAAAAAAAAAA.AAAA',
        'kdf': _kdf(),
        'mfaEnabled': false,
      });
    case 'POST /v1/auth/password/reset':
    case 'POST /v1/me/password':
      return emptyResponse(204);
    case 'GET /v1/me':
    case 'PATCH /v1/me':
    case 'POST /v1/me/email-change/confirm':
      return jsonResponse(200, _user());
    case 'POST /v1/me/email-change':
      return jsonResponse(202, <String, Object?>{'email': 'nuevo@example.com'});
    case 'POST /v1/me/delete':
      return emptyResponse(202);
    case 'GET /v1/keys':
      return jsonResponse(200, _keysJson());
    case 'PUT /v1/keys/recovery':
      return emptyResponse(204);
    case 'GET /v1/devices':
      return jsonResponse(200, <Object?>[_device()]);
    case 'DELETE /v1/devices/d_1':
      return emptyResponse(204);
    case 'GET /v1/settings':
    case 'PATCH /v1/settings':
      return jsonResponse(200, _settings());
    case 'GET /v1/storage/usage':
      return jsonResponse(200, <String, Object?>{
        'usedBytes': 1,
        'quotaBytes': 1073741824,
        'notesBytes': 1,
        'imagesBytes': 0,
        'trashBytes': 0,
      });
    case 'GET /v1/mfa':
      return jsonResponse(200, <String, Object?>{
        'enabled': false,
        'enabledAt': null,
        'recoveryCodesLeft': 10,
      });
    case 'POST /v1/mfa/totp/setup':
      return jsonResponse(200, <String, Object?>{
        'secret': 'SECRETO',
        'otpauthUri': 'otpauth://totp/x',
      });
    case 'POST /v1/mfa/totp/enable':
    case 'POST /v1/mfa/recovery-codes':
      return jsonResponse(200, <String, Object?>{
        'recoveryCodes': <Object?>['ABCDE-12345'],
      });
    case 'POST /v1/mfa/totp/disable':
      return emptyResponse(204);
    case 'GET /v1/notes':
      return jsonResponse(200, <String, Object?>{
        'items': <Object?>[_note()],
        'nextCursor': null,
      });
    case 'GET /v1/notes/n_1':
      return jsonResponse(200, _note());
    case 'GET /v1/folders':
      return jsonResponse(200, <Object?>[_folder()]);
    case 'PUT /v1/notes/n_1/share':
    case 'GET /v1/notes/n_1/share':
      return jsonResponse(200, _sharedNote());
    case 'GET /v1/notes/sin-enlace/share':
      return jsonResponse(200, null);
    case 'PUT /v1/notes/n_1/share/payload':
    case 'DELETE /v1/notes/n_1/share':
      return emptyResponse(204);
    case 'GET /v1/public/notes/slug':
      return jsonResponse(200, <String, Object?>{
        'payload': 'a1.AAAAAAAAAAAAAAAA.AAAA',
        'updatedAt': '2026-10-10T10:00:00.000Z',
      });
    case 'POST /v1/sync':
      return jsonResponse(200, <String, Object?>{
        'cursor': 'c2',
        'hasMore': false,
        'applied': <Object?>[
          <String, Object?>{'entity': 'note', 'id': 'n_1', 'revision': 2},
        ],
        'remoteChanges': <Object?>[
          <String, Object?>{
            'entity': 'folder',
            'id': 'f_1',
            'deleted': false,
            'revision': 1,
            'folder': _folder(),
          },
          <String, Object?>{
            'entity': 'note',
            'id': 'n_2',
            'deleted': true,
            'revision': 3,
          },
        ],
        'conflicts': <Object?>[],
      });
    default:
      throw StateError('ruta no guionizada: $key');
  }
}

Map<String, Object?> _kdf() => <String, Object?>{
  'alg': 'argon2id',
  'memoryKiB': 1024,
  'iterations': 1,
  'parallelism': 1,
  'salt': 'AAAAAAAAAAAAAAAAAAAAAA',
};

Map<String, Object?> _keysJson() => <String, Object?>{
  'kdf': _kdf(),
  'wrappedMasterKey': 'a1.AAAAAAAAAAAAAAAA.AAAA',
  'recoveryWrappedMasterKey': 'a1.BBBBBBBBBBBBBBBB.BBBB',
  'keysVersion': 1,
};

KeyBundleDto _keys() => KeyBundleDto.fromJson(_keysJson());

Map<String, Object?> _user() => <String, Object?>{
  'id': 'u_1',
  'email': 'persona@example.com',
  'fullName': 'Persona',
  'emailVerified': true,
  'hasGoogle': false,
  'createdAt': '2026-10-10T10:00:00.000Z',
};

Map<String, Object?> _session({bool conTokens = false}) => <String, Object?>{
  'user': _user(),
  'expiresAt': '2026-10-10T10:15:00.000Z',
  if (conTokens) 'accessToken': 'access',
  if (conTokens) 'refreshToken': 'refresh',
};

Map<String, Object?> _loginResult() => <String, Object?>{
  'user': _user(),
  'expiresAt': '2026-10-10T10:15:00.000Z',
  'accessToken': 'access',
  'refreshToken': 'refresh',
  'keys': _keysJson(),
};

Map<String, Object?> _device() => <String, Object?>{
  'id': 'd_1',
  'name': 'ZTE',
  'platform': 'android',
  'lastActiveAt': '2026-10-10T10:00:00.000Z',
  'current': true,
};

Map<String, Object?> _settings() => <String, Object?>{
  'theme': 'system',
  'textSize': 'medium',
  'noteOrder': 'updated',
  'openWithNewNote': false,
  'showPreview': true,
  'language': 'es',
  'autoSync': true,
  'wifiOnly': false,
  'biometricLock': true,
  'lockOnExit': false,
  'lockTimeout': '1m',
  'twoFactor': false,
};

Map<String, Object?> _note() => <String, Object?>{
  'id': 'n_1',
  'folderId': null,
  'createdAt': '2026-10-10T10:00:00.000Z',
  'updatedAt': '2026-10-10T10:00:00.000Z',
  'deletedAt': null,
  'revision': 1,
  'lastEditedDeviceId': 'd_1',
  'wrappedKey': 'a1.AAAAAAAAAAAAAAAA.AAAA',
  'payload': 'a1.BBBBBBBBBBBBBBBB.BBBB',
};

Map<String, Object?> _folder() => <String, Object?>{
  'id': 'f_1',
  'createdAt': '2026-10-10T10:00:00.000Z',
  'updatedAt': '2026-10-10T10:00:00.000Z',
  'revision': 1,
  'wrappedKey': 'a1.AAAAAAAAAAAAAAAA.AAAA',
  'payload': 'a1.BBBBBBBBBBBBBBBB.BBBB',
};

Map<String, Object?> _sharedNote() => <String, Object?>{
  'id': 's_1',
  'noteId': 'n_1',
  'slug': 'slug',
  'wrappedShareKey': 'a1.AAAAAAAAAAAAAAAA.AAAA',
  'payload': 'a1.BBBBBBBBBBBBBBBB.BBBB',
  'createdAt': '2026-10-10T10:00:00.000Z',
  'updatedAt': '2026-10-10T10:00:00.000Z',
};

ShareInputDto _shareInput() => const ShareInputDto(
  slug: 'slug',
  wrappedShareKey: 'a1.AAAAAAAAAAAAAAAA.AAAA',
  payload: 'a1.BBBBBBBBBBBBBBBB.BBBB',
);

RegisterRequestDto _registerRequest() => RegisterRequestDto(
  userId: 'u_1',
  fullName: 'Persona',
  email: 'persona@example.com',
  acceptedTerms: true,
  authKey: 'authkey',
  recoveryAuth: 'recovery',
  keys: _keys(),
);
