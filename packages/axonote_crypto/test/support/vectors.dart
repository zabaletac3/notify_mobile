import 'dart:convert';
import 'dart:io';

/// Carga un archivo de `contract/vectors/<name>.json`. Las pruebas de este paquete se ejecutan
/// con el directorio de trabajo en `packages/axonote_crypto` (raíz del paquete).
Map<String, Object?> loadVector(String name) {
  final file = File('../../contract/vectors/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}

List<Map<String, Object?>> listOf(Object? value) =>
    (value! as List<Object?>).cast<Map<String, Object?>>();
