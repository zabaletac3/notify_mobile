import 'package:axonote_domain/axonote_domain.dart';
import 'package:path_provider/path_provider.dart';

import '../local/local_account.dart';

/// Borrado de la copia local de una cuenta (A1): el archivo de la base cifrada vive en el
/// directorio de soporte de la app (el mismo que usa el resto de la capa local).
class FileSystemDataCleaner implements LocalDataCleaner {
  const FileSystemDataCleaner();

  @override
  Future<void> wipe(String userId) async {
    final directory = await getApplicationSupportDirectory();
    await LocalDatabase.wipe(directory, userId);
  }
}
