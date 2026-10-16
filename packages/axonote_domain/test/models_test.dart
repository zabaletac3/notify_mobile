// Cobertura de los tipos de datos del dominio (plan §11: `axonote_domain` ≥ 90 %): preferencias,
// bloqueo, uso de almacenamiento, resultado, entidades de cuenta/enlace, errores y auth.
import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

void main() {
  group('AppSettings', () {
    test('valores por defecto (iguales a DEFAULT_SETTINGS de la web)', () {
      const settings = AppSettings();
      expect(settings.theme, ThemePreference.system);
      expect(settings.textSize, TextSize.medium);
      expect(settings.noteOrder, NoteOrder.updated);
      expect(settings.openWithNewNote, isFalse);
      expect(settings.showPreview, isTrue);
      expect(settings.language, 'es');
    });

    test('copyWith cambia solo lo indicado', () {
      const base = AppSettings();
      final changed = base.copyWith(
        theme: ThemePreference.dark,
        textSize: TextSize.large,
        noteOrder: NoteOrder.title,
        openWithNewNote: true,
        showPreview: false,
        language: 'en',
      );
      expect(changed.theme, ThemePreference.dark);
      expect(changed.textSize, TextSize.large);
      expect(changed.noteOrder, NoteOrder.title);
      expect(changed.openWithNewNote, isTrue);
      expect(changed.showPreview, isFalse);
      expect(changed.language, 'en');
    });

    test('copyWith sin argumentos devuelve algo igual', () {
      const base = AppSettings();
      expect(base.copyWith(), base);
      expect(base.copyWith().hashCode, base.hashCode);
    });

    test('igualdad por valor', () {
      expect(const AppSettings(), const AppSettings());
      expect(
        const AppSettings(theme: ThemePreference.dark),
        isNot(const AppSettings()),
      );
    });

    test('enums: valor de cable', () {
      expect(ThemePreference.system.wire, 'system');
      expect(ThemePreference.light.wire, 'light');
      expect(ThemePreference.dark.wire, 'dark');
      expect(TextSize.small.wire, 'small');
      expect(TextSize.medium.wire, 'medium');
      expect(TextSize.large.wire, 'large');
      expect(NoteOrder.updated.wire, 'updated');
      expect(NoteOrder.created.wire, 'created');
      expect(NoteOrder.title.wire, 'title');
    });
  });

  group('LockSettings', () {
    test('copyWith cambia cada campo y hashCode/toString responden', () {
      const base = LockSettings();
      final changed = base.copyWith(
        biometricLock: false,
        lockOnExit: true,
        lockTimeout: LockTimeout.never,
      );
      expect(changed.biometricLock, isFalse);
      expect(changed.lockOnExit, isTrue);
      expect(changed.lockTimeout, LockTimeout.never);
      expect(changed.hashCode, isA<int>());
      expect(changed.toString(), contains('biometricLock: false'));
    });

    test('wire de LockTimeout', () {
      expect(LockTimeout.immediately.wire, 'immediately');
      expect(LockTimeout.oneMinute.wire, '1m');
      expect(LockTimeout.fiveMinutes.wire, '5m');
      expect(LockTimeout.fifteenMinutes.wire, '15m');
      expect(LockTimeout.never.wire, 'never');
    });
  });

  group('StorageUsage', () {
    test('availableBytes y percentUsed', () {
      const usage = StorageUsage(
        usedBytes: 250,
        quotaBytes: 1000,
        notesBytes: 200,
        imagesBytes: 40,
        trashBytes: 10,
      );
      expect(usage.availableBytes, 750);
      expect(usage.percentUsed, 0.25);
    });

    test('sin cuota', () {
      const usage = StorageUsage(
        usedBytes: 100,
        quotaBytes: 0,
        notesBytes: 0,
        imagesBytes: 0,
        trashBytes: 0,
      );
      expect(usage.percentUsed, 0);
    });

    test('uso por encima de la cuota se recorta a cero disponible', () {
      const usage = StorageUsage(
        usedBytes: 1500,
        quotaBytes: 1000,
        notesBytes: 0,
        imagesBytes: 0,
        trashBytes: 0,
      );
      expect(usage.availableBytes, 0);
      expect(usage.percentUsed, 1.5);
    });
  });

  group('Result', () {
    test('Ok lleva valor y responde isOk', () {
      const result = Ok<int>(7);
      expect(result.isOk, isTrue);
      expect(result.value, 7);
    });

    test('Err lleva error y no es Ok', () {
      const result = Err<int>(NetworkError());
      expect(result.isOk, isFalse);
      expect(result.error.kind, 'network');
    });
  });

  group('Cuenta y dispositivos', () {
    test('Device y DevicePlatform', () {
      final device = Device(
        id: 'd1',
        name: 'Pixel',
        platform: DevicePlatform.android,
        lastActiveAt: DateTime.utc(2026),
        current: true,
      );
      expect(device.id, 'd1');
      expect(device.current, isTrue);
      expect(DevicePlatform.linux.wire, 'linux');
      expect(DevicePlatform.windows.wire, 'windows');
      expect(DevicePlatform.web.wire, 'web');
    });

    test('User.copyWith conserva lo no indicado', () {
      final user = User(
        id: 'u1',
        email: 'a@b.c',
        fullName: 'Ana',
        emailVerified: true,
        hasGoogle: false,
        createdAt: DateTime.utc(2026),
      );
      final changed = user.copyWith(fullName: 'Ana P', hasGoogle: true);
      expect(changed.id, 'u1');
      expect(changed.email, 'a@b.c');
      expect(changed.fullName, 'Ana P');
      expect(changed.hasGoogle, isTrue);
      expect(changed.emailVerified, isTrue);
    });
  });

  group('Enlaces públicos', () {
    test('entidades del contrato', () {
      final at = DateTime.utc(2026);
      final link = ShareLink(
        id: 's',
        noteId: 'n',
        url: 'https://x/n/s#k=k',
        createdAt: at,
      );
      expect(link.url, contains('#k='));
      final shared = SharedNote(
        id: 's',
        noteId: 'n',
        slug: 'slug',
        wrappedShareKey: 'a1.x.y',
        payload: 'a1.x.y',
        createdAt: at,
        updatedAt: at,
      );
      expect(shared.slug, 'slug');
      const input = ShareInput(
        slug: 'slug',
        wrappedShareKey: 'k',
        payload: 'p',
      );
      expect(input.slug, 'slug');
      final public = PublicNote(payload: 'p', updatedAt: at);
      expect(public.payload, 'p');
      final content = SharedNoteContent(
        title: 't',
        content: 'c',
        updatedAt: at,
      );
      expect(content.title, 't');
    });
  });

  group('Errores', () {
    test('cada error expone su kind y AppFailure solo imprime el kind', () {
      expect(const NetworkError().kind, 'network');
      expect(const ServerError(status: 500).kind, 'server');
      expect(const UnauthorizedError().kind, 'unauthorized');
      expect(
        const ForbiddenError(code: ForbiddenCode.limitReached).kind,
        'forbidden',
      );
      expect(const SessionExpiredError().kind, 'session-expired');
      expect(const LockedError().kind, 'locked');
      expect(const DecryptError().kind, 'decrypt');
      expect(const DeviceRevokedError().kind, 'device-revoked');
      expect(const NotFoundError(entity: 'device').kind, 'not-found');
      expect(const ValidationError({'email': 'invalid'}).kind, 'validation');
      expect(const ConflictError().kind, 'conflict');
      expect(const RateLimitedError(retryAfterSec: 30).kind, 'rate-limited');
      expect(const UnknownError().kind, 'unknown');

      const failure = AppFailure(NetworkError());
      expect(failure.kind, 'network');
      expect(failure.toString(), 'AppFailure(network)');
      expect(failure.toString(), isNot(contains('http')));
    });

    test('ForbiddenCode: valor de cable', () {
      expect(ForbiddenCode.emailNotVerified.wire, 'email-not-verified');
      expect(ForbiddenCode.googleDisabled.wire, 'google-disabled');
      expect(
        ForbiddenCode.googleEmailUnverified.wire,
        'google-email-unverified',
      );
      expect(ForbiddenCode.accountDeleted.wire, 'account-deleted');
      expect(ForbiddenCode.googleNotLinked.wire, 'google-not-linked');
      expect(ForbiddenCode.limitReached.wire, 'limit-reached');
    });
  });

  group('MFA', () {
    test('isMfaCode acepta 6 dígitos o un código de respaldo', () {
      expect(isMfaCode('123456'), isTrue);
      expect(isMfaCode(' 123456 '), isTrue);
      expect(isMfaCode('ABCDE-23456'), isTrue);
      expect(isMfaCode('12345'), isFalse);
      expect(isMfaCode('ABCDE-1234'), isFalse);
      expect(isMfaCode('ABCDE_23456'), isFalse);
    });

    test('constantes de longitud', () {
      expect(verificationCodeLength, 6);
      expect(mfaCodeLength, 6);
      expect(mfaRecoveryCodeRegex.hasMatch('ABCDE-23456'), isTrue);
    });
  });
}
