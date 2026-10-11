import 'package:axonote_app/app/session.dart';
import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/router/app_router.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp.router(
    debugShowCheckedModeBanner: false,
    theme: AxoTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: container.read(routerProvider),
  ),
);

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('las guardas llevan a introducción, notas y desbloqueo', (
    tester,
  ) async {
    _phone(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();
    expect(
      find.text('Omitir'),
      findsWidgets,
      reason: 'sin sesión → introducción',
    );

    container.read(sessionProvider.notifier).set(AxoSession.unlocked);
    await tester.pumpAndSettle();
    expect(find.text('Notas'), findsWidgets, reason: 'desbloqueado → notas');

    container.read(sessionProvider.notifier).set(AxoSession.locked);
    await tester.pumpAndSettle();
    expect(
      find.text('Desbloquear'),
      findsWidgets,
      reason: 'bloqueado → desbloqueo',
    );
  });

  testWidgets('la galería de componentes (dev) es accesible sin sesión', (
    tester,
  ) async {
    _phone(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pumpAndSettle();

    container.read(routerProvider).go('/dev/components');
    await tester.pumpAndSettle();
    expect(find.text('Componentes (dev)'), findsWidgets);
  });
}
