// Reproduce los 19 escenarios de `contract/vectors/sync-behavior.json` (ver
// `contract/vectors/README.md` y `docs/plan.md` §7): cola, ciclo `syncNow()`, paginación,
// conflictos y sus tres resoluciones, edición en vuelo y lápidas, todo contra un `SyncStore` real
// (`LocalSyncStore` sobre `LocalDatabase.memory`) y el motor real (`SyncEngine`), con un
// transporte guionizado que reproduce cada `exchanges[]` grabado.
//
// Solo se reproducen los pasos del dispositivo `a` (el observado): los de `b` solo existían para
// que el servidor simulado generara las respuestas que ya vienen grabadas en `exchanges[]`, así
// que aquí no hacen nada (no hay un segundo dispositivo real en esta prueba).
import 'package:axonote_app/data/local/local_item_codec.dart';
import 'package:axonote_crypto/axonote_crypto.dart' show generateKeyBytes;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/local/local_harness.dart';
import 'logical_state.dart';
import 'scripted_sync_transport.dart';
import 'shadow_sealer.dart';
import 'vectors.dart';

const _fixedNow = '2026-03-04T10:00:00.000Z';

/// Entrega, en orden, los ids que la prueba programa antes de cada paso que crea algo
/// (`createNote`, `createFolder`, la copia «(conflicto)» de `resolveConflict('both')`): el
/// vector se generó «con reloj e ids fijos» (`notify_web/.../sync-behavior-vectors.ts`), así que
/// aquí no se reproduce ese generador aleatorio, se inyecta directamente el id que el vector ya
/// grabó como resultado. Si algo crea un id sin que la prueba lo haya programado, es una llamada
/// que esta prueba no esperaba: mejor que falle alto que devolver un id al azar que tape un bug.
class _ScriptedIds {
  String? _next;

  void queue(String id) => _next = id;

  Id call([int? timestampMs]) {
    final id = _next;
    if (id == null) {
      throw StateError('se generó un id sin que la prueba lo programara');
    }
    _next = null;
    return id;
  }
}

void main() {
  final vector = loadVector('sync-behavior');
  final scenarios = (vector['scenarios']! as List)
      .cast<Map>()
      .map((s) => s.cast<String, Object?>())
      .toList();

  // Si esto falla, es que `sync-behavior.json` cambió de forma (p. ej. se regeneró con más o
  // menos escenarios): no hay que debilitar la lista, hay que mirar qué cambió.
  if (scenarios.length != 19) {
    throw StateError(
      'se esperaban 19 escenarios en sync-behavior.json y hay ${scenarios.length}',
    );
  }

  for (final scenario in scenarios) {
    test(scenario['name']! as String, () => _runScenario(scenario));
  }
}

Future<void> _runScenario(Map<String, Object?> scenario) async {
  final name = scenario['name']! as String;
  final initial = (scenario['initial']! as Map).cast<String, Object?>();
  final steps = (scenario['steps']! as List)
      .cast<Map>()
      .map((s) => s.cast<String, Object?>())
      .toList();
  final expected = (scenario['expected']! as List)
      .cast<Map>()
      .map((s) => s.cast<String, Object?>())
      .toList();
  expect(
    steps,
    hasLength(expected.length),
    reason: '$name: «steps» y «expected» deben tener la misma longitud',
  );

  final masterKey = generateKeyBytes();
  final ids = _ScriptedIds();
  final h = LocalHarness(
    master: masterKey,
    deviceId: 'd_a',
    deviceName: 'A',
    now: () => DateTime.utc(2026, 3, 4, 10),
    newId: ids.call,
  );
  addTearDown(h.close);
  final shadow = ShadowSealer(masterKey);

  expect(await logicalState(h), initial, reason: '$name: estado inicial');

  for (var i = 0; i < steps.length; i++) {
    final step = steps[i];
    if (step['device'] != 'a') continue; // solo se observa el dispositivo `a`.
    _queueCreatedId(ids, step, i == 0 ? initial : expected[i - 1], expected[i]);
    await _applyStep(h, shadow, step);
    expect(
      await logicalState(h),
      expected[i],
      reason: '$name: paso $i (${step['op']})',
    );
  }
}

/// Programa en [ids] el id que el paso va a crear, antes de ejecutarlo:
/// - `createNote`/`createFolder` lo llevan en el propio paso (`step['id']`).
/// - `resolveConflict('both')` crea además una copia «(conflicto)» cuyo id no viene en el paso;
///   se obtiene comparando los ids de nota de [previous] (el estado antes de este paso) con los
///   de [next] (el estado esperado tras él, que ya viene en el vector): el único id nuevo es el
///   de la copia.
void _queueCreatedId(
  _ScriptedIds ids,
  Map<String, Object?> step,
  Map<String, Object?> previous,
  Map<String, Object?> next,
) {
  switch (step['op']) {
    case 'createNote':
    case 'createFolder':
      ids.queue(step['id']! as String);
    case 'resolveConflict':
      final before = _noteIds(previous);
      final after = _noteIds(next);
      final created = after.difference(before);
      if (created.isNotEmpty) {
        ids.queue(created.single);
      }
  }
}

Set<String> _noteIds(Map<String, Object?> state) => (state['notes']! as List)
    .cast<Map>()
    .map((n) => n['id']! as String)
    .toSet();

Future<void> _applyStep(
  LocalHarness h,
  ShadowSealer shadow,
  Map<String, Object?> step,
) async {
  switch (step['op']) {
    case 'sync':
      await _driveSync(h, shadow, step);
    case 'editDuringSync':
      await _driveSync(h, shadow, step, editing: true);
    case 'createNote':
      await h.local.notes.create(
        NoteDraft(
          title: step['title'] as String?,
          content: step['content'] as String?,
          folderId: step['folderId'] as String?,
          folderIdPresent: step.containsKey('folderId'),
        ),
      );
    case 'updateNote':
      await h.local.notes.update(
        step['id']! as String,
        NoteDraft(
          title: step['title'] as String?,
          content: step['content'] as String?,
        ),
      );
    case 'moveToTrash':
      await h.local.notes.moveToTrash(step['id']! as String);
    case 'restore':
      await h.local.notes.restore(step['id']! as String);
    case 'deleteForever':
      await h.local.notes.deleteForever(step['id']! as String);
    case 'createFolder':
      await h.local.folders.create(step['name']! as String);
    case 'renameFolder':
      await h.local.folders.rename(
        step['id']! as String,
        step['name']! as String,
      );
    case 'deleteFolder':
      await h.local.folders.delete(step['id']! as String);
    case 'resolveConflict':
      await h.local.syncStore.resolveConflict(
        step['id']! as String,
        ConflictResolution.values.byName(step['resolution']! as String),
      );
    default:
      throw StateError('paso desconocido: ${step['op']}');
  }
}

Future<void> _driveSync(
  LocalHarness h,
  ShadowSealer shadow,
  Map<String, Object?> step, {
  bool editing = false,
}) async {
  final exchanges = (step['exchanges']! as List)
      .cast<Map>()
      .map((e) => e.cast<String, Object?>())
      .toList();
  final transport = ScriptedSyncTransport(
    exchanges: exchanges,
    shadow: shadow,
    editIndex: editing ? step['editDuringSync'] as int : null,
    editHook: editing
        ? () => h.local.notes.update(
            step['id']! as String,
            NoteDraft(content: step['content'] as String?),
          )
        : null,
  );
  final engine = SyncEngine(
    store: h.local.syncStore,
    transport: transport,
    codec: LocalItemCodec(h.local.deps),
    clock: const FixedSyncClock(_fixedNow),
  );
  await engine.syncNow();
  expect(
    transport.consumed,
    exchanges.length,
    reason: 'número de páginas distinto del grabado',
  );
}
