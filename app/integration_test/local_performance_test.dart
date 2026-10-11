// Prueba de rendimiento de la capa de datos local (plan §6, «Hecho cuando» de la Fase 6): con
// 10 000 notas, la lista inicial se consulta en < 50 ms y una búsqueda en < 100 ms en el ZTE
// (serie LZ0V50COPBC002769). Se ejecuta en un dispositivo Android de verdad:
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/local_performance_test.dart -d LZ0V50COPBC002769 --profile
//
// (con `--profile` para medir como en release). Usa la base **cifrada real** (archivo en el
// directorio de la app, clave derivada del Vault), como en producción. Mide la lista inicial
// (primera página de 200 notas) y la búsqueda en frío (justo tras cerrar y reabrir la base) y en
// caliente; borra el archivo al terminar.
import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_app/data/local/local_account.dart';
import 'package:axonote_app/data/local/test_data_generator.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Tamaño de página de la lista inicial.
const int _pageSize = 200;

class _Measure {
  const _Measure({
    required this.seedMs,
    required this.coldListMs,
    required this.coldSearchMs,
    required this.warmListMs,
    required this.warmSearchMs,
    required this.listCount,
    required this.foundCount,
  });

  final int seedMs;
  final int coldListMs;
  final int coldSearchMs;
  final int warmListMs;
  final int warmSearchMs;
  final int listCount;
  final int foundCount;
}

Future<_Measure> _measure(int count) async {
  final dir = await getApplicationSupportDirectory();
  final userId = 'bench_$count';
  await LocalDatabase.wipe(dir, userId);
  final vault = Vault(userId: userId)..unlockWith(generateKeyBytes());

  var local = await LocalDatabase.open(
    directory: dir,
    userId: userId,
    vault: vault,
    deviceId: 'bench',
    deviceName: 'bench',
  );
  final seedWatch = Stopwatch()..start();
  await TestDataGenerator(local.deps).generate(notes: count, folders: 12);
  seedWatch.stop();
  await local.close();

  // Frío: se vuelve a abrir el archivo cifrado y se mide la primera consulta.
  local = await LocalDatabase.open(
    directory: dir,
    userId: userId,
    vault: vault,
    deviceId: 'bench',
    deviceName: 'bench',
  );
  final coldList = Stopwatch()..start();
  final notes = await local.notes.list(const NoteQuery(limit: _pageSize));
  coldList.stop();
  final coldSearch = Stopwatch()..start();
  final found = await local.notes.search(
    'lorem',
    const NoteQuery(limit: _pageSize),
  );
  coldSearch.stop();

  // Caliente: las mismas dos consultas con la base ya abierta.
  final warmList = Stopwatch()..start();
  await local.notes.list(const NoteQuery(limit: _pageSize));
  warmList.stop();
  final warmSearch = Stopwatch()..start();
  await local.notes.search('lorem', const NoteQuery(limit: _pageSize));
  warmSearch.stop();

  await local.close();
  await LocalDatabase.wipe(dir, userId);

  return _Measure(
    seedMs: seedWatch.elapsedMilliseconds,
    coldListMs: coldList.elapsedMilliseconds,
    coldSearchMs: coldSearch.elapsedMilliseconds,
    warmListMs: warmList.elapsedMilliseconds,
    warmSearchMs: warmSearch.elapsedMilliseconds,
    listCount: notes.length,
    foundCount: found.length,
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    '2000 notas (base cifrada): lista y búsqueda en frío y en caliente',
    (tester) async {
      final r = await _measure(2000);
      debugPrint(
        'Fase 6 · 2000 cifrada: seed=${r.seedMs}ms '
        'cold list=${r.coldListMs}ms search=${r.coldSearchMs}ms · '
        'warm list=${r.warmListMs}ms search=${r.warmSearchMs}ms',
      );
      expect(r.listCount, _pageSize);
      expect(r.foundCount, _pageSize);
      expect(r.coldListMs, lessThan(50));
      expect(r.coldSearchMs, lessThan(100));
      expect(r.warmListMs, lessThan(50));
      expect(r.warmSearchMs, lessThan(100));
    },
  );

  testWidgets(
    '10000 notas (base cifrada): lista inicial < 50 ms y búsqueda < 100 ms',
    (tester) async {
      final r = await _measure(10000);
      debugPrint(
        'Fase 6 · 10000 cifrada: seed=${r.seedMs}ms '
        'cold list=${r.coldListMs}ms search=${r.coldSearchMs}ms · '
        'warm list=${r.warmListMs}ms search=${r.warmSearchMs}ms',
      );
      expect(r.listCount, _pageSize);
      expect(r.foundCount, _pageSize);
      expect(r.coldListMs, lessThan(50));
      expect(r.coldSearchMs, lessThan(100));
      expect(r.warmListMs, lessThan(50));
      expect(r.warmSearchMs, lessThan(100));
    },
  );
}
