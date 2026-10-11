import 'package:axonote_domain/axonote_domain.dart';
import 'package:test/test.dart';

Note note({String id = 'n', String? folderId}) => Note(
  id: id,
  folderId: folderId,
  title: 't',
  content: 'c',
  tags: const ['a'],
  pinned: false,
  createdAt: '2026-10-01T00:00:00.000Z',
  updatedAt: '2026-10-01T00:00:00.000Z',
  deletedAt: null,
  revision: 1,
  syncStatus: NoteSyncStatus.synced,
  lastEditedDeviceId: 'd',
);

void main() {
  group('Note', () {
    test(
      'copyWith cambia cada campo, incluidos folderId y deletedAt a null',
      () {
        final base = note(folderId: 'f');
        final trashed = base.copyWith(
          id: 'n2',
          folderId: null,
          title: 'x',
          content: 'y',
          tags: const ['b'],
          pinned: true,
          createdAt: '2026-10-02T00:00:00.000Z',
          updatedAt: '2026-10-03T00:00:00.000Z',
          deletedAt: '2026-10-04T00:00:00.000Z',
          revision: 5,
          syncStatus: NoteSyncStatus.pending,
          lastEditedDeviceId: 'd2',
          unreadable: true,
        );
        expect(trashed.id, 'n2');
        expect(trashed.folderId, isNull);
        expect(trashed.title, 'x');
        expect(trashed.content, 'y');
        expect(trashed.tags, ['b']);
        expect(trashed.pinned, isTrue);
        expect(trashed.deletedAt, '2026-10-04T00:00:00.000Z');
        expect(trashed.revision, 5);
        expect(trashed.syncStatus, NoteSyncStatus.pending);
        expect(trashed.lastEditedDeviceId, 'd2');
        expect(trashed.unreadable, isTrue);

        expect(trashed.copyWith(deletedAt: null).deletedAt, isNull);
        // Sin argumentos, copia igual.
        expect(base.copyWith(), base);
      },
    );

    test('igualdad y hashCode comparan las etiquetas en orden', () {
      expect(note(), note());
      expect(note().hashCode, note().hashCode);
      expect(note(), isNot(note(id: 'other')));
      expect(note().copyWith(tags: const ['a', 'b']), isNot(note()));
    });

    test('NoteSyncStatus tiene su valor de contrato', () {
      expect(NoteSyncStatus.synced.wire, 'synced');
      expect(NoteSyncStatus.pending.wire, 'pending');
      expect(NoteSyncStatus.conflict.wire, 'conflict');
    });
  });

  group('Folder', () {
    const folder = Folder(
      id: 'f',
      name: 'U',
      createdAt: '2026-10-01T00:00:00.000Z',
      updatedAt: '2026-10-01T00:00:00.000Z',
    );

    test('copyWith, igualdad y hashCode', () {
      expect(folder.copyWith(name: 'V').name, 'V');
      expect(folder.copyWith(), folder);
      expect(folder, isNot(folder.copyWith(name: 'X')));
      expect(folder.hashCode, folder.copyWith().hashCode);
    });
  });

  group('tipos de sincronización', () {
    test('construye versiones, conflictos y snapshot', () {
      const local = NoteVersion(
        title: 'a',
        content: 'b',
        editedAt: '2026-10-01T00:00:00.000Z',
        deviceName: 'd',
      );
      const conflict = Conflict(noteId: 'n', local: local, remote: local);
      expect(conflict.local.title, 'a');
      expect(conflict.remote.deviceName, 'd');
      expect(
        const SyncSnapshot(
          phase: SyncPhase.syncing,
          lastSyncedAt: null,
          pendingCount: 3,
          conflicts: [],
        ).pendingCount,
        3,
      );
      expect(ConflictResolution.values, hasLength(3));
      expect(SyncPhase.values, hasLength(4));
    });
  });

  group('protocolo cifrado', () {
    const enc = EncryptedNote(
      id: 'n',
      folderId: 'f',
      createdAt: '2026-10-01T00:00:00.000Z',
      updatedAt: '2026-10-01T00:00:00.000Z',
      deletedAt: null,
      revision: 2,
      lastEditedDeviceId: 'd',
      wrappedKey: 'a1.x.y',
      payload: 'a1.p.q',
    );
    const encFolder = EncryptedFolder(
      id: 'f',
      createdAt: '2026-10-01T00:00:00.000Z',
      updatedAt: '2026-10-01T00:00:00.000Z',
      revision: 1,
      wrappedKey: 'a1.x.y',
      payload: 'a1.p.q',
    );

    test('campos de nota y carpeta se derivan correctamente', () {
      final fields = EncryptedNoteFields.fromNote(enc);
      expect(fields.folderId, 'f');
      expect(fields.payload, 'a1.p.q');
      final folderFields = EncryptedFolderFields.fromFolder(encFolder);
      expect(folderFields.wrappedKey, 'a1.x.y');
    });

    test('filas de cola, conflicto y enlace', () {
      final outbox = OutboxEntry(
        seq: 1,
        entity: SyncEntity.note,
        entityId: 'n',
        op: SyncOp.upsert,
        baseRevision: 0,
        version: 1,
        changedAt: 't',
        noteData: EncryptedNoteFields.fromNote(enc),
      );
      expect(outbox.noteData!.folderId, 'f');
      final pending = PendingChange(
        entity: SyncEntity.folder,
        entityId: 'f',
        op: SyncOp.delete,
        baseRevision: 3,
        folderData: EncryptedFolderFields.fromFolder(encFolder),
      );
      expect(pending.folderData!.payload, 'a1.p.q');
      const conflict = ConflictRow(
        noteId: 'n',
        remote: enc,
        remoteDeviceName: 'd',
        detectedAt: 't',
      );
      expect(conflict.remote.id, 'n');
      const share = ShareRow(
        noteId: 'n',
        slug: 's',
        wrappedShareKey: 'w',
        createdAt: 't',
        updatedAt: 't',
      );
      expect(share.slug, 's');
    });

    test('resultados de sincronización', () {
      const applied = AppliedChange(
        entity: SyncEntity.note,
        id: 'n',
        revision: 5,
      );
      expect(applied.revision, 5);
      const remote = RemoteChange(
        entity: SyncEntity.folder,
        id: 'f',
        deleted: false,
        revision: 1,
        folder: encFolder,
      );
      expect(remote.folder!.id, 'f');
      const report = ConflictReport(
        noteId: 'n',
        remote: enc,
        remoteDeviceName: 'd',
      );
      expect(report.remoteDeviceName, 'd');
    });

    test('conversión de entidades y claves de cola', () {
      expect(SyncEntity.fromWire('note'), SyncEntity.note);
      expect(SyncOp.upsert.wire, 'upsert');
      expect(SyncOp.delete.wire, 'delete');
      expect(outboxKey(SyncEntity.folder, 'f'), 'folder:f');
      expect(() => SyncEntity.fromWire('x'), throwsArgumentError);
    });
  });

  group('errores', () {
    test('cada AppError tiene su kind y sus datos no sensibles', () {
      expect(const NetworkError().kind, 'network');
      expect(const ServerError(status: 500).status, 500);
      expect(const ServerError().kind, 'server');
      expect(
        const UnauthorizedError(code: 'invalid-credentials').code,
        'invalid-credentials',
      );
      expect(
        const ForbiddenError(code: ForbiddenCode.limitReached).kind,
        'forbidden',
      );
      expect(ForbiddenCode.limitReached.wire, 'limit-reached');
      expect(const SessionExpiredError().kind, 'session-expired');
      expect(const LockedError().kind, 'locked');
      expect(const DecryptError().kind, 'decrypt');
      expect(const DeviceRevokedError().kind, 'device-revoked');
      expect(const NotFoundError(entity: 'note').entity, 'note');
      expect(const ValidationError({'email': 'invalid'}).fields, {
        'email': 'invalid',
      });
      expect(const ConflictError(noteId: 'n', code: 'c').noteId, 'n');
      expect(const RateLimitedError(retryAfterSec: 30).retryAfterSec, 30);
      expect(const UnknownError(message: 'm').message, 'm');
    });

    test('AppFailure solo imprime el kind (no filtra datos)', () {
      const failure = AppFailure(ValidationError({'note': 'in-trash'}));
      expect(failure.kind, 'validation');
      expect(failure.toString(), 'AppFailure(validation)');
    });
  });
}
