import 'package:axonote_api/axonote_api.dart';
import 'package:test/test.dart';

void expectFormatError(void Function() action) {
  expect(action, throwsA(isA<JsonFormatException>()));
}

Map<String, Object?> userJson() => <String, Object?>{
  'id': 'u_1',
  'email': 'persona@example.com',
  'fullName': 'Persona',
  'emailVerified': true,
  'hasGoogle': false,
  'createdAt': '2026-10-10T10:00:00.000Z',
};

Map<String, Object?> kdfJson() => <String, Object?>{
  'alg': 'argon2id',
  'memoryKiB': 1024,
  'iterations': 1,
  'parallelism': 1,
  'salt': 'AAAAAAAAAAAAAAAAAAAAAA',
};

Map<String, Object?> keysJson() => <String, Object?>{
  'kdf': kdfJson(),
  'wrappedMasterKey': 'a1.AAAAAAAAAAAAAAAA.AAAA',
  'recoveryWrappedMasterKey': 'a1.BBBBBBBBBBBBBBBB.BBBB',
  'keysVersion': 1,
};

void main() {
  group('fromJson estricto', () {
    test('UserDto válido', () {
      final user = UserDto.fromJson(userJson());
      expect(user.id, 'u_1');
      expect(user.emailVerified, isTrue);
      expect(user.createdAt.toUtc().year, 2026);
    });

    test('campo ausente es fallo de formato', () {
      final json = userJson()..remove('email');
      expectFormatError(() => UserDto.fromJson(json));
    });

    test('tipo equivocado es fallo de formato', () {
      expectFormatError(
        () => UserDto.fromJson(userJson()..['emailVerified'] = 'sí'),
      );
      expectFormatError(
        () => UserDto.fromJson(userJson()..['createdAt'] = 123),
      );
      expectFormatError(
        () => UserDto.fromJson(userJson()..['createdAt'] = 'no-es-fecha'),
      );
    });

    test('una raíz que no es objeto es fallo de formato', () {
      expectFormatError(() => UserDto.fromJson('texto'));
      expectFormatError(() => UserDto.fromJson(<Object?>[]));
    });

    test('KeyBundleDto anida kdf y exige todos sus campos', () {
      expect(KeyBundleDto.fromJson(keysJson()).keysVersion, 1);
      final roto = keysJson();
      (roto['kdf']! as Map<String, Object?>).remove('salt');
      expectFormatError(() => KeyBundleDto.fromJson(roto));
    });

    test('SessionDto admite tokens ausentes y null explícito', () {
      final session = SessionDto.fromJson(<String, Object?>{
        'user': userJson(),
        'expiresAt': '2026-10-10T10:15:00.000Z',
      });
      expect(session.accessToken, isNull);
      expect(session.refreshToken, isNull);
      final conNull = SessionDto.fromJson(<String, Object?>{
        'user': userJson(),
        'expiresAt': '2026-10-10T10:15:00.000Z',
        'accessToken': null,
        'refreshToken': null,
      });
      expect(conNull.accessToken, isNull);
    });

    test('LoginResultDto exige keys', () {
      expectFormatError(
        () => LoginResultDto.fromJson(<String, Object?>{
          'user': userJson(),
          'expiresAt': '2026-10-10T10:15:00.000Z',
        }),
      );
    });

    test('AppSettingsDto valida las enumeraciones', () {
      final settings = AppSettingsDto.fromJson(appSettingsJson());
      expect(settings.theme, ThemePreference.system);
      expect(settings.lockTimeout, LockTimeout.oneMinute);
      expectFormatError(
        () =>
            AppSettingsDto.fromJson(appSettingsJson()..['theme'] = 'arcoiris'),
      );
      expectFormatError(
        () =>
            AppSettingsDto.fromJson(appSettingsJson()..['lockTimeout'] = '2m'),
      );
    });

    test('MfaRecoveryCodesDto exige una lista de cadenas', () {
      final codes = MfaRecoveryCodesDto.fromJson(<String, Object?>{
        'recoveryCodes': <Object?>['ABCDE-12345'],
      });
      expect(codes.recoveryCodes, <String>['ABCDE-12345']);
      expectFormatError(
        () => MfaRecoveryCodesDto.fromJson(<String, Object?>{
          'recoveryCodes': <Object?>[123],
        }),
      );
    });

    test('SyncResponseDto con arrays y cambios remotos', () {
      final response = SyncResponseDto.fromJson(<String, Object?>{
        'cursor': 'c1',
        'hasMore': false,
        'applied': <Object?>[
          <String, Object?>{'entity': 'note', 'id': 'n_1', 'revision': 2},
        ],
        'remoteChanges': <Object?>[
          <String, Object?>{
            'entity': 'folder',
            'id': 'f_1',
            'deleted': true,
            'revision': 3,
          },
          <String, Object?>{
            'entity': 'note',
            'id': 'n_2',
            'deleted': false,
            'revision': 4,
            'note': noteJson(),
          },
        ],
        'conflicts': <Object?>[
          <String, Object?>{
            'noteId': 'n_2',
            'remote': noteJson(),
            'remoteDeviceName': 'Chrome',
          },
        ],
      });
      expect(response.cursor, 'c1');
      expect(response.hasMore, isFalse);
      expect(response.applied.single.revision, 2);
      expect(response.remoteChanges.first.deleted, isTrue);
      expect(response.remoteChanges.last.note!.id, 'n_2');
      expect(response.conflicts.single.noteId, 'n_2');
    });

    test('un sync con campos de más no falla, pero uno mal tipado sí', () {
      expectFormatError(
        () => SyncResponseDto.fromJson(<String, Object?>{
          'cursor': 'c1',
          'applied': 'no-es-array',
          'remoteChanges': <Object?>[],
          'conflicts': <Object?>[],
        }),
      );
    });

    test('los campos anulables aceptan valores no nulos', () {
      final note = EncryptedNoteDto.fromJson(<String, Object?>{
        ...noteJson(),
        'folderId': 'f_1',
        'deletedAt': '2026-10-11T10:00:00.000Z',
      });
      expect(note.folderId, 'f_1');
      expect(note.deletedAt!.day, 11);

      final status = MfaStatusDto.fromJson(<String, Object?>{
        'enabled': true,
        'enabledAt': '2026-10-10T10:00:00.000Z',
        'recoveryCodesLeft': 8,
      });
      expect(status.enabledAt!.year, 2026);
    });

    test('AppSettingsPatchDto sabe si está vacío', () {
      expect(const AppSettingsPatchDto().isEmpty, isTrue);
      expect(const AppSettingsPatchDto(autoSync: true).isEmpty, isFalse);
    });
  });

  group('toJson', () {
    test('LoginInputDto incluye el dispositivo si se da', () {
      final json = const LoginInputDto(
        email: 'persona@example.com',
        authKey: 'key',
        device: DeviceInfoDto(name: 'ZTE', platform: DevicePlatform.android),
      ).toJson();
      expect(json['device'], <String, Object?>{
        'name': 'ZTE',
        'platform': 'android',
      });
    });

    test('AppSettingsPatchDto omite los campos nulos', () {
      final json = const AppSettingsPatchDto(theme: ThemePreference.dark)
          .toJson();
      expect(json, <String, Object?>{'theme': 'dark'});
    });

    test('SyncRequestDto conserva el cursor null', () {
      final json = const SyncRequestDto(
        deviceId: 'd_1',
        deviceName: 'ZTE',
        changes: <SyncChangeDto>[],
      ).toJson();
      expect(json.containsKey('cursor'), isTrue);
      expect(json['cursor'], isNull);
    });
  });
}

Map<String, Object?> appSettingsJson() => <String, Object?>{
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

Map<String, Object?> noteJson() => <String, Object?>{
  'id': 'n_2',
  'folderId': null,
  'createdAt': '2026-10-10T10:00:00.000Z',
  'updatedAt': '2026-10-10T10:00:00.000Z',
  'deletedAt': null,
  'revision': 1,
  'lastEditedDeviceId': 'd_1',
  'wrappedKey': 'a1.AAAAAAAAAAAAAAAA.AAAA',
  'payload': 'a1.BBBBBBBBBBBBBBBB.BBBB',
};
