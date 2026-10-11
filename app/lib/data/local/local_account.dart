import 'dart:io';

import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';

import '../crypto/vault.dart';
import 'app_database.dart';
import 'failures.dart';
import 'local_codec.dart';
import 'local_deps.dart';
import 'local_folder_repository.dart';
import 'local_note_repository.dart';
import 'local_sync_store.dart';
import 'mutex.dart';
import 'schema.dart';

/// Composición de la capa de datos local: abre la base cifrada de una cuenta y reparte los
/// repositorios. Es lo único que conoce `drift` fuera de este directorio.
class LocalDatabase {
  LocalDatabase._(this.deps);

  final LocalDeps deps;

  late final NoteRepository notes = LocalNoteRepository(deps);
  late final FolderRepository folders = LocalFolderRepository(deps);
  late final SyncStore syncStore = LocalSyncStore(deps);

  /// Abre la base cifrada de la cuenta [userId] en [directory]. La clave se deriva de la clave
  /// maestra del [vault] (A1/A2); con el cofre bloqueado esto lanza un `AppFailure(locked)`.
  static Future<LocalDatabase> open({
    required Directory directory,
    required String userId,
    required Vault vault,
    required String deviceId,
    DateTime Function()? now,
  }) async {
    final key = await _localKey(vault);
    final file = File('${directory.path}/${databaseFileName(userId)}');
    final db = AppDatabase.openEncrypted(file: file, key: key.bytes);
    return LocalDatabase._(
      LocalDeps(
        db: db,
        codec: LocalCodec(vault),
        vault: vault,
        lock: Mutex(),
        now: now ?? DateTime.now,
        deviceId: deviceId,
      ),
    );
  }

  /// Variante en memoria (pruebas y datos de ejemplo): no cifra.
  static LocalDatabase memory({
    required Vault vault,
    required String deviceId,
    DateTime Function()? now,
  }) {
    return LocalDatabase._(
      LocalDeps(
        db: AppDatabase.memory(),
        codec: LocalCodec(vault),
        vault: vault,
        lock: Mutex(),
        now: now ?? DateTime.now,
        deviceId: deviceId,
      ),
    );
  }

  Future<void> close() => deps.db.close();

  /// Borrado total por cuenta (A1): elimina el archivo de la base y sus auxiliares (`-wal`, `-shm`,
  /// `-journal`). Las claves locales las borra el almacén de la fase 5 (`axonote_platform` y
  /// `flutter_secure_storage`).
  static Future<void> wipe(Directory directory, String userId) async {
    final base = '${directory.path}/${databaseFileName(userId)}';
    for (final suffix in const ['', '-wal', '-shm', '-journal']) {
      final file = File('$base$suffix');
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  static Future<crypto.SecretKeyBytes> _localKey(Vault vault) async {
    try {
      return await vault.localDbKey();
    } on VaultLockedError {
      failLocked();
    }
  }
}
