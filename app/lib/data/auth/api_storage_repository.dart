import 'package:axonote_api/axonote_api.dart' as api;
import 'package:axonote_domain/axonote_domain.dart';

/// Implementación de [StorageRepository] sobre `axonote_api` (plan §4.2).
class ApiStorageRepository implements StorageRepository {
  ApiStorageRepository(api.HttpClient http) : _api = api.StorageApi(http);

  final api.StorageApi _api;

  @override
  Future<StorageUsage> usage() async {
    final dto = await _api.usage();
    return StorageUsage(
      usedBytes: dto.usedBytes,
      quotaBytes: dto.quotaBytes,
      notesBytes: dto.notesBytes,
      imagesBytes: dto.imagesBytes,
      trashBytes: dto.trashBytes,
    );
  }
}
