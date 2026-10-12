import 'package:axonote_domain/axonote_domain.dart' as domain;

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
    this.newId = domain.newId,
  }) : notes = NotesDao(db),
       folders = FoldersDao(db),
       sync = SyncDao(db);

  final AppDatabase db;
  final LocalCodec codec;
  final Vault vault;
  final Mutex lock;
  final DateTime Function() now;
  final String deviceId;

  /// Generador de identificadores nuevos para notas y carpetas (por defecto el real,
  /// `domain.newId`). Inyectable para que las pruebas de los vectores de comportamiento
  /// (`sync-behavior.json`, generado «con reloj e ids fijos») entreguen el id exacto de cada
  /// paso en vez del id aleatorio real.
  final domain.Id Function([int?]) newId;

  /// Nombre del dispositivo, como lo muestra el servidor en los conflictos (en la web es
  /// `device.name`). Distinto del identificador [deviceId].
  final String deviceName;
  final NotesDao notes;
  final FoldersDao folders;
  final SyncDao sync;
}
