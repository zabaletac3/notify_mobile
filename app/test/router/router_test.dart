import 'package:axonote_app/app/session.dart';
import 'package:axonote_app/router/app_router.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('las guardas llevan a bienvenida, notas y desbloqueo', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AxoTheme.light(),
          routerConfig: container.read(routerProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Bienvenida'),
      findsWidgets,
      reason: 'sin sesión → bienvenida',
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
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AxoTheme.light(),
          routerConfig: container.read(routerProvider),
        ),
      ),
    );
    await tester.pumpAndSettle();

    container.read(routerProvider).go('/dev/components');
    await tester.pumpAndSettle();
    expect(find.text('Componentes (dev)'), findsWidgets);
  });
}
