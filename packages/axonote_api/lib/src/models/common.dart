import '../json.dart';

/// Tipos comunes a varios DTO: enumeraciones del contrato y el alias de texto cifrado.

/// Texto cifrado con AES-256-GCM: `a1.<iv>.<ct>` (base64url). Aquí es solo un tipo; lo produce y lo
/// lee `axonote_crypto`.
typedef Sealed = String;

/// Convierte una cadena del contrato en el valor del enum. Falla si no es cadena o no está en la
/// lista: nunca cae a un valor por defecto.
T enumFromWire<T>(
  Iterable<T> values,
  String Function(T value) toWire,
  Object? raw,
  String path,
) {
  if (raw is! String) throw JsonFormatException(path);
  for (final value in values) {
    if (toWire(value) == raw) return value;
  }
  throw JsonFormatException(path);
}

/// Plataforma del dispositivo (`DevicePlatform`).
enum DevicePlatform {
  linux('linux'),
  windows('windows'),
  android('android'),
  web('web');

  const DevicePlatform(this.wire);

  final String wire;
}

/// Tema preferido (`AppSettings.theme`).
enum ThemePreference {
  system('system'),
  light('light'),
  dark('dark');

  const ThemePreference(this.wire);

  final String wire;
}

/// Tamaño de texto (`AppSettings.textSize`).
enum TextSize {
  small('small'),
  medium('medium'),
  large('large');

  const TextSize(this.wire);

  final String wire;
}

/// Orden de las notas (`AppSettings.noteOrder`).
enum NoteOrder {
  updated('updated'),
  created('created'),
  title('title');

  const NoteOrder(this.wire);

  final String wire;
}

/// Tiempo de bloqueo (`AppSettings.lockTimeout`).
enum LockTimeout {
  immediately('immediately'),
  oneMinute('1m'),
  fiveMinutes('5m'),
  fifteenMinutes('15m'),
  never('never');

  const LockTimeout(this.wire);

  final String wire;
}

/// Entidad de un cambio de sincronización (`SyncChange.entity`).
enum SyncEntity {
  note('note'),
  folder('folder');

  const SyncEntity(this.wire);

  final String wire;
}

/// Operación de un cambio de sincronización (`SyncChange.op`).
enum SyncOp {
  upsert('upsert'),
  delete('delete');

  const SyncOp(this.wire);

  final String wire;
}

/// Modo de restablecimiento de contraseña (`PasswordResetRequest.mode`).
enum PasswordResetMode {
  keep('keep'),
  wipe('wipe');

  const PasswordResetMode(this.wire);

  final String wire;
}
