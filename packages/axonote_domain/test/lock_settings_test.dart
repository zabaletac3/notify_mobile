import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

void main() {
  group('LockSettings', () {
    test('valores por defecto (iguales a DEFAULT_SETTINGS de la web)', () {
      const settings = LockSettings();
      expect(settings.biometricLock, isTrue);
      expect(settings.lockOnExit, isFalse);
      expect(settings.lockTimeout, LockTimeout.oneMinute);
    });

    test('copyWith solo cambia lo indicado', () {
      const settings = LockSettings();
      final changed = settings.copyWith(lockTimeout: LockTimeout.never);
      expect(changed.lockTimeout, LockTimeout.never);
      expect(changed.biometricLock, settings.biometricLock);
      expect(changed.lockOnExit, settings.lockOnExit);
    });

    test('igualdad por valor', () {
      expect(const LockSettings(), const LockSettings());
      expect(const LockSettings(lockOnExit: true), isNot(const LockSettings()));
    });
  });

  group('LockTimeoutDuration', () {
    test('immediately y never no dependen de un tiempo', () {
      expect(LockTimeout.immediately.after, isNull);
      expect(LockTimeout.never.after, isNull);
    });

    test('los demás miden el tiempo documentado en el plan', () {
      expect(LockTimeout.oneMinute.after, const Duration(minutes: 1));
      expect(LockTimeout.fiveMinutes.after, const Duration(minutes: 5));
      expect(LockTimeout.fifteenMinutes.after, const Duration(minutes: 15));
    });
  });
}
