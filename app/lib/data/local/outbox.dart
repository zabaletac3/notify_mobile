import 'package:axonote_domain/axonote_domain.dart';

import 'sync_dao.dart';

/// Cola de cambios pendientes. Portado de `notify_web/src/lib/data/local/outbox.ts`, con la
/// diferencia de que aquí la cola guarda **solo referencias** (A4): los datos del elemento se
/// cifran al enviar, desde la fila actual (fase 7).
///
/// Se funden los cambios de una misma entidad:
///  - varias ediciones → una sola, con la `base_revision` más antigua y `version + 1`;
///  - crear y borrar sin haber sincronizado → no queda nada que contarle al servidor;
///  - editar y luego borrar → solo el borrado.
///
/// Siempre debe llamarse dentro de la misma transacción que escribe la fila.
class Outbox {
  Outbox(this._dao);

  final SyncDao _dao;

  Future<void> enqueue({
    required SyncEntity entity,
    required String entityId,
    required SyncOp op,
    required int baseRevision,
    required String changedAt,
  }) async {
    final existing = await _dao.outboxEntry(entity.wire, entityId);

    if (existing.isEmpty) {
      if (op == SyncOp.delete && baseRevision == 0) {
        return; // nunca llegó al servidor
      }
      await _dao.insertOutbox(
        entity.wire,
        entityId,
        op.wire,
        baseRevision,
        1,
        changedAt,
      );
      return;
    }

    final seq = existing['seq']! as int;
    final currentBase = existing['base_revision']! as int;
    final currentVersion = existing['version']! as int;

    if (op == SyncOp.delete) {
      if (currentBase == 0) {
        await _dao.deleteOutbox(seq);
        return;
      }
      await _dao.updateOutbox(
        seq,
        'delete',
        currentBase,
        currentVersion + 1,
        changedAt,
      );
      return;
    }

    await _dao.updateOutbox(
      seq,
      'upsert',
      currentBase,
      currentVersion + 1,
      changedAt,
    );
  }
}
