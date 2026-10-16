import 'package:axonote_app/features/settings/ui/about_screen.dart';
import 'package:axonote_app/features/legal/ui/changelog_screen.dart';
import 'package:axonote_app/features/legal/ui/legal_document_screen.dart';
import 'package:axonote_app/features/legal/ui/support_screen.dart';
import 'package:axonote_app/features/settings/ui/account_screen.dart';
import 'package:axonote_app/features/settings/ui/delete_account_screen.dart';
import 'package:axonote_app/features/settings/ui/general_screen.dart';
import 'package:axonote_app/features/settings/ui/privacy_screen.dart';
import 'package:axonote_app/features/settings/ui/settings_menu_screen.dart';
import 'package:axonote_app/features/settings/ui/storage_screen.dart';
import 'package:axonote_app/features/settings/ui/sync_screen.dart';
import 'package:axonote_app/features/settings/ui/two_factor_screen.dart';
import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_harness.dart';

/// Carga la fuente Inter (empaquetada en `assets/fonts`) en las pruebas.
Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.otf'));
  }
  await loader.load();
}

Widget _app(
  ProviderContainer container,
  Widget child,
  ThemeData theme,
  Key key,
) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    key: key,
    debugShowCheckedModeBanner: false,
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(
        size: Size(412, 915),
        padding: EdgeInsets.only(top: 39, bottom: 26),
        viewPadding: EdgeInsets.only(top: 39, bottom: 26),
      ),
      child: child,
    ),
  ),
);

/// Goldens de las pantallas de Ajustes (tableros «Android — Ajustes…» de Pencil), en claro y oscuro.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadInter);

  final screens = <String, Widget Function()>{
    'menu': () => const SettingsMenuScreen(),
    'general': () => const GeneralScreen(),
    'cuenta': () => const AccountScreen(),
    'sync': () => const SyncScreen(),
    'privacidad': () => const PrivacyScreen(),
    'almacenamiento': () => const StorageScreen(),
    'eliminar-cuenta': () => const DeleteAccountScreen(),
    'acerca': () => const AboutScreen(),
    'verificacion': () => const TwoFactorSettingsScreen(),
    'terminos': () => LegalDocumentScreen(document: terms),
    'privacidad-legal': () => LegalDocumentScreen(document: privacy),
    'novedades': () => const ChangelogScreen(),
    'soporte': () => const SupportScreen(),
  };

  for (final entry in screens.entries) {
    for (final (mode, theme) in [
      ('claro', AxoTheme.light()),
      ('oscuro', AxoTheme.dark()),
    ]) {
      testWidgets('${entry.key} · $mode', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(412, 915);
        addTearDown(tester.view.reset);
        final container = settingsContainer();
        addTearDown(container.dispose);
        await tester.pumpWidget(
          _app(container, entry.value(), theme, ValueKey('${entry.key}-$mode')),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/settings-${entry.key}-$mode.png'),
        );
      });
    }
  }
}
