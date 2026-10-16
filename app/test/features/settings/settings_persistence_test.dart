import 'package:axonote_app/bootstrap/providers.dart';
import 'package:axonote_app/features/settings/state/lock_settings_controller.dart';
import 'package:axonote_app/features/settings/state/settings_controller.dart';
import 'package:axonote_app/features/vault/state/vault_lock.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/support/fakes.dart';

/// Persistencia y efecto de los ajustes de Generales y Privacidad (fase 11.2b): el tema y el
/// tamaño se aplican de verdad, el bloqueo se persiste y se aplica, y el arranque en frío los
/// respeta.
void main() {
  test('tema: cada preferencia mapea a su ThemeMode', () {
    expect(themeModeOf(ThemePreference.system), ThemeMode.system);
    expect(themeModeOf(ThemePreference.light), ThemeMode.light);
    expect(themeModeOf(ThemePreference.dark), ThemeMode.dark);
  });

  test('tamaño de letra: medium es 1,0 y small/large lo rodean', () {
    expect(textScaleOf(TextSize.medium), 1.0);
    expect(textScaleOf(TextSize.small), lessThan(1.0));
    expect(textScaleOf(TextSize.large), greaterThan(1.0));
  });

  test(
    'arranque en frío: las preferencias se cargan y al cambiarlas se persisten',
    () async {
      final prefs = FakeVaultPrefs()
        ..session = const CachedSession(userId: 'u1', email: 'p@e.com')
        ..appSettings = const AppSettings(
          theme: ThemePreference.dark,
          noteOrder: NoteOrder.title,
        );
      final container = ProviderContainer(
        overrides: [vaultPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container.read(settingsProvider.notifier).load();
      expect(container.read(settingsProvider).theme, ThemePreference.dark);
      expect(container.read(settingsProvider).noteOrder, NoteOrder.title);

      await container
          .read(settingsProvider.notifier)
          .update(
            container.read(settingsProvider).copyWith(showPreview: false),
          );
      expect(prefs.appSettings.showPreview, isFalse);
      expect(prefs.appSettings.theme, ThemePreference.dark);
    },
  );

  test(
    'bloqueo: arranque en frío lo carga y al cambiarlo se persiste y se aplica',
    () async {
      AxonotePlatform.instance = FakeAxonotePlatform();
      final prefs = FakeVaultPrefs()
        ..session = const CachedSession(userId: 'u1', email: 'p@e.com')
        ..settings['u1'] = const LockSettings(
          biometricLock: false,
          lockOnExit: true,
          lockTimeout: LockTimeout.fiveMinutes,
        );
      final container = ProviderContainer(
        overrides: [vaultPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final loaded = await container.read(lockSettingsProvider.future);
      expect(loaded.biometricLock, isFalse);
      expect(loaded.lockOnExit, isTrue);
      expect(loaded.lockTimeout, LockTimeout.fiveMinutes);

      const next = LockSettings(
        biometricLock: true,
        lockOnExit: false,
        lockTimeout: LockTimeout.never,
      );
      await container.read(lockSettingsProvider.notifier).save(next);
      expect(prefs.settings['u1'], next);
      expect(container.read(vaultLockControllerProvider).settings, next);
    },
  );
}
