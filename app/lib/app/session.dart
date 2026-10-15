import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado del cofre (ver §5.3 del plan): restaurando, sin sesión, bloqueado o desbloqueado.
///
/// [restoring] es el estado inicial mientras se lee el almacén seguro al arrancar: la navegación
/// muestra una pantalla de arranque y no decide todavía entre onboarding, bienvenida, desbloqueo o
/// notas (así no parpadea ninguna pantalla). La fase 8 resuelve el estado real en
/// `AuthController.bootstrap`.
enum AxoSession { restoring, noSession, locked, unlocked }

/// Controla el estado de sesión para la navegación. Lo resuelve `AuthController.bootstrap` al
/// arrancar (fase 8) y lo actualizan el login, el desbloqueo, el bloqueo por tiempo y el cierre de
/// sesión.
class SessionController extends Notifier<AxoSession> {
  @override
  AxoSession build() => AxoSession.restoring;

  void set(AxoSession value) => state = value;
}

final sessionProvider = NotifierProvider<SessionController, AxoSession>(
  SessionController.new,
);

/// Si la persona ya vio la introducción en este dispositivo. Lo resuelve `AuthController.bootstrap`
/// desde el almacén seguro antes de decidir la pantalla; la introducción solo se enseña la primera
/// vez y después de cerrar sesión se vuelve a la bienvenida.
class OnboardingSeenController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final onboardingSeenProvider = NotifierProvider<OnboardingSeenController, bool>(
  OnboardingSeenController.new,
);
