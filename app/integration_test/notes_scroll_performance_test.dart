// Prueba de desplazamiento de la lista de notas (plan §10, «Hecho cuando» de la Fase 9 y §11:
// «Desplazamiento de la lista: sin cuadros > 16 ms en el percentil 99»). Con 10 000 notas en la
// base cifrada real, abre la pantalla de notas y la desplaza; mide los tiempos por cuadro con
// `SchedulerBinding.addTimingsCallback` y exige que el percentil 99 no pase de 16 ms.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/notes_scroll_performance_test.dart -d LZ0V50COPBC002769 --profile
//
import 'package:axonote_app/app/local_session.dart';
import 'package:axonote_app/bootstrap/providers.dart';
import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_app/data/local/local_account.dart';
import 'package:axonote_app/data/local/test_data_generator.dart';
import 'package:axonote_app/features/notes/ui/notes_screen.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('10 000 notas: desplazamiento con p99 ≤ 16 ms', (tester) async {
    final dir = await getApplicationSupportDirectory();
    const userId = 'bench_scroll';
    await LocalDatabase.wipe(dir, userId);
    final vault = Vault(userId: userId)..unlockWith(generateKeyBytes());
    final local = await LocalDatabase.open(
      directory: dir,
      userId: userId,
      vault: vault,
      deviceId: 'bench',
      deviceName: 'bench',
    );
    final seed = Stopwatch()..start();
    await TestDataGenerator(local.deps).generate(notes: 10000, folders: 12);
    seed.stop();

    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        noteRepositoryProvider.overrideWithValue(local.notes),
        folderRepositoryProvider.overrideWithValue(local.folders),
        clockProvider.overrideWithValue(const SystemClock()),
        deviceNameProvider.overrideWithValue('bench'),
      ],
    );
    addTearDown(container.dispose);

    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    SchedulerBinding.instance.addTimingsCallback(collect);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AxoTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(412, 915),
              padding: EdgeInsets.only(top: 39, bottom: 26),
            ),
            child: NotesScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // La lista se lee de la base de forma asíncrona: espera a que pinte la primera página.
    for (var i = 0; i < 200 && !tester.any(find.byType(ListView)); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsWidgets);
    // La primera página ya está pintada: descarta los cuadros de arranque.
    timings.clear();

    final list = find.byType(ListView).first;
    final scroll = Stopwatch()..start();
    for (var i = 0; i < 12; i++) {
      await tester.fling(list, const Offset(0, -4000), 10000);
      for (var f = 0; f < 45; f++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }
    await tester.pumpAndSettle();
    scroll.stop();
    SchedulerBinding.instance.removeTimingsCallback(collect);

    final spans =
        timings.map((t) => t.totalSpan.inMicroseconds / 1000.0).toList()
          ..sort();
    final p50 = _percentile(spans, 0.50);
    final p99 = _percentile(spans, 0.99);
    final over = spans.where((s) => s > 16).length;
    debugPrint(
      'Fase 9 · 10000 notas scroll: seed=${seed.elapsedMilliseconds}ms '
      'frames=${spans.length} en ${scroll.elapsedMilliseconds}ms · '
      'p50=${p50.toStringAsFixed(1)}ms p99=${p99.toStringAsFixed(1)}ms '
      'cuadros>16ms=$over',
    );

    expect(spans, isNotEmpty);
    expect(
      p99,
      lessThanOrEqualTo(16.0),
      reason: '§11: sin cuadros > 16 ms en el percentil 99',
    );

    await local.close();
    await LocalDatabase.wipe(dir, userId);
  });
}

double _percentile(List<double> sorted, double q) {
  if (sorted.isEmpty) return 0;
  final index = ((sorted.length - 1) * q).round();
  return sorted[index];
}
