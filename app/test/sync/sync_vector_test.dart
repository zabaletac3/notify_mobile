// Vector `contract/vectors/sync.json` (ver `contract/vectors/README.md`): estructura real de
// `EncryptedSyncRequest`/`EncryptedSyncResponse`, con una `masterKey` y textos cifrados de
// verdad. A diferencia de `sync-behavior.json` (campos lógicos, sin bytes cifrados), este vector
// comprueba que `RemoteSyncTransport` manda y entiende la forma exacta del contrato, y que el
// `wrappedKey`/`payload` de cada nota y carpeta se descifran con la `masterKey` del vector.
import 'package:axonote_app/data/remote/remote_sync_transport.dart';
import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/remote/fake_dio.dart';
import 'vectors.dart';

void main() {
  final vector = loadVector('sync');
  final userId = vector['userId']! as String;
  final masterKey = crypto.SecretKeyBytes(
    crypto.fromB64u(vector['masterKey']! as String),
  );
  final request = (vector['request']! as Map).cast<String, Object?>();
  final responses = (vector['responses']! as List)
      .cast<Map>()
      .map((r) => r.cast<String, Object?>())
      .toList();

  String keyAad(String entity, String id) => 'apunte/v1/key/$userId/$entity/$id';
  String dataAad(String entity, String id) => 'apunte/v1/data/$userId/$entity/$id';

  Future<void> expectNoteDecrypts(
    String id, {
    required String wrappedKey,
    required String payload,
  }) async {
    final itemKey = await crypto.unwrap(masterKey, wrappedKey, keyAad('note', id));
    final decoded = await crypto.openNotePayload(itemKey, payload, dataAad('note', id));
    expect(decoded.title, isA<String>());
    expect(decoded.content, isA<String>());
  }

  Future<void> expectFolderDecrypts(
    String id, {
    required String wrappedKey,
    required String payload,
  }) async {
    final itemKey = await crypto.unwrap(masterKey, wrappedKey, keyAad('folder', id));
    final decoded = await crypto.openFolderPayload(
      itemKey,
      payload,
      dataAad('folder', id),
    );
    expect(decoded.name, isA<String>());
  }

  test('la nota que viaja en la petición se descifra con la masterKey del vector', () async {
    final changes = (request['changes']! as List).cast<Map>();
    final noteChange = changes.firstWhere((c) => c['entity'] == 'note');
    final data = (noteChange['data']! as Map).cast<String, Object?>();
    await expectNoteDecrypts(
      noteChange['id']! as String,
      wrappedKey: data['wrappedKey']! as String,
      payload: data['payload']! as String,
    );
  });

  test(
    'RemoteSyncTransport manda la petición con la forma exacta del vector',
    () async {
      Map<String, Object?>? sent;
      final adapter = FakeAdapter((options) async {
        sent = options.data as Map<String, Object?>;
        return jsonResponse(200, responses[0]);
      });
      final transport = RemoteSyncTransport(
        await apiWith(adapter),
        deviceId: request['deviceId']! as String,
        deviceName: request['deviceName']! as String,
      );
      final changes = (request['changes']! as List).cast<Map>();

      await transport.sync(
        SyncRequest(
          cursor: request['cursor'] as String?,
          changes: [
            for (final (i, c) in changes.indexed)
              OutboxEntry(
                seq: i + 1,
                entity: c['entity'] == 'note' ? SyncEntity.note : SyncEntity.folder,
                entityId: c['id']! as String,
                op: c['op'] == 'upsert' ? SyncOp.upsert : SyncOp.delete,
                baseRevision: c['baseRevision']! as int,
                version: 1,
                changedAt: '2026-01-01T00:00:00.000Z',
                noteData: c['entity'] == 'note' && c['op'] == 'upsert'
                    ? _noteFields((c['data']! as Map).cast<String, Object?>())
                    : null,
                folderData: c['entity'] == 'folder' && c['op'] == 'upsert'
                    ? _folderFields((c['data']! as Map).cast<String, Object?>())
                    : null,
              ),
          ],
        ),
      );

      expect(sent, request);
    },
  );

  test(
    'respuesta «con-mas-cambios»: hasMore, applied y remoteChanges (nota + lápida) se descifran',
    () async {
      final response = responses.firstWhere((r) => r['name'] == 'con-mas-cambios');
      final adapter = FakeAdapter((options) async => jsonResponse(200, response));
      final transport = RemoteSyncTransport(
        await apiWith(adapter),
        deviceId: 'd',
        deviceName: 'D',
      );

      final result = await transport.sync(const SyncRequest(cursor: null, changes: []));

      expect(result.cursor, 'cursor-2');
      expect(result.hasMore, isTrue);
      expect(result.applied.single.revision, 1);
      final noteChange = result.remoteChanges.firstWhere((c) => c.entity == SyncEntity.note);
      expect(noteChange.note, isNotNull);
      await expectNoteDecrypts(
        noteChange.note!.id,
        wrappedKey: noteChange.note!.wrappedKey,
        payload: noteChange.note!.payload,
      );
      final folderChange = result.remoteChanges.firstWhere((c) => c.entity == SyncEntity.folder);
      expect(folderChange.deleted, isTrue);
    },
  );

  test(
    'respuesta «final-con-conflicto»: el conflicto y la carpeta remota se descifran',
    () async {
      final response = responses.firstWhere((r) => r['name'] == 'final-con-conflicto');
      final adapter = FakeAdapter((options) async => jsonResponse(200, response));
      final transport = RemoteSyncTransport(
        await apiWith(adapter),
        deviceId: 'd',
        deviceName: 'D',
      );

      final result = await transport.sync(const SyncRequest(cursor: null, changes: []));

      expect(result.hasMore, isFalse);
      expect(result.conflicts, hasLength(1));
      final conflict = result.conflicts.single;
      await expectNoteDecrypts(
        conflict.remote.id,
        wrappedKey: conflict.remote.wrappedKey,
        payload: conflict.remote.payload,
      );
      final folderChange = result.remoteChanges.single;
      expect(folderChange.folder, isNotNull);
      await expectFolderDecrypts(
        folderChange.folder!.id,
        wrappedKey: folderChange.folder!.wrappedKey,
        payload: folderChange.folder!.payload,
      );
    },
  );
}

EncryptedNoteFields _noteFields(Map<String, Object?> data) => EncryptedNoteFields(
  folderId: data['folderId'] as String?,
  createdAt: data['createdAt']! as String,
  updatedAt: data['updatedAt']! as String,
  deletedAt: data['deletedAt'] as String?,
  wrappedKey: data['wrappedKey']! as String,
  payload: data['payload']! as String,
);

EncryptedFolderFields _folderFields(Map<String, Object?> data) => EncryptedFolderFields(
  createdAt: data['createdAt']! as String,
  updatedAt: data['updatedAt']! as String,
  wrappedKey: data['wrappedKey']! as String,
  payload: data['payload']! as String,
);
