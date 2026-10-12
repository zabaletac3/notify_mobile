import 'package:axonote_domain/axonote_domain.dart';

/// Cifra un elemento de la cola **desde su fila actual** (A4 del plan: la cola solo guarda
/// referencias, nunca datos). Lo implementa `app/lib/data` sobre `LocalCodec`
/// (`sealNoteForUpload`/`sealFolderForUpload`): el motor solo conoce el [Id], nunca filas de
/// base ni bytes cifrados de antemano.
///
/// Si el elemento ya no existe (p. ej. se borró entre encolar y sincronizar; no debería ocurrir
/// porque borrar también encola un `delete` que sustituye al `upsert`), la implementación lanza
/// `AppFailure`.
abstract interface class ItemCodec {
  /// Campos cifrados de la nota [id], listos para viajar en un `upsert`.
  Future<EncryptedNoteFields> sealNote(Id id);

  /// Campos cifrados de la carpeta [id], listos para viajar en un `upsert`.
  Future<EncryptedFolderFields> sealFolder(Id id);
}
