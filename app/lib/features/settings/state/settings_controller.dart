import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';

/// Tema de Material a partir de la preferencia (`system`/`light`/`dark`).
ThemeMode themeModeOf(ThemePreference preference) => switch (preference) {
  ThemePreference.system => ThemeMode.system,
  ThemePreference.light => ThemeMode.light,
  ThemePreference.dark => ThemeMode.dark,
};

/// Factor de escala del texto a partir del tamaño (`small`/`medium`/`large`). `medium` es 1,0.
double textScaleOf(TextSize size) => switch (size) {
  TextSize.small => 0.9,
  TextSize.medium => 1.0,
  TextSize.large => 1.15,
};

/// Preferencias locales de la app (tema, tamaño, orden, vista previa). Se cargan en el arranque en
/// frío y se persisten por cuenta en el almacén seguro (no se sincronizan, igual que la web).
class SettingsController extends Notifier<AppSettings> {
  String? _userId;

  @override
  AppSettings build() => const AppSettings();

  /// Lee las preferencias de la cuenta con sesión (si la hay) al arrancar.
  Future<void> load() async {
    final userId = (await ref.read(vaultPrefsProvider).cachedSession())?.userId;
    _userId = userId;
    state = userId == null
        ? const AppSettings()
        : await ref.read(vaultPrefsProvider).readAppSettings(userId);
  }

  /// Cambia las preferencias y las persiste para la cuenta con sesión.
  Future<void> update(AppSettings next) async {
    state = next;
    final userId =
        _userId ?? (await ref.read(vaultPrefsProvider).cachedSession())?.userId;
    if (userId != null) {
      await ref.read(vaultPrefsProvider).writeAppSettings(userId, next);
    }
  }
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
