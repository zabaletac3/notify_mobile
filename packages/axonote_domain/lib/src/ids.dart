import 'dart:math';
import 'dart:typed_data';

/// Identificador opaco (UUID en datos reales, `n_1`… en datos de prueba).
typedef Id = String;

/// Fecha y hora en formato ISO 8601 (UTC) con milisegundos, tal cual viaja en el contrato,
/// p. ej. `2026-10-07T08:54:00.000Z`. Nunca se convierte a entero: debe volver al servidor
/// igual que llegó (plan §6).
typedef IsoDate = String;

final Random _secureRandom = Random.secure();

/// Identificador nuevo para notas y carpetas: UUID v7 (los 48 bits altos son la hora, así que
/// ordenan por creación). Lo genera el cliente para poder crear sin conexión. Equivale a
/// `newId` de `notify_web/src/lib/domain/ids.ts`.
Id newId([int? timestampMs]) {
  final millis = timestampMs ?? DateTime.now().millisecondsSinceEpoch;
  final bytes = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    bytes[i] = _secureRandom.nextInt(256);
  }
  var t = millis;
  for (var i = 5; i >= 0; i--) {
    bytes[i] = t % 256;
    t = t ~/ 256;
  }
  bytes[6] = (bytes[6] & 0x0f) | 0x70; // versión 7
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  final hex = StringBuffer();
  for (final b in bytes) {
    hex.write(b.toRadixString(16).padLeft(2, '0'));
  }
  final s = hex.toString();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}'
      '-${s.substring(16, 20)}-${s.substring(20)}';
}

/// Fecha en ISO 8601 UTC con milisegundos, idéntica a la de `Date.prototype.toISOString` de la
/// web (siempre 3 dígitos de milisegundos, sufijo `Z`).
String isoFromDateTime(DateTime date) {
  final u = date.toUtc();
  String p(int value, int width) => value.toString().padLeft(width, '0');
  return '${p(u.year, 4)}-${p(u.month, 2)}-${p(u.day, 2)}T'
      '${p(u.hour, 2)}:${p(u.minute, 2)}:${p(u.second, 2)}.'
      '${p(u.millisecond, 3)}Z';
}

/// Interpreta una fecha ISO 8601 del contrato. Lanza [FormatException] si no tiene la forma
/// esperada; nunca cae a un valor por defecto.
DateTime parseIsoDate(String value) => DateTime.parse(value);

/// Instante actual como [IsoDate] (UTC con milisegundos).
IsoDate nowIso() => isoFromDateTime(DateTime.now());
