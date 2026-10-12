import 'errors.dart';

/// Resultado de una acción: éxito con valor o fallo con un [AppError] (plan §4.3). Las acciones del
/// estado devuelven `Result` en vez de lanzar; la interfaz decide qué mostrar según el `kind`.
sealed class Result<T> {
  const Result();

  /// `true` si la acción terminó bien.
  bool get isOk => this is Ok<T>;
}

/// La acción terminó bien con [value].
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

/// La acción falló con [error].
final class Err<T> extends Result<T> {
  const Err(this.error);

  final AppError error;
}
