/// Lectura **estricta** de los cuerpos JSON del contrato.
///
/// Regla de la fase 4: un campo ausente o de tipo equivocado es un [JsonFormatException]; jamás un
/// valor por defecto silencioso. Los DTO llaman a este lector y dejan que el cliente HTTP convierta
/// la excepción en un fallo tipado (`server`). El mensaje de la excepción solo lleva la ruta del
/// campo (`$.kdf.salt`), nunca el valor: podría ser secreto.
library;

/// Un campo del cuerpo no está o no tiene el tipo que dicta el contrato.
class JsonFormatException implements Exception {
  const JsonFormatException(this.path);

  /// Ruta del campo dentro del JSON (`$`, `$.user.id`…). Nunca contiene el valor.
  final String path;

  @override
  String toString() => 'JsonFormatException($path)';
}

/// Envuelve un valor JSON y ofrece lecturas que fallan ante ausencia o tipo equivocado.
class JsonReader {
  JsonReader(this._value, [this._path = r'$']);

  final Object? _value;
  final String _path;

  Map<String, Object?> _object() {
    final value = _value;
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    throw JsonFormatException(_path);
  }

  /// Lee un campo obligatorio. Si no está, es un fallo (aunque su valor sea `null`).
  JsonReader child(String key) {
    final map = _object();
    if (!map.containsKey(key)) throw JsonFormatException('$_path.$key');
    return JsonReader(map[key], '$_path.$key');
  }

  /// Lee un campo **opcional**: devuelve `null` si no está o si su valor es `null`.
  JsonReader? optional(String key) {
    final map = _object();
    final value = map[key];
    if (!map.containsKey(key) || value == null) return null;
    return JsonReader(value, '$_path.$key');
  }

  String asString() {
    final value = _value;
    if (value is String) return value;
    throw JsonFormatException(_path);
  }

  /// Cadena que el contrato marca como `[string, 'null']`: puede ser `null` explícito.
  String? asNullableString() {
    if (_value == null) return null;
    return asString();
  }

  bool asBool() {
    final value = _value;
    if (value is bool) return value;
    throw JsonFormatException(_path);
  }

  int asInt() {
    final value = _value;
    if (value is int) return value;
    throw JsonFormatException(_path);
  }

  /// Fecha ISO 8601. Falla si no es una cadena o no se puede interpretar.
  DateTime asDateTime() {
    final raw = asString();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) throw JsonFormatException(_path);
    return parsed;
  }

  /// Fecha ISO 8601 que el contrato marca como `[string, 'null']`, `format: date-time`.
  DateTime? asNullableDateTime() {
    if (_value == null) return null;
    return asDateTime();
  }

  List<JsonReader> asList() {
    final value = _value;
    if (value is List) {
      return [
        for (var i = 0; i < value.length; i++)
          JsonReader(value[i], '$_path[$i]'),
      ];
    }
    throw JsonFormatException(_path);
  }

  /// Objeto JSON crudo (mapa), sin validar sus campos.
  Map<String, Object?> asMap() => _object();
}
