import '../crypto/vault.dart';
import 'app_database.dart';
import 'folders_dao.dart';
import 'local_codec.dart';
import 'mutex.dart';
import 'notes_dao.dart';
import 'sync_dao.dart';

/// Dependencias compartidas por los repositorios locales.
class LocalDeps {
  LocalDeps({
    required this.db,
    required this.codec,
    required this.vault,
    required this.lock,
    required this.now,
    required this.deviceId,
    required this.deviceName,
  }) : notes = NotesDao(db),
       folders = FoldersDao(db),
       sync = SyncDao(db);

  final AppDatabase db;
  final LocalCodec codec;
  final Vault vault;
  final Mutex lock;
  final DateTime Function() now;
  final String deviceId;

  /// Nombre del dispositivo, como lo muestra el servidor en los conflictos (en la web es
  /// `device.name`). Distinto del identificador [deviceId].
  final String deviceName;
  final NotesDao notes;
  final FoldersDao folders;
  final SyncDao sync;
}
