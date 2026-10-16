import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/session.dart';
import '../dev/components_gallery.dart';
import '../dev/editor_gallery.dart';
import '../features/auth/ui/forgot_password_screen.dart';
import '../features/auth/ui/forgot_password_sent_screen.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/onboarding_screen.dart';
import '../features/auth/ui/recovery_key_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/auth/ui/server_error_screen.dart';
import '../features/auth/ui/splash_screen.dart';
import '../features/auth/ui/two_factor_screen.dart';
import '../features/auth/ui/unlock_screen.dart';
import '../features/auth/ui/verify_screen.dart';
import '../features/auth/ui/welcome_screen.dart';
import '../features/editor/ui/editor_screen.dart';
import '../features/legal/ui/changelog_screen.dart';
import '../features/legal/ui/legal_document_screen.dart';
import '../features/legal/ui/support_screen.dart';
import '../features/notes/ui/notes_screen.dart';
import '../features/notes/ui/search_screen.dart';
import '../features/notes/ui/trash_screen.dart';
import '../features/settings/ui/about_screen.dart';
import '../features/settings/ui/account_screen.dart';
import '../features/settings/ui/delete_account_screen.dart';
import '../features/settings/ui/general_screen.dart';
import '../features/settings/ui/privacy_screen.dart';
import '../features/settings/ui/settings_menu_screen.dart';
import '../features/settings/ui/storage_screen.dart';
import '../features/settings/ui/sync_screen.dart';
import '../features/settings/ui/two_factor_screen.dart';
import '../ui/placeholder_screen.dart';

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

/// Ruta de arranque (mientras se restaura la sesión desde el almacén seguro).
const _splashRoute = '/splash';

/// Ruta de la maqueta del editor (datos falsos), solo en modo debug.
const _devEditorRoute = '/dev/editor';

PlaceholderScreen _p(String title) => PlaceholderScreen(title: title);

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
      if (kDebugMode && (loc == _devRoute || loc == _devEditorRoute)) {
        return null;
      }
      final isPublic = _publicRoutes.contains(loc);
      final isUnlock = loc == '/unlock';
      final isSplash = loc == _splashRoute;
      switch (session) {
        case AxoSession.restoring:
          // Mientras se lee el almacén seguro no se decide pantalla: solo el arranque.
          return isSplash ? null : _splashRoute;
        case AxoSession.noSession:
          if (isPublic) return null;
          final seen = ref.read(onboardingSeenProvider);
          return seen ? '/welcome' : '/onboarding';
        case AxoSession.locked:
          if (isUnlock) return null;
          return '/unlock';
        case AxoSession.unlocked:
          if (isPublic || isUnlock || loc == '/' || isSplash) return '/notes';
      }
      return null;
    },
    routes: [
      // Arranque: se muestra mientras se restaura la sesión desde el almacén seguro.
      GoRoute(path: _splashRoute, builder: (_, _) => const SplashScreen()),
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
      // Notas (fase 9).
      GoRoute(
        path: '/notes',
        builder: (_, _) => const NotesScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                EditorScreen(noteId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: '/folders/:id',
        builder: (_, state) =>
            NotesScreen(folderId: state.pathParameters['id']),
      ),
      GoRoute(path: '/trash', builder: (_, _) => const TrashScreen()),
      GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
      // Ajustes (fase 11): menú y subpantallas.
      GoRoute(
        path: '/settings/menu',
        builder: (_, _) => const SettingsMenuScreen(),
      ),
      GoRoute(
        path: '/settings/general',
        builder: (_, _) => const GeneralScreen(),
      ),
      GoRoute(
        path: '/settings/account',
        builder: (_, _) => const AccountScreen(),
      ),
      GoRoute(path: '/settings/sync', builder: (_, _) => const SyncScreen()),
      GoRoute(
        path: '/settings/privacy',
        builder: (_, _) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/settings/storage',
        builder: (_, _) => const StorageScreen(),
      ),
      GoRoute(
        path: '/settings/delete-account',
        builder: (_, _) => const DeleteAccountScreen(),
      ),
      GoRoute(path: '/settings/about', builder: (_, _) => const AboutScreen()),
      // Verificación en dos pasos (fase 11.3).
      GoRoute(
        path: '/settings/two-factor',
        builder: (_, _) => const TwoFactorSettingsScreen(),
      ),
      // Textos legales y soporte (fase 11.6).
      GoRoute(
        path: '/terms',
        builder: (_, _) => LegalDocumentScreen(document: terms),
      ),
      GoRoute(
        path: '/privacy',
        builder: (_, _) => LegalDocumentScreen(document: privacy),
      ),
      GoRoute(path: '/changelog', builder: (_, _) => const ChangelogScreen()),
      GoRoute(path: '/support', builder: (_, _) => const SupportScreen()),
      // Galería de componentes (solo debug).
      if (kDebugMode)
        GoRoute(path: _devRoute, builder: (_, _) => const ComponentsGallery()),
      // Maqueta del editor (solo debug).
      if (kDebugMode)
        GoRoute(
          path: _devEditorRoute,
          builder: (_, _) => const EditorGallery(),
        ),
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
