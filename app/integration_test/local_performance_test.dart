// Prueba de rendimiento de la capa de datos local (plan §6, «Hecho cuando» de la Fase 6): con
// 10 000 notas, la lista inicial se consulta en < 50 ms y una búsqueda en < 100 ms en el ZTE
// (serie LZ0V50COPBC002769). Se ejecuta en un dispositivo Android de verdad:
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/local_performance_test.dart -d LZ0V50COPBC002769 --profile
//
// (con `--profile` para medir como en release). Genera los datos en memoria para medir el camino
// de consulta (lista y FTS5); el cifrado de la base no cambia esos tiempos.
//
// La lista inicial es una **página** (200 notas): la interfaz usa `ListView.builder` y no
// materializa toda la colección (§4.3, §4.4). También se registra, sin afirmarlo, el tiempo de la
// lista completa para dejar constancia.
import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_app/data/local/local_account.dart';
import 'package:axonote_app/data/local/test_data_generator.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Tamaño de página de la lista inicial.
const int _pageSize = 200;

class _Measure {
  const _Measure({
    required this.seedMs,
    required this.listMs,
    required this.searchMs,
    required this.fullListMs,
    required this.listCount,
    required this.foundCount,
  });

  final int seedMs;
  final int listMs;
  final int searchMs;
  final int fullListMs;
  final int listCount;
  final int foundCount;
}

Future<_Measure> _measure(int count) async {
  final vault = Vault(userId: 'bench')..unlockWith(generateKeyBytes());
  final local = LocalDatabase.memory(vault: vault, deviceId: 'bench');
  try {
    final seedWatch = Stopwatch()..start();
    await TestDataGenerator(local.deps).generate(notes: count, folders: 12);
    seedWatch.stop();

    final listWatch = Stopwatch()..start();
    final notes = await local.notes.list(const NoteQuery(limit: _pageSize));
    listWatch.stop();

    final searchWatch = Stopwatch()..start();
    final found = await local.notes.search(
      'lorem',
      const NoteQuery(limit: _pageSize),
    );
    searchWatch.stop();

    final fullWatch = Stopwatch()..start();
    final full = await local.notes.list();
    fullWatch.stop();
    debugPrint(
      'Fase 6 · $count: lista completa (sin límite) = ${fullWatch.elapsedMilliseconds}ms '
      '(${full.length} notas)',
    );

    return _Measure(
      seedMs: seedWatch.elapsedMilliseconds,
      listMs: listWatch.elapsedMilliseconds,
      searchMs: searchWatch.elapsedMilliseconds,
      fullListMs: fullWatch.elapsedMilliseconds,
      listCount: notes.length,
      foundCount: found.length,
    );
  } finally {
    await local.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('2000 notas: página de lista y búsqueda', (tester) async {
    final r = await _measure(2000);
    debugPrint(
      'Fase 6 · 2000 notas: seed=${r.seedMs}ms list=${r.listMs}ms search=${r.searchMs}ms',
    );
    expect(r.listCount, _pageSize);
    expect(r.foundCount, _pageSize);
    expect(r.listMs, lessThan(50));
    expect(r.searchMs, lessThan(100));
  });

  testWidgets('10000 notas: lista inicial < 50 ms y búsqueda < 100 ms', (
    tester,
  ) async {
    final r = await _measure(10000);
    debugPrint(
      'Fase 6 · 10000 notas: seed=${r.seedMs}ms list=${r.listMs}ms search=${r.searchMs}ms',
    );
    expect(r.listCount, _pageSize);
    expect(r.foundCount, _pageSize);
    expect(r.listMs, lessThan(50));
    expect(r.searchMs, lessThan(100));
  });
}
