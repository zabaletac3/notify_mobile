import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_app/data/local/local_codec.dart';
import 'package:axonote_crypto/axonote_crypto.dart' show SecretKeyBytes;
import 'package:axonote_domain/axonote_domain.dart';

/// Instante fijo para todo lo que no comparan los vectores (`createdAt`/`updatedAt` de lo que
/// llega remoto: ningún escenario de `sync-behavior.json` los comprueba).
const String shadowFixedInstant = '2026-03-04T10:00:00.000Z';

/// Cifra contenido lógico (título, texto…) como si viniera ya cifrado del servidor: los vectores
/// de `sync-behavior.json` describen los intercambios en campos **lógicos** (sin bytes cifrados,
/// ver `contract/vectors/README.md`), pero el `SyncStore` real (`LocalSyncStore`) necesita un
/// `EncryptedNote`/`EncryptedFolder` de verdad para poder descifrarlo al aplicar la respuesta.
///
/// Usa la misma `masterKey` que el dispositivo bajo prueba (mismo `userId` fijo que
/// `LocalHarness`, `u_test`): con eso basta para que lo que esta clase cifra, el `Vault` real del
/// dispositivo lo pueda descifrar, igual que si lo hubiera cifrado otro dispositivo de la cuenta.
class ShadowSealer {
  ShadowSealer(SecretKeyBytes masterKey)
    : _codec = LocalCodec(Vault(userId: 'u_test')..unlockWith(masterKey));

  final LocalCodec _codec;

  Future<EncryptedNote> note({
    required String id,
    required String title,
    required String content,
    required String? folderId,
    required int revision,
    required String? deletedAt,
  }) async {
    final row = await _codec.noteRow(
      Note(
        id: id,
        folderId: folderId,
        title: title,
        content: content,
        tags: const [],
        pinned: false,
        createdAt: shadowFixedInstant,
        updatedAt: shadowFixedInstant,
        deletedAt: deletedAt,
        revision: revision,
        syncStatus: NoteSyncStatus.synced,
        lastEditedDeviceId: 'd_shadow',
      ),
    );
    final sealed = await _codec.sealNoteForUpload(row);
    return EncryptedNote(
      id: id,
      folderId: folderId,
      createdAt: shadowFixedInstant,
      updatedAt: shadowFixedInstant,
      deletedAt: deletedAt,
      revision: revision,
      lastEditedDeviceId: 'd_shadow',
      wrappedKey: sealed.wrappedKey,
      payload: sealed.payload,
    );
  }

  Future<EncryptedFolder> folder({
    required String id,
    required String name,
    required int revision,
  }) async {
    final row = await _codec.folderRow(
      Folder(
        id: id,
        name: name,
        createdAt: shadowFixedInstant,
        updatedAt: shadowFixedInstant,
      ),
      revision,
    );
    final sealed = await _codec.sealFolderForUpload(row);
    return EncryptedFolder(
      id: id,
      createdAt: shadowFixedInstant,
      updatedAt: shadowFixedInstant,
      revision: revision,
      wrappedKey: sealed.wrappedKey,
      payload: sealed.payload,
    );
  }
}
