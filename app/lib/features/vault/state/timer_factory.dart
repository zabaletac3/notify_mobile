import 'dart:async';

import 'clock.dart';

/// Un temporizador que se puede cancelar, sin más.
abstract class CancelableTimer {
  void cancel();
}

/// Fábrica de temporizadores inyectable: en producción, un [Timer] real de `dart:async`; en
/// pruebas, uno falso que dispara al avanzar un [FakeClock] en vez de esperar tiempo real (ver
/// [FakeTimerFactory]). Necesario porque el gestor de bloqueo decide "en cuánto tiempo bloquear"
/// a partir de la hora que da el [Clock] inyectado, y un `Timer` real no conoce ese reloj.
abstract class TimerFactory {
  CancelableTimer schedule(Duration delay, void Function() callback);
}

class RealTimerFactory implements TimerFactory {
  const RealTimerFactory();

  @override
  CancelableTimer schedule(Duration delay, void Function() callback) =>
      _RealCancelableTimer(Timer(delay, callback));
}

class _RealCancelableTimer implements CancelableTimer {
  _RealCancelableTimer(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

class _PendingTimer {
  _PendingTimer(this.at, this.callback);

  final DateTime at;
  final void Function() callback;
  bool cancelled = false;
  bool fired = false;
}

/// Fábrica falsa para pruebas: los temporizadores no esperan tiempo real. [advance] mueve el
/// [FakeClock] compartido y dispara, en orden, cualquier temporizador pendiente cuyo plazo ya se
/// cumplió (como `vi.advanceTimersByTimeAsync` en las pruebas de la web).
class FakeTimerFactory implements TimerFactory {
  FakeTimerFactory(this.clock);

  final FakeClock clock;
  final List<_PendingTimer> _pending = [];

  @override
  CancelableTimer schedule(Duration delay, void Function() callback) {
    final entry = _PendingTimer(clock.now().add(delay), callback);
    _pending.add(entry);
    return _FakeCancelableTimer(entry);
  }

  void advance(Duration by) {
    clock.advance(by);
    // Copia la lista: un callback puede programar otro temporizador nuevo durante el bucle.
    final due = _pending
        .where((t) => !t.cancelled && !t.fired && !clock.now().isBefore(t.at))
        .toList();
    for (final entry in due) {
      if (entry.cancelled || entry.fired) continue;
      entry.fired = true;
      _pending.remove(entry);
      entry.callback();
    }
  }

  /// Cuántos temporizadores siguen pendientes (ni disparados ni cancelados). Solo para pruebas.
  int get pendingCount =>
      _pending.where((t) => !t.cancelled && !t.fired).length;
}

class _FakeCancelableTimer implements CancelableTimer {
  _FakeCancelableTimer(this._entry);

  final _PendingTimer _entry;

  @override
  void cancel() => _entry.cancelled = true;
}
