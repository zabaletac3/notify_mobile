import '../folder.dart';
import '../ids.dart';

/// Acceso a las carpetas guardadas en local. Lo implementa `app/lib/data` (drift).
abstract interface class FolderRepository {
  Future<List<Folder>> list();

  /// Igual que [list], pero reactivo.
  Stream<List<Folder>> watch();

  Future<Folder> create(String name);

  Future<Folder> rename(Id id, String name);

  /// Borra la carpeta; sus notas pasan a «sin carpeta» (plan §6).
  Future<void> delete(Id id);
}
