import 'package:axonote_app/features/settings/state/mfa_status_controller.dart';
import 'package:axonote_app/features/sync/state/sync_controller.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:axonote_app/bootstrap/providers.dart';

import '../../auth/support/fakes.dart';

/// Fecha base de las pruebas de Ajustes.
final DateTime settingsBaseNow = DateTime(2026, 10, 15, 10, 0);

/// Dispositivos de muestra (los del tablero) para los goldens.
class FakeDeviceRepository implements DeviceRepository {
  @override
  Future<List<Device>> list() async => [
    Device(
      id: 'd1',
      name: 'Pixel 8',
      platform: DevicePlatform.android,
      lastActiveAt: settingsBaseNow,
      current: true,
    ),
    Device(
      id: 'd2',
      name: 'Laptop Fedora',
      platform: DevicePlatform.linux,
      lastActiveAt: settingsBaseNow.subtract(const Duration(hours: 2)),
      current: false,
    ),
    Device(
      id: 'd3',
      name: 'PC de la universidad',
      platform: DevicePlatform.windows,
      lastActiveAt: settingsBaseNow.subtract(const Duration(days: 3)),
      current: false,
    ),
  ];

  @override
  Future<void> remove(String deviceId) async {}
}

/// Uso de espacio de muestra (180 MB de 1 GB), el del tablero.
class FakeStorageRepository implements StorageRepository {
  static const int _mb = 1024 * 1024;

  @override
  Future<StorageUsage> usage() async => const StorageUsage(
    usedBytes: 180 * _mb,
    quotaBytes: 1024 * _mb,
    notesBytes: 120 * _mb,
    imagesBytes: 55 * _mb,
    trashBytes: 5 * _mb,
  );
}

/// Sincronización de muestra: «Todo sincronizado» hace 2 minutos.
class FakeSyncController extends SyncController {
  FakeSyncController(this._now);

  final DateTime _now;

  @override
  SyncUiState build() => SyncUiState(
    phase: SyncPhase.idle,
    pendingCount: 0,
    conflicts: const [],
    lastSyncedAt: _now.subtract(const Duration(minutes: 2)).toIso8601String(),
  );
}

/// Verificación en dos pasos desactivada (para los goldens).
class FakeMfaStatusController extends MfaStatusController {
  @override
  Future<MfaStatus> build() async =>
      const MfaStatus(enabled: false, enabledAt: null, recoveryCodesLeft: 0);
}

/// Contenedor con los repositorios de muestra de Ajustes y un reloj inyectado.
ProviderContainer settingsContainer() {
  return ProviderContainer(
    overrides: [
      deviceRepositoryProvider.overrideWithValue(FakeDeviceRepository()),
      storageRepositoryProvider.overrideWithValue(FakeStorageRepository()),
      vaultPrefsProvider.overrideWithValue(FakeVaultPrefs()),
      clockProvider.overrideWithValue(FakeClock(settingsBaseNow)),
      syncControllerProvider.overrideWith(
        () => FakeSyncController(settingsBaseNow),
      ),
      mfaStatusProvider.overrideWith(FakeMfaStatusController.new),
    ],
  );
}
