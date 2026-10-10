import '../json.dart';

/// Estado de la verificación en dos pasos.
class MfaStatusDto {
  const MfaStatusDto({
    required this.enabled,
    required this.enabledAt,
    required this.recoveryCodesLeft,
  });

  factory MfaStatusDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return MfaStatusDto(
      enabled: r.child('enabled').asBool(),
      enabledAt: r.child('enabledAt').asNullableDateTime(),
      recoveryCodesLeft: r.child('recoveryCodesLeft').asInt(),
    );
  }

  final bool enabled;

  /// Cuándo se activó; `null` si no está activa.
  final DateTime? enabledAt;

  /// Códigos de respaldo sin usar (0–10).
  final int recoveryCodesLeft;
}

/// Lo que se muestra una sola vez al configurar el autenticador.
class MfaSetupResultDto {
  const MfaSetupResultDto({required this.secret, required this.otpauthUri});

  factory MfaSetupResultDto.fromJson(Object? json) {
    final r = JsonReader(json);
    return MfaSetupResultDto(
      secret: r.child('secret').asString(),
      otpauthUri: r.child('otpauthUri').asString(),
    );
  }

  final String secret;
  final String otpauthUri;
}

/// Códigos de respaldo (se devuelven en claro una sola vez).
class MfaRecoveryCodesDto {
  const MfaRecoveryCodesDto(this.recoveryCodes);

  factory MfaRecoveryCodesDto.fromJson(Object? json) {
    final r = JsonReader(json);
    final codes = <String>[
      for (final item in r.child('recoveryCodes').asList()) item.asString(),
    ];
    return MfaRecoveryCodesDto(codes);
  }

  final List<String> recoveryCodes;
}
