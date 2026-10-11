// Prueba de rendimiento de la primera descarga (plan §4.4 y §11, «Hecho cuando» de la Fase 7):
// 2 000 notas en ≤ 15 s, con progreso y SIN BLOQUEAR LA INTERFAZ. La fase 7 decidió no montar un
// isolate de trabajo propio para el descifrado por lotes (ver docs/decisions.md, «Fase 7»):
// `cryptography_flutter` ya saca el AES-GCM del isolate de Dart, pero el resto (JSON, relleno,
// la propia transacción de drift) sigue en el isolate principal. Esta prueba lo MIDE en vez de
// suponerlo: un `Timer.periodic` de 16 ms detecta cualquier bloqueo del isolate principal por el
// mayor hueco entre dos de sus disparos (si el isolate está ocupado calculando, el temporizador
// se retrasa exactamente lo mismo que se retrasaría un fotograma).
//
// Se ejecuta en un dispositivo Android de verdad, en modo perfil:
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/sync_first_download_performance_test.dart \
//     -d LZ0V50COPBC002769 --profile
//
// Nunca imprime título ni contenido de ninguna nota: solo cifras (tiempos, páginas, bytes).
import 'dart:async';
import 'dart:math';

import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_app/data/local/local_account.dart';
import 'package:axonote_app/data/local/local_codec.dart';
import 'package:axonote_app/data/local/local_item_codec.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const int _totalNotes = 2000;
const int _pageSize = 500;

/// Hueco entre dos disparos sucesivos de un `Timer.periodic` de 16 ms: si el isolate principal
/// está ocupado (descifrando, decodificando JSON…), el disparo se retrasa exactamente lo mismo
/// que se retrasaría un fotograma. [maxGapMs] es el peor hueco observado.
class _JankMonitor {
  final Stopwatch _stopwatch = Stopwatch()..start();
  int _lastMs = 0;
  int maxGapMs = 0;
  Timer? _timer;

  void start() {
    _lastMs = _stopwatch.elapsedMilliseconds;
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = _stopwatch.elapsedMilliseconds;
      final gap = now - _lastMs;
      if (gap > maxGapMs) maxGapMs = gap;
      _lastMs = now;
    });
  }

  void stop() => _timer?.cancel();
}

/// Transporte guionizado: sirve [notes] en páginas de [pageSize], como lo haría el servidor real
/// en la primera sincronización (cursor `null`, `hasMore` hasta la última página).
class _PagedTransport implements SyncTransport {
  _PagedTransport(this._notes, {required this.pageSize});

  final List<EncryptedNote> _notes;
  final int pageSize;
  int _offset = 0;
  int pagesServed = 0;

  @override
  Future<SyncResponse> sync(SyncRequest request) async {
    pagesServed++;
    final page = _notes.skip(_offset).take(pageSize).toList();
    _offset += page.length;
    final hasMore = _offset < _notes.length;
    return SyncResponse(
      cursor: 'page:$_offset',
      hasMore: hasMore,
      applied: const [],
      conflicts: const [],
      remoteChanges: [
        for (final n in page)
          RemoteChange(
            entity: SyncEntity.note,
            id: n.id,
            deleted: false,
            revision: n.revision,
            note: n,
          ),
      ],
    );
  }
}

/// Cifra [count] notas remotas de verdad (mismo formato que mandaría el servidor), con un tamaño
/// de nota realista (~1-2 KB de texto, como una nota normal, no una de prueba de unas líneas).
Future<List<EncryptedNote>> _sealRemoteNotes(
  LocalCodec codec,
  int count,
) async {
  const words = [
    'lorem',
    'ipsum',
    'dolor',
    'sit',
    'amet',
    'consectetur',
    'adipiscing',
    'elit',
    'tempor',
    'incididunt',
    'labore',
    'magna',
    'aliqua',
    'veniam',
    'nostrud',
    'exercitation',
    'ullamco',
    'laboris',
    'nisi',
    'aliquip',
  ];
  final random = Random(7);
  const now = '2026-01-01T00:00:00.000Z';
  final notes = <EncryptedNote>[];
  for (var i = 0; i < count; i++) {
    final buffer = StringBuffer();
    while (buffer.length < 1200 + random.nextInt(800)) {
      buffer.write('${words[random.nextInt(words.length)]} ');
    }
    final id = newId(i);
    final row = await codec.noteRow(
      Note(
        id: id,
        folderId: null,
        title: 'Nota ${i.toString().padLeft(4, '0')}',
        content: buffer.toString(),
        tags: const [],
        pinned: false,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        revision: 1,
        syncStatus: NoteSyncStatus.synced,
        lastEditedDeviceId: 'bench_remote',
      ),
    );
    final sealed = await codec.sealNoteForUpload(row);
    notes.add(
      EncryptedNote(
        id: id,
        folderId: null,
        createdAt: now,
        updatedAt: now,
        deletedAt: null,
        revision: 1,
        lastEditedDeviceId: 'bench_remote',
        wrappedKey: sealed.wrappedKey,
        payload: sealed.payload,
      ),
    );
  }
  return notes;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'primera descarga de 2000 notas: tiempo total y bloqueo máximo del isolate principal',
    (tester) async {
      final dir = await getApplicationSupportDirectory();
      const userId = 'bench_sync_first_download';
      await LocalDatabase.wipe(dir, userId);
      final masterKey = generateKeyBytes();
      final vault = Vault(userId: userId)..unlockWith(masterKey);
      final local = await LocalDatabase.open(
        directory: dir,
        userId: userId,
        vault: vault,
        deviceId: 'bench',
        deviceName: 'bench',
      );

      // Sellado de las notas remotas: con la MISMA clave maestra (otro `Vault`, otro `LocalCodec`,
      // como si las hubiera cifrado otro dispositivo de la cuenta), pero sin tocar la base del
      // dispositivo bajo prueba.
      final remoteCodec = LocalCodec(
        Vault(userId: userId)..unlockWith(masterKey),
      );
      final remoteNotes = await _sealRemoteNotes(remoteCodec, _totalNotes);

      final transport = _PagedTransport(remoteNotes, pageSize: _pageSize);
      final engine = SyncEngine(
        store: local.syncStore,
        transport: transport,
        codec: LocalItemCodec(local.deps),
      );

      final jank = _JankMonitor()..start();
      final stopwatch = Stopwatch()..start();
      await engine.syncNow();
      stopwatch.stop();
      jank.stop();

      final totalMs = stopwatch.elapsedMilliseconds;
      final maxGapMs = jank.maxGapMs;
      debugPrint(
        'Fase 7 · primera descarga de $_totalNotes notas: total=${totalMs}ms '
        'páginas=${transport.pagesServed} bloqueo_máximo=${maxGapMs}ms',
      );

      expect(transport.pagesServed, (_totalNotes / _pageSize).ceil());
      expect(await local.syncStore.pendingCount(), 0);
      expect(
        totalMs,
        lessThan(15000),
        reason:
            'presupuesto §11: primera sincronización de 2000 notas en ≤ 15 s',
      );
      // Sin isolate de trabajo propio (decisión documentada en docs/decisions.md, «Fase 7»): si
      // el bloqueo máximo supera ~100 ms, la fase no se cierra sin montar ese isolate. Anota el
      // número impreso arriba en docs/benchmarks.md tanto si pasa como si no.
      expect(
        maxGapMs,
        lessThan(100),
        reason:
            'bloqueo máximo del isolate principal durante la descarga; por encima de esto hace '
            'falta el isolate de trabajo que describe docs/decisions.md, «Fase 7»',
      );

      await local.close();
      await LocalDatabase.wipe(dir, userId);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
