import 'package:axonote_app/data/remote/remote_sync_transport.dart';
import 'package:axonote_domain/axonote_domain.dart' as domain;
import 'package:axonote_sync/axonote_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_dio.dart';

void main() {
  test(
    'manda deviceId/deviceName y los cambios con sus campos cifrados, sin pasar las fechas por DateTime',
    () async {
      late Map<String, Object?> sentBody;
      final adapter = FakeAdapter((options) async {
        sentBody = options.data as Map<String, Object?>;
        return jsonResponse(200, {
          'cursor': '1',
          'hasMore': false,
          'applied': <Object?>[],
          'conflicts': <Object?>[],
          'remoteChanges': <Object?>[],
        });
      });
      final transport = RemoteSyncTransport(
        await apiWith(adapter),
        deviceId: 'd_a',
        deviceName: 'Móvil de A',
      );

      final response = await transport.sync(
        SyncRequest(
          cursor: '0',
          changes: [
            const domain.OutboxEntry(
              seq: 1,
              entity: domain.SyncEntity.note,
              entityId: 'n1',
              op: domain.SyncOp.upsert,
              baseRevision: 0,
              version: 1,
              changedAt: '2026-03-04T10:00:00.123Z',
              noteData: domain.EncryptedNoteFields(
                folderId: 'f1',
                createdAt: '2026-03-04T10:00:00.123Z',
                updatedAt: '2026-03-04T10:00:00.456Z',
                deletedAt: null,
                wrappedKey: 'a1.wrap.key',
                payload: 'a1.pay.load',
              ),
            ),
            const domain.OutboxEntry(
              seq: 2,
              entity: domain.SyncEntity.folder,
              entityId: 'f1',
              op: domain.SyncOp.delete,
              baseRevision: 3,
              version: 1,
              changedAt: '2026-03-04T10:00:00.123Z',
            ),
          ],
        ),
      );

      expect(response.cursor, '1');
      expect(response.hasMore, isFalse);
      expect(sentBody['deviceId'], 'd_a');
      expect(sentBody['deviceName'], 'Móvil de A');
      expect(sentBody['cursor'], '0');
      final changes = sentBody['changes'] as List<Object?>;
      expect(changes, hasLength(2));
      final noteChange = changes[0] as Map<String, Object?>;
      expect(noteChange['entity'], 'note');
      expect(noteChange['id'], 'n1');
      expect(noteChange['op'], 'upsert');
      expect(noteChange['baseRevision'], 0);
      final data = noteChange['data'] as Map<String, Object?>;
      expect(data['folderId'], 'f1');
      expect(
        data['createdAt'],
        '2026-03-04T10:00:00.123Z',
        reason: 'la fecha viaja tal cual el texto local, sin pasar por DateTime',
      );
      expect(data['updatedAt'], '2026-03-04T10:00:00.456Z');
      expect(data['wrappedKey'], 'a1.wrap.key');
      expect(data['payload'], 'a1.pay.load');

      final folderChange = changes[1] as Map<String, Object?>;
      expect(folderChange['entity'], 'folder');
      expect(folderChange['op'], 'delete');
      expect(folderChange.containsKey('data'), isFalse);
    },
  );

  test(
    'las fechas que bajan vuelven exactamente como llegaron (DTO → dominio)',
    () async {
      final adapter = FakeAdapter((options) async {
        return jsonResponse(200, {
          'cursor': '2',
          'hasMore': false,
          'applied': <Object?>[],
          'conflicts': <Object?>[],
          'remoteChanges': [
            {
              'entity': 'note',
              'id': 'n1',
              'deleted': false,
              'revision': 1,
              'note': {
                'id': 'n1',
                'folderId': null,
                'createdAt': '2026-03-04T10:00:00.123Z',
                'updatedAt': '2026-03-04T10:00:05.000Z',
                'deletedAt': null,
                'revision': 1,
                'lastEditedDeviceId': 'd_b',
                'wrappedKey': 'a1.k.v',
                'payload': 'a1.p.v',
              },
            },
          ],
        });
      });
      final transport = RemoteSyncTransport(
        await apiWith(adapter),
        deviceId: 'd_a',
        deviceName: 'A',
      );

      final response = await transport.sync(
        const SyncRequest(cursor: null, changes: []),
      );

      final note = response.remoteChanges.single.note!;
      expect(note.createdAt, '2026-03-04T10:00:00.123Z');
      expect(note.updatedAt, '2026-03-04T10:00:05.000Z');
      expect(note.deletedAt, isNull);
      expect(note.wrappedKey, 'a1.k.v');
    },
  );

  test(
    'una fecha remota sin milisegundos se normaliza a milisegundos (mismo instante)',
    () async {
      final adapter = FakeAdapter(
        (options) async => jsonResponse(200, {
          'cursor': '2',
          'hasMore': false,
          'applied': <Object?>[],
          'conflicts': <Object?>[],
          'remoteChanges': [
            {
              'entity': 'note',
              'id': 'n1',
              'deleted': false,
              'revision': 1,
              'note': {
                'id': 'n1',
                'folderId': null,
                'createdAt': '2026-03-04T10:00:00Z',
                'updatedAt': '2026-03-04T10:00:00Z',
                'deletedAt': null,
                'revision': 1,
                'lastEditedDeviceId': 'd_b',
                'wrappedKey': 'a1.k.v',
                'payload': 'a1.p.v',
              },
            },
          ],
        }),
      );
      final transport = RemoteSyncTransport(
        await apiWith(adapter),
        deviceId: 'd_a',
        deviceName: 'A',
      );

      final response = await transport.sync(
        const SyncRequest(cursor: null, changes: []),
      );

      final note = response.remoteChanges.single.note!;
      // Documentado en docs/decisions.md, «Fase 7»: es seguro porque createdAt/updatedAt de una
      // nota o carpeta siempre los fija un cliente (web o móvil), que siempre escribe
      // milisegundos exactos; el servidor nunca produce esta forma por su cuenta.
      expect(note.createdAt, '2026-03-04T10:00:00.000Z');
      expect(note.updatedAt, '2026-03-04T10:00:00.000Z');
    },
  );

  test(
    'una fecha remota con microsegundos se trunca a milisegundos (nunca llega así en la práctica)',
    () async {
      final adapter = FakeAdapter(
        (options) async => jsonResponse(200, {
          'cursor': '2',
          'hasMore': false,
          'applied': <Object?>[],
          'conflicts': <Object?>[],
          'remoteChanges': [
            {
              'entity': 'note',
              'id': 'n1',
              'deleted': false,
              'revision': 1,
              'note': {
                'id': 'n1',
                'folderId': null,
                'createdAt': '2026-03-04T10:00:00.123456Z',
                'updatedAt': '2026-03-04T10:00:00.123999Z',
                'deletedAt': null,
                'revision': 1,
                'lastEditedDeviceId': 'd_b',
                'wrappedKey': 'a1.k.v',
                'payload': 'a1.p.v',
              },
            },
          ],
        }),
      );
      final transport = RemoteSyncTransport(
        await apiWith(adapter),
        deviceId: 'd_a',
        deviceName: 'A',
      );

      final response = await transport.sync(
        const SyncRequest(cursor: null, changes: []),
      );

      final note = response.remoteChanges.single.note!;
      // isoFromDateTime solo escribe DateTime.millisecond: los microsegundos de más se truncan
      // (no se redondean). Inofensivo por el mismo motivo que el caso de arriba: la base local
      // solo guarda milisegundos (plan §6), así que esa fracción no se podría conservar de todos
      // modos, y ningún cliente real la produce.
      expect(note.createdAt, '2026-03-04T10:00:00.123Z');
      expect(note.updatedAt, '2026-03-04T10:00:00.123Z');
    },
  );
}
