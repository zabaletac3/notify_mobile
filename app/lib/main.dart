import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'ui/theme.dart';

void main() {
  runApp(const ProviderScope(child: AxoNoteApp()));
}

/// Raíz de la app: tema claro/oscuro del diseño y navegación con guardas.
class AxoNoteApp extends ConsumerWidget {
  const AxoNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'AxoNote',
      debugShowCheckedModeBanner: false,
      theme: AxoTheme.light(),
      darkTheme: AxoTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
