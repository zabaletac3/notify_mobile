import 'dart:async';

import 'package:axonote_domain/axonote_domain.dart';

/// Evento de sesión publicado en el canal único (§4.3).
enum SessionEvent {
  /// El servidor cerró la sesión (token inválido, contraseña cambiada en otro sitio).
  expired,

  /// Este dispositivo fue eliminado de la cuenta desde otro: hay que borrar la copia local.
  deviceRevoked,
}

/// Canal único de eventos de sesión (§4.3). Lo publica la capa de datos cuando una respuesta
/// remota devuelve `session-expired` o `device-revoked`; lo escucha el estado de autenticación.
///
/// Es un `broadcast`: varias capas pueden escuchar a la vez. El estado lo usa para llevar la sesión
/// a `expired` o a `noSession` y borrar lo local.
class SessionEventBus {
  final StreamController<SessionEvent> _controller =
      StreamController<SessionEvent>.broadcast();

  Stream<SessionEvent> get stream => _controller.stream;

  void emit(SessionEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }

  /// Publica según el `kind` del error, si es uno de sesión. Devuelve `true` si lo era.
  bool emitForError(AppError error) {
    if (error is SessionExpiredError) {
      emit(SessionEvent.expired);
      return true;
    }
    if (error is DeviceRevokedError) {
      emit(SessionEvent.deviceRevoked);
      return true;
    }
    return false;
  }

  void dispose() {
    _controller.close();
  }
}
