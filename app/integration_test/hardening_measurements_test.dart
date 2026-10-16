// Mediciones de la fase 12 (§11): abrir una nota de 10 KB (< 150 ms) y memoria en reposo con la
// lista de 2 000 notas abierta (< 200 MB). Se ejecuta en el ZTE en modo profile:
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/hardening_measurements_test.dart -d LZ0V50COPBC002769 --profile
//
// La memoria se lee con `ProcessInfo.currentRss` (Dart), que incluye el proceso entero; sirve como
// cota del presupuesto. Nunca imprime texto de notas: solo cifras.
import 'dart:io';

import 'package:axonote_app/app/local_session.dart';
import 'package:axonote_app/bootstrap/providers.dart';
import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_app/data/local/local_account.dart';
import 'package:axonote_app/data/local/test_data_generator.dart';
import 'package:axonote_app/features/editor/state/editor_adapter.dart';
import 'package:axonote_app/features/notes/ui/notes_screen.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/l10n/app_localizations.dart';
import 'package:axonote_app/ui/theme.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_markdown/axonote_markdown.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Nota realista de al menos [targetBytes] bytes.
String _note(int targetBytes) {
  const chunk = '''
# Título de sección

Un párrafo con **negrita**, *cursiva*, ~~tachado~~, ++subrayado++, `código` y un [enlace](https://apunte.app "título").

- viñeta uno
- viñeta dos
  - anidada

- [ ] tarea pendiente
- [x] tarea hecha

> Una cita con **negrita** y una idea.

---
''';
  final buffer = StringBuffer();
  while (buffer.length < targetBytes) {
    buffer.write(chunk);
  }
  return buffer.toString();
}

/// PSS en kB del propio proceso, leído de `/proc/self/smaps_rollup` (Android). `null` si no está
/// disponible.
int? _pssKb() {
  try {
    for (final line in File('/proc/self/smaps_rollup').readAsLinesSync()) {
      if (line.startsWith('Pss:')) {
        return int.tryParse(line.replaceAll(RegExp(r'[^0-9]'), ''));
      }
    }
  } catch (_) {}
  return null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('nota de 10 KB: abre en < 150 ms', (tester) async {
    final content = _note(10 * 1024);
    final sizeKb = (content.length / 1024).toStringAsFixed(1);

    final open = Stopwatch()..start();
    final blocks = MarkdownParser.parse(content).content;
    final document = EditorAdapter.toDocument(blocks);
    open.stop();

    debugPrint(
      'Fase 12 · nota ${sizeKb}KB (${blocks.length} bloques): '
      'apertura=${open.elapsedMilliseconds}ms',
    );

    expect(document.root.children, isNotEmpty);
    expect(
      open.elapsedMilliseconds,
      lessThan(150),
      reason: '§11: abrir una nota de 10 KB < 150 ms',
    );
  });

  testWidgets('Argon2id con parámetros reales (64 MiB, t=3) en < 3 s', (
    tester,
  ) async {
    final argon2id = await SodiumArgon2id.load();
    final password = utf8Encode('contraseña de prueba, no secreta');
    final salt = Uint8List(16);
    await argon2id.derive(
      password: password,
      salt: salt,
      memoryKiB: 65536,
      iterations: 3,
    );
    final watch = Stopwatch()..start();
    final key = await argon2id.derive(
      password: password,
      salt: salt,
      memoryKiB: 65536,
      iterations: 3,
    );
    watch.stop();
    debugPrint(
      'Fase 12 · Argon2id real (64 MiB, t=3): ${watch.elapsedMilliseconds}ms',
    );
    expect(key, hasLength(32));
    expect(
      watch.elapsedMilliseconds,
      lessThan(3000),
      reason: '§11: Argon2id con parámetros reales ≤ 3 s',
    );
  });

  testWidgets('memoria en reposo con la lista de 2000 notas', (tester) async {
    final dir = await getApplicationSupportDirectory();
    const userId = 'bench_memory';
    await LocalDatabase.wipe(dir, userId);
    final vault = Vault(userId: userId)..unlockWith(generateKeyBytes());
    final local = await LocalDatabase.open(
      directory: dir,
      userId: userId,
      vault: vault,
      deviceId: 'bench',
      deviceName: 'bench',
    );
    await TestDataGenerator(local.deps).generate(notes: 2000, folders: 12);

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
    for (var i = 0; i < 200 && !tester.any(find.byType(ListView)); i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsWidgets);

    // PSS (proportional set size) es la métrica de memoria de Android (`dumpsys meminfo`); el
    // RSS cuenta enteras las páginas compartidas y sobrestima. Fallback a RSS si no se puede leer.
    final pssKb = _pssKb();
    final memMb = pssKb != null
        ? pssKb / 1024
        : ProcessInfo.currentRss / (1024 * 1024);
    final label = pssKb != null ? 'PSS' : 'RSS';
    debugPrint(
      'Fase 12 · memoria en reposo con 2000 notas: '
      '$label=${memMb.toStringAsFixed(0)}MB',
    );
    expect(
      memMb,
      lessThan(200),
      reason: '§11: memoria en reposo con la lista abierta < 200 MB',
    );

    await local.close();
    await LocalDatabase.wipe(dir, userId);
  });
}
