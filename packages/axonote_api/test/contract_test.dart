import 'dart:io';

import 'package:axonote_api/axonote_api.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Comprueba que cada ruta + método que usa el cliente existe en `contract/openapi.yaml`. Lee el
/// YAML real, no una copia: si el contrato y el cliente divergen, la prueba falla.
void main() {
  final root = _repoRoot();
  final document = loadYaml(
    File('${root.path}/contract/openapi.yaml').readAsStringSync(),
  );
  final paths = document['paths'] as YamlMap;

  test('cada ruta y método usado por el cliente está en el contrato', () {
    final missing = <String>[];
    for (final route in ApiRoutes.all) {
      final entry = paths[route.pathTemplate];
      if (entry is! YamlMap) {
        missing.add('${route.method} ${route.pathTemplate} (ruta ausente)');
        continue;
      }
      if (!entry.containsKey(route.method.toLowerCase())) {
        missing.add('${route.method} ${route.pathTemplate}');
      }
    }
    expect(missing, isEmpty);
  });

  test('el cliente no usa rutas de Google ni de dispositivos de confianza', () {
    final templates = ApiRoutes.all.map((route) => route.pathTemplate);
    expect(templates.where((path) => path.contains('google')), isEmpty);
    expect(
      templates.where((path) => path.contains('trusted-devices')),
      isEmpty,
    );
  });
}

Directory _repoRoot() {
  var dir = Directory.current;
  while (true) {
    if (File('${dir.path}/contract/openapi.yaml').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('no se encontró contract/openapi.yaml');
    }
    dir = parent;
  }
}
