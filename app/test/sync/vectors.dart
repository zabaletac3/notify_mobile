import 'dart:convert';
import 'dart:io';

/// Carga un archivo de `contract/vectors/<name>.json`. Las pruebas de `app` se ejecutan con el
/// directorio de trabajo en `app/` (raíz del paquete), igual que las de los demás paquetes del
/// workspace (ver `packages/axonote_crypto/test/support/vectors.dart`).
Map<String, Object?> loadVector(String name) {
  final file = File('../contract/vectors/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
}
