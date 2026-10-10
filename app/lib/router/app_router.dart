import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/session.dart';
import '../dev/components_gallery.dart';
import '../ui/components.dart';
import '../ui/placeholder_screen.dart';
import '../ui/tokens.dart';

/// Rutas de introducción y autenticación (accesibles sin sesión).
const _publicRoutes = {
  '/welcome',
  '/onboarding',
  '/login',
  '/register',
  '/verify',
  '/forgot-password',
  '/forgot-password/sent',
};

PlaceholderScreen _p(String title, {List<Widget> actions = const []}) =>
    PlaceholderScreen(title: title, actions: actions);

/// Botón de demostración que cambia el estado de sesión (para recorrer el esqueleto a mano).
Widget _demo(String label, AxoSession target) => Consumer(
  builder: (context, ref, _) => AxoButton(
    label: label,
    onPressed: () => ref.read(sessionProvider.notifier).set(target),
  ),
);

/// Botón de navegación (solo depuración).
Widget _devNav(String label, String location) => Builder(
  builder: (context) => AxoButton(
    label: label,
    variant: AxoButtonVariant.outline,
    onPressed: () => GoRouter.of(context).go(location),
  ),
);

/// Ruta de la galería de componentes, solo en modo debug.
const _devRoute = '/dev/components';

/// Pantalla de bienvenida vacía con los accesos visibles (centrados): entrar (demo) y galería de
/// componentes (solo debug). No van en la barra superior.
Widget _welcome() => Builder(
  builder: (context) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Scaffold(
      backgroundColor: c.bgApp,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AxoSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bienvenida',
                  style: AxoType.screenTitle.copyWith(color: c.textPrimary),
                ),
                const SizedBox(height: AxoSpacing.xxl),
                _demo('Entrar (demo)', AxoSession.unlocked),
                if (kDebugMode) ...[
                  const SizedBox(height: AxoSpacing.md),
                  _devNav('Ver componentes (dev)', _devRoute),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  },
);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AxoSession>(ref.read(sessionProvider));
  ref.listen<AxoSession>(sessionProvider, (_, next) => refresh.value = next);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = refresh.value;
      final loc = state.matchedLocation;
      // La galería de componentes está accesible en cualquier estado, solo en debug.
      if (kDebugMode && loc == _devRoute) return null;
      final isPublic = _publicRoutes.contains(loc);
      final isLocked = loc == '/unlock';
      switch (session) {
        case AxoSession.noSession:
          if (!isPublic) return '/welcome';
        case AxoSession.locked:
          if (!isLocked) return '/unlock';
        case AxoSession.unlocked:
          if (isPublic || isLocked) return '/notes';
      }
      return null;
    },
    routes: [
      // Introducción y autenticación.
      GoRoute(path: '/welcome', builder: (_, _) => _welcome()),
      GoRoute(path: '/onboarding', builder: (_, _) => _p('Onboarding')),
      GoRoute(path: '/login', builder: (_, _) => _p('Inicio de sesión')),
      GoRoute(path: '/register', builder: (_, _) => _p('Registro')),
      GoRoute(path: '/verify', builder: (_, _) => _p('Verificación de correo')),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => _p('Recuperar contraseña'),
      ),
      GoRoute(
        path: '/forgot-password/sent',
        builder: (_, _) => _p('Correo enviado'),
      ),
      GoRoute(
        path: '/unlock',
        builder: (_, _) => _p(
          'Desbloquear',
          actions: [_demo('Desbloquear (demo)', AxoSession.unlocked)],
        ),
      ),
      // Notas.
      GoRoute(
        path: '/notes',
        builder: (_, _) => _p(
          'Notas',
          actions: [
            _demo('Bloquear (demo)', AxoSession.locked),
            _demo('Cerrar sesión (demo)', AxoSession.noSession),
          ],
        ),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, _) => _p('Editor'),
            routes: [
              GoRoute(path: 'share', builder: (_, _) => _p('Compartir nota')),
            ],
          ),
        ],
      ),
      GoRoute(path: '/folders/:id', builder: (_, _) => _p('Carpeta')),
      GoRoute(path: '/trash', builder: (_, _) => _p('Papelera')),
      GoRoute(path: '/search', builder: (_, _) => _p('Búsqueda')),
      // Ajustes.
      GoRoute(path: '/settings/menu', builder: (_, _) => _p('Ajustes')),
      GoRoute(
        path: '/settings/general',
        builder: (_, _) => _p('Ajustes generales'),
      ),
      GoRoute(path: '/settings/account', builder: (_, _) => _p('Mi cuenta')),
      GoRoute(
        path: '/settings/sync',
        builder: (_, _) => _p('Sincronización y dispositivos'),
      ),
      GoRoute(
        path: '/settings/privacy',
        builder: (_, _) => _p('Privacidad y seguridad'),
      ),
      GoRoute(
        path: '/settings/storage',
        builder: (_, _) => _p('Almacenamiento y exportación'),
      ),
      GoRoute(
        path: '/settings/delete-account',
        builder: (_, _) => _p('Eliminar cuenta'),
      ),
      GoRoute(path: '/settings/about', builder: (_, _) => _p('Acerca de')),
      // Galería de componentes (solo debug).
      if (kDebugMode)
        GoRoute(path: _devRoute, builder: (_, _) => const ComponentsGallery()),
      // Ruta inicial: el redirect decide a dónde ir.
      GoRoute(path: '/', builder: (_, _) => _p('Inicio')),
    ],
  );

  ref.onDispose(() {
    refresh.dispose();
    router.dispose();
  });
  return router;
});
