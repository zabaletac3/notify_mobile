// Comprueba las reglas de dependencia entre capas del workspace (ver §4.2 del plan).
//
// Uso: dart run tool/check_imports.dart  (desde la raíz del repositorio)
//
// Reglas:
//  - Cada paquete solo puede importar de los paquetes internos permitidos.
//  - Los paquetes Dart puros (domain, crypto, markdown, api, sync) no importan Flutter.
//  - Nadie fuera de `app/lib/data` importa `drift` ni `dio`.
import 'dart:io';

/// Paquetes internos y qué otros paquetes internos pueden importar.
const Map<String, Set<String>> allowedInternal = {
  'axonote_domain': {},
  'axonote_crypto': {},
  'axonote_markdown': {},
  'axonote_api': {'axonote_domain'},
  'axonote_sync': {'axonote_domain'},
  'axonote_platform': {},
  'axonote_app': {
    'axonote_domain',
    'axonote_crypto',
    'axonote_markdown',
    'axonote_api',
    'axonote_sync',
    'axonote_platform',
  },
};

/// Paquetes que no pueden depender de Flutter.
const Set<String> purePackages = {
  'axonote_domain',
  'axonote_crypto',
  'axonote_markdown',
  'axonote_api',
  'axonote_sync',
};

final _internal = allowedInternal.keys.toSet();
final _import = RegExp(r"""^\s*(?:import|export)\s+['"](?:package:([^/'"]+)|(dart:[^'"]+))""");

void main() {
  final root = Directory.current;
  final packages = <String, Directory>{
    for (final name in allowedInternal.keys)
      name: Directory(
        name == 'axonote_app' ? '${root.path}/app/lib' : '${root.path}/packages/$name/lib',
      ),
  };

  final violations = <String>[];
  for (final entry in packages.entries) {
    final name = entry.key;
    final dir = entry.value;
    if (!dir.existsSync()) continue;
    for (final file in dir.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final rel = file.path.replaceFirst('${root.path}/', '');
      final inData = rel.contains('app/lib/data/');
      for (final line in file.readAsLinesSync()) {
        final match = _import.firstMatch(line);
        if (match == null) continue;
        final pkg = match.group(1);
        final dartUri = match.group(2);
        if (pkg != null && _internal.contains(pkg) && pkg != name) {
          if (!(allowedInternal[name]!.contains(pkg))) {
            violations.add('$rel: «$name» no puede importar «$pkg»');
          }
        }
        final isFlutter = pkg == 'flutter' || (pkg?.startsWith('flutter_') ?? false) || dartUri == 'dart:ui';
        if (isFlutter && purePackages.contains(name)) {
          violations.add('$rel: el paquete puro «$name» no puede depender de Flutter ($pkg)');
        }
        final isDataOnly = pkg == 'drift' || pkg == 'dio' || (pkg?.startsWith('drift_') ?? false);
        if (isDataOnly && name == 'axonote_app' && !inData) {
          violations.add('$rel: fuera de app/lib/data no se importa «$pkg»');
        }
      }
    }
  }

  if (violations.isEmpty) {
    stdout.writeln('Arquitectura correcta.');
    return;
  }
  stderr.writeln('Se han encontrado ${violations.length} violación(es) de arquitectura:');
  for (final v in violations) {
    stderr.writeln('  - $v');
  }
  exit(1);
}
