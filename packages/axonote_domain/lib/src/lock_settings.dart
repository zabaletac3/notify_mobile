/// Cuánto tiempo sin actividad hace falta para que el cofre se bloquee solo (plan §5.3). Mismos
/// nombres y valores que `LockTimeout` de `src/lib/domain/settings.ts` en la web.
enum LockTimeout { immediately, oneMinute, fiveMinutes, fifteenMinutes, never }

extension LockTimeoutDuration on LockTimeout {
  /// Tiempo de inactividad tras el que se bloquea, o `null` si no depende del tiempo:
  /// `immediately` se gestiona por visibilidad (al salir a segundo plano, no por un cronómetro) y
  /// `never` no bloquea sola.
  Duration? get after => switch (this) {
    LockTimeout.immediately => null,
    LockTimeout.oneMinute => const Duration(minutes: 1),
    LockTimeout.fiveMinutes => const Duration(minutes: 5),
    LockTimeout.fifteenMinutes => const Duration(minutes: 15),
    LockTimeout.never => null,
  };

  /// Valor tal como viaja en el contrato (`immediately`, `1m`, `5m`, `15m`, `never`).
  String get wire => switch (this) {
    LockTimeout.immediately => 'immediately',
    LockTimeout.oneMinute => '1m',
    LockTimeout.fiveMinutes => '5m',
    LockTimeout.fifteenMinutes => '15m',
    LockTimeout.never => 'never',
  };
}

/// Ajustes que gobiernan el cofre (plan §5.3), con los mismos valores por defecto que
/// `DEFAULT_SETTINGS` de la web: `biometricLock: true`, `lockOnExit: false`, `lockTimeout: '1m'`.
class LockSettings {
  const LockSettings({
    this.biometricLock = true,
    this.lockOnExit = false,
    this.lockTimeout = LockTimeout.oneMinute,
  });

  /// La clave maestra recordada en el dispositivo exige biometría (o, en API ≥ 30, también la
  /// credencial del teléfono) para usarse. Si es `false`, al bloquear se vuelve a pedir la
  /// contraseña salvo que además `lockOnExit` sea `false` y `lockTimeout` sea `never` (clave de
  /// dispositivo sin autenticación, equivalente a la web).
  final bool biometricLock;

  /// Bloquea al pasar la app a segundo plano, sin esperar el tiempo de `lockTimeout`.
  final bool lockOnExit;

  final LockTimeout lockTimeout;

  LockSettings copyWith({
    bool? biometricLock,
    bool? lockOnExit,
    LockTimeout? lockTimeout,
  }) => LockSettings(
    biometricLock: biometricLock ?? this.biometricLock,
    lockOnExit: lockOnExit ?? this.lockOnExit,
    lockTimeout: lockTimeout ?? this.lockTimeout,
  );

  @override
  bool operator ==(Object other) =>
      other is LockSettings &&
      other.biometricLock == biometricLock &&
      other.lockOnExit == lockOnExit &&
      other.lockTimeout == lockTimeout;

  @override
  int get hashCode => Object.hash(biometricLock, lockOnExit, lockTimeout);

  @override
  String toString() =>
      'LockSettings(biometricLock: $biometricLock, lockOnExit: $lockOnExit, '
      'lockTimeout: $lockTimeout)';
}
