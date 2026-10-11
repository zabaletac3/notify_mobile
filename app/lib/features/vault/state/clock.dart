/// Reloj inyectable: en producción el del sistema; en pruebas, uno falso y controlable (mismo
/// papel que `createClock()` en `notify_web/src/lib/test/test-app.js`).
abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Reloj falso para pruebas: `now()` devuelve lo que se fije con [advance] o [set].
class FakeClock implements Clock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime(2026, 1, 1);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration by) => _now = _now.add(by);

  void set(DateTime value) => _now = value;
}
