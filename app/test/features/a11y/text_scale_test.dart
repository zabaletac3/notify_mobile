// Texto al 200 % (fase 12, plan §12.3): ninguna pantalla clave debe desbordar ni ocultar acciones
// con el escalado de texto del sistema al doble. Se monta cada pantalla en un marco de móvil y se
// comprueba que no hay desbordamiento (un `RenderFlex overflow` en pruebas se registra como
// excepción y `takeException` lo devuelve).
import 'package:axonote_app/features/notes/ui/notes_screen.dart';
import 'package:axonote_app/features/notes/ui/search_screen.dart';
import 'package:axonote_app/features/notes/ui/trash_screen.dart';
import 'package:axonote_app/features/settings/ui/about_screen.dart';
import 'package:axonote_app/features/settings/ui/account_screen.dart';
import 'package:axonote_app/features/settings/ui/general_screen.dart';
import 'package:axonote_app/features/settings/ui/privacy_screen.dart';
import 'package:axonote_app/features/settings/ui/settings_menu_screen.dart';
import 'package:axonote_app/features/settings/ui/storage_screen.dart';
import 'package:axonote_app/features/settings/ui/sync_screen.dart';
import 'package:axonote_app/features/settings/ui/two_factor_screen.dart';
import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../notes/support/notes_harness.dart';
import '../settings/support/settings_harness.dart';

Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.otf'));
  }
  await loader.load();
}

/// Envuelve [child] en el marco de móvil con el texto al 200 %.
Widget _app(ProviderContainer container, Widget child, Key key) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        key: key,
        debugShowCheckedModeBanner: false,
        theme: AxoTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(412, 915),
            padding: EdgeInsets.only(top: 39, bottom: 26),
            viewPadding: EdgeInsets.only(top: 39, bottom: 26),
            textScaler: TextScaler.linear(2),
          ),
          child: child,
        ),
      ),
    );

Future<void> _pumpNoOverflow(
  WidgetTester tester,
  ProviderContainer container,
  Widget child,
  String name,
) async {
  await tester.pumpWidget(_app(container, child, ValueKey(name)));
  // Unos cuadros, sin `pumpAndSettle` (algunos estados tienen animaciones continuas).
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(
    tester.takeException(),
    isNull,
    reason: '$name desborda con el texto al 200 %',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadInter);

  final notesScreens = <String, Widget Function(NotesHarness)>{
    'lista': (_) => const NotesScreen(),
    'búsqueda': (_) => const SearchScreen(),
    'papelera': (_) => const TrashScreen(),
  };

  notesScreens.forEach((name, home) {
    testWidgets('notas · $name · texto 200 %', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      final h = name == 'papelera'
          ? await buildTrashHarness()
          : await buildNotesHarness();
      await _pumpNoOverflow(tester, h.container, home(h), name);
    });
  });

  final settingsScreens = <String, Widget Function()>{
    'ajustes': () => const SettingsMenuScreen(),
    'general': () => const GeneralScreen(),
    'cuenta': () => const AccountScreen(),
    'privacidad': () => const PrivacyScreen(),
    'sincronización': () => const SyncScreen(),
    'almacenamiento': () => const StorageScreen(),
    'verificación': () => const TwoFactorSettingsScreen(),
    'acerca de': () => const AboutScreen(),
  };

  settingsScreens.forEach((name, home) {
    testWidgets('ajustes · $name · texto 200 %', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      final container = settingsContainer();
      addTearDown(container.dispose);
      await _pumpNoOverflow(tester, container, home(), name);
    });
  });
}
