import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/session.dart';
import '../dev/components_gallery.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/auth/ui/forgot_password_sent_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/onboarding_screen.dart';
import '../features/auth/ui/recovery_key_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/auth/ui/server_error_screen.dart';
import '../features/auth/ui/two_factor_screen.dart';
import '../features/auth/ui/unlock_screen.dart';
import '../features/auth/ui/verify_screen.dart';
import '../features/auth/ui/welcome_screen.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/vault/state/vault_lock.dart';
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
  '/two-factor',
  '/forgot-password',
  '/forgot-password/sent',
};

/// Ruta de la galería de componentes, solo en modo debug.
const _devRoute = '/dev/components';

PlaceholderScreen _p(String title) => PlaceholderScreen(title: title);

/// Pantalla provisional de notas (fase 9) con las acciones de sesión de esta fase: bloquear y
/// cerrar sesión, para poder recorrer el ciclo completo mientras no existe la lista real.
class _NotesHome extends ConsumerWidget {
  const _NotesHome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AxoColors>()!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notas',
          style: AxoType.heading.copyWith(color: c.textPrimary),
        ),
        backgroundColor: c.bgApp,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notas',
              style: AxoType.screenTitle.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: AxoSpacing.sm),
            Text(
              '(lista en la fase 9)',
              style: AxoType.body.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: AxoSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AxoSpacing.xxxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AxoButton(
                    label: 'Bloquear',
                    variant: AxoButtonVariant.outline,
                    onPressed: () =>
                        ref.read(vaultLockControllerProvider).lock(),
                  ),
                  const SizedBox(height: AxoSpacing.md),
                  AxoButton(
                    label: 'Cerrar sesión',
                    variant: AxoButtonVariant.outline,
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AxoSession>(ref.read(sessionProvider));
  ref.listen<AxoSession>(sessionProvider, (_, next) => refresh.value = next);

  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    errorBuilder: (context, state) =>
        ServerErrorScreen(code: 404, onRetry: () => context.go('/')),
    redirect: (context, state) {
      final session = refresh.value;
      final loc = state.matchedLocation;
      // La galería de componentes está accesible en cualquier estado, solo en debug.
      if (kDebugMode && loc == _devRoute) return null;
      final isPublic = _publicRoutes.contains(loc);
      final isLocked = loc == '/unlock';
      switch (session) {
        case AxoSession.noSession:
          if (loc == '/') return '/onboarding';
          if (!isPublic) return '/welcome';
        case AxoSession.locked:
          if (!isLocked) return '/unlock';
        case AxoSession.unlocked:
          if (isPublic || isLocked || loc == '/') return '/notes';
      }
      return null;
    },
    routes: [
      // Introducción y autenticación.
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(path: '/verify', builder: (_, _) => const VerifyScreen()),
      GoRoute(
        path: '/recovery-key',
        builder: (_, _) => const RecoveryKeyScreen(),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/two-factor', builder: (_, _) => const TwoFactorScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/forgot-password/sent',
        builder: (_, _) => const ForgotPasswordSentScreen(),
      ),
      GoRoute(path: '/unlock', builder: (_, _) => const UnlockScreen()),
      // Notas (lista real en la fase 9).
      GoRoute(
        path: '/notes',
        builder: (_, _) => const _NotesHome(),
        routes: [GoRoute(path: ':id', builder: (_, _) => _p('Editor'))],
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
