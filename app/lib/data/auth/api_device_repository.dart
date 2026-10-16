import 'package:axonote_api/axonote_api.dart' as api;
import 'package:axonote_domain/axonote_domain.dart';

/// Implementación de [DeviceRepository] sobre `axonote_api` (plan §4.2: nadie fuera de
/// `app/lib/data` importa `dio`).
class ApiDeviceRepository implements DeviceRepository {
  ApiDeviceRepository(api.HttpClient http) : _api = api.DeviceApi(http);

  final api.DeviceApi _api;

  @override
  Future<List<Device>> list() async {
    final dtos = await _api.list();
    return [
      for (final dto in dtos)
        Device(
          id: dto.id,
          name: dto.name,
          platform: _platform(dto.platform),
          lastActiveAt: dto.lastActiveAt,
          current: dto.current,
        ),
    ];
  }

  @override
  Future<void> remove(String deviceId) => _api.remove(deviceId);

  static DevicePlatform _platform(api.DevicePlatform platform) =>
      switch (platform) {
        api.DevicePlatform.linux => DevicePlatform.linux,
        api.DevicePlatform.windows => DevicePlatform.windows,
        api.DevicePlatform.android => DevicePlatform.android,
        api.DevicePlatform.web => DevicePlatform.web,
      };
}
