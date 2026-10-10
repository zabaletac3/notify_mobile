import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Estado del cofre (ver §5.3 del plan): sin sesión, bloqueado o desbloqueado.
enum AxoSession { noSession, locked, unlocked }

/// Controla el estado de sesión para la navegación. En la fase 2 es solo el esqueleto; la lógica real
/// (login, bloqueo por tiempo, `device-revoked`) llega en las fases 5 y 8.
class SessionController extends Notifier<AxoSession> {
  @override
  AxoSession build() => AxoSession.noSession;

  void set(AxoSession value) => state = value;
}

final sessionProvider = NotifierProvider<SessionController, AxoSession>(
  SessionController.new,
);
