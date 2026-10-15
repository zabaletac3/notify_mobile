import 'package:axonote_app/features/settings/ui/account_screen.dart';
import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/settings_harness.dart';

/// Goldens de los diálogos de «Mi cuenta» (cambio de nombre, correo y contraseña; sin tablero en
/// «Movil v2»), en claro y oscuro.
Future<void> _loadInter() async {
  final loader = FontLoader('Inter');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$weight.otf'));
  }
  await loader.load();
}

Widget _app(ProviderContainer container, ThemeData theme, Key key) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        key: key,
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MediaQuery(
          data: MediaQueryData(
            size: Size(412, 915),
            padding: EdgeInsets.only(top: 39, bottom: 26),
            viewPadding: EdgeInsets.only(top: 39, bottom: 26),
          ),
          child: AccountScreen(),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadInter);

  final dialogs = <String, String>{
    'dialogo-nombre': 'Nombre',
    'dialogo-correo': 'Correo electrónico',
    'dialogo-contrasena': 'Cambiar',
  };

  for (final entry in dialogs.entries) {
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
          _app(container, theme, ValueKey('${entry.key}-$mode')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(entry.value));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/settings-${entry.key}-$mode.png'),
        );
      });
    }
  }
}
