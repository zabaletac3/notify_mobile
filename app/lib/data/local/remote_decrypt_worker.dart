// Descifrado de una página grande de cambios remotos en un isolate de trabajo (plan §4.4/§12).
//
// Por qué hace falta: D12 preveía `cryptography_flutter` para sacar el AES-GCM del isolate de
// Dart, pero esta fase no llegó a integrarlo (`axonote_crypto` solo depende de
// `package:cryptography`, cuyo AES-GCM es software puro, síncrono, en el isolate que lo llama).
// Medido en el ZTE `LZ0V50COPBC002769` con la primera descarga de 2 000 notas (4 páginas de
// 500): el tiempo total está bien (<5,1 s), pero el mayor bloqueo del isolate principal llega a
// ~560 ms por página — por encima del umbral de 100 ms de
// `integration_test/sync_first_download_performance_test.dart`. No es el paso de mensajes de 500
// filas lo que bloquea (eso es barato): es el propio descifrado — desenvolver la clave de cada
// elemento y abrir su payload (AES-GCM + relleno + JSON) 500 veces en el hilo que también dibuja
// la interfaz.
import 'dart:isolate';
import 'dart:typed_data';

import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';

import '../crypto/vault.dart';
import 'local_codec.dart' show unreadableFolderRow, unreadableNoteRow;
import 'rows.dart';

/// Umbral de elementos a partir del cual una página se descifra en un isolate de trabajo en vez
/// de en línea. Por debajo, levantar un isolate (arrancar su VM, copiar los datos) cuesta más de
/// lo que ahorra: una sincronización incremental normal (unos pocos cambios) sigue descifrando en
/// el isolate principal, como antes.
const int remoteDecryptIsolateThreshold = 50;

/// Filas ya descifradas de un lote, listas para que `LocalSyncStore.applyResult` las escriba en
/// una sola transacción (este cálculo no toca la base: solo cifra/descifra y construye filas).
class RemoteDecryptBatch {
  const RemoteDecryptBatch({required this.noteRows, required this.folderRows});

  final Map<Id, NoteRow> noteRows;
  final Map<Id, FolderRow> folderRows;
}

/// Descifra [changes] (ya filtrados: sin lápidas, cada uno con su `note` o `folder`) en un
/// isolate de trabajo aparte.
///
/// Solo cruzan la frontera del isolate [userId] y una **copia** de los bytes de la clave maestra,
/// nunca el `Vault` ni su caché de claves de elemento: el isolate reconstruye su propia
/// `SecretKeyBytes` a partir de esos bytes, descifra, y la borra (la pone a cero) antes de
/// devolver el resultado — nunca llega a un registro ni se queda en memoria más de lo necesario.
/// Quien llama debe borrar también su copia en cuanto esta función vuelve: no lo hace esta
/// función, los bytes son prestados, no suyos.
Future<RemoteDecryptBatch> decryptRemoteChangesInWorker({
  required String userId,
  required Uint8List masterKeyBytes,
  required List<RemoteChange> changes,
}) {
  return Isolate.run(() => _decryptBatch(userId, masterKeyBytes, changes));
}

Future<RemoteDecryptBatch> _decryptBatch(
  String userId,
  Uint8List masterKeyBytes,
  List<RemoteChange> changes,
) async {
  final master = crypto.SecretKeyBytes(masterKeyBytes);
  try {
    final noteRows = <Id, NoteRow>{};
    final folderRows = <Id, FolderRow>{};
    for (final ch in changes) {
      if (ch.entity == SyncEntity.note && ch.note != null) {
        noteRows[ch.id] = await _noteRowFromRemote(
          userId,
          master,
          ch.note!,
          NoteSyncStatus.synced,
        );
      } else if (ch.entity == SyncEntity.folder && ch.folder != null) {
        folderRows[ch.id] = await _folderRowFromRemote(
          userId,
          master,
          ch.folder!,
        );
      }
    }
    return RemoteDecryptBatch(noteRows: noteRows, folderRows: folderRows);
  } finally {
    master.dispose();
  }
}

/// Descifra una nota remota con la clave maestra directa (sin `Vault`): misma lógica que
/// `LocalCodec.openNote` + `LocalCodec.noteRow` para el caso remoto, donde siempre hay
/// `wrappedKey` (nunca genera una clave nueva ni mezcla con una fila anterior). Si el formato del
/// payload o de las filas cambia, hay que cambiar también `LocalCodec`:
/// `remote_decrypt_worker_test.dart` lo comprueba comparando ambos caminos con el mismo vector.
Future<NoteRow> _noteRowFromRemote(
  String userId,
  crypto.SecretKeyBytes master,
  EncryptedNote enc,
  NoteSyncStatus status,
) async {
  try {
    final key = await crypto.unwrap(
      master,
      enc.wrappedKey,
      vaultKeyAad(userId, ItemEntity.note, enc.id),
    );
    final payload = await crypto.openNotePayload(
      key,
      enc.payload,
      vaultDataAad(userId, ItemEntity.note, enc.id),
    );
    return NoteRow(
      id: enc.id,
      folderId: enc.folderId,
      title: payload.title,
      content: payload.content,
      preview: derivePreview(payload.content),
      tagsJson: tagsToJson(payload.tags),
      pinned: payload.pinned,
      createdAt: enc.createdAt,
      updatedAt: enc.updatedAt,
      deletedAt: enc.deletedAt,
      revision: enc.revision,
      syncStatus: status,
      lastEditedDeviceId: enc.lastEditedDeviceId,
      wrappedKey: enc.wrappedKey,
      unreadable: false,
      rawPayload: null,
    );
  } on crypto.DecryptError {
    return unreadableNoteRow(enc, status);
  } on crypto.CryptoFormatError {
    return unreadableNoteRow(enc, status);
  }
}

/// Descifra una carpeta remota con la clave maestra directa. Ver [_noteRowFromRemote].
Future<FolderRow> _folderRowFromRemote(
  String userId,
  crypto.SecretKeyBytes master,
  EncryptedFolder enc,
) async {
  try {
    final key = await crypto.unwrap(
      master,
      enc.wrappedKey,
      vaultKeyAad(userId, ItemEntity.folder, enc.id),
    );
    final payload = await crypto.openFolderPayload(
      key,
      enc.payload,
      vaultDataAad(userId, ItemEntity.folder, enc.id),
    );
    return FolderRow(
      id: enc.id,
      name: payload.name,
      createdAt: enc.createdAt,
      updatedAt: enc.updatedAt,
      revision: enc.revision,
      wrappedKey: enc.wrappedKey,
      unreadable: false,
      rawPayload: null,
    );
  } on crypto.DecryptError {
    return unreadableFolderRow(enc);
  } on crypto.CryptoFormatError {
    return unreadableFolderRow(enc);
  }
}
