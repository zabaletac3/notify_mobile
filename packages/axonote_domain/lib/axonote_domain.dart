/// Dominio de AxoNote: entidades, errores, validación, reglas e interfaces de repositorio.
///
/// Dart puro, sin dependencias ni Flutter: lo comparten los paquetes puros y la app. Las
/// interfaces ([NoteRepository], [FolderRepository], [SyncStore]) las implementa `app/lib/data`.
library;

export 'src/errors.dart';
export 'src/folder.dart';
export 'src/ids.dart';
export 'src/lock_settings.dart';
export 'src/note.dart';
export 'src/note_groups.dart';
export 'src/note_query.dart';
export 'src/note_text.dart';
export 'src/repositories/folder_repository.dart';
export 'src/repositories/note_repository.dart';
export 'src/repositories/sync_store.dart';
export 'src/sync.dart';
export 'src/sync_protocol.dart';
export 'src/validation.dart';
