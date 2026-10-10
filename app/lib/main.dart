import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/vault/ui/vault_activity_gate.dart';
import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ProviderScope(child: AxoNoteApp()));
}

/// Raíz de la app: tema claro/oscuro del diseño, localización `es` y navegación con guardas.
class AxoNoteApp extends ConsumerWidget {
  const AxoNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AxoTheme.light(),
      darkTheme: AxoTheme.dark(),
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          VaultActivityGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
