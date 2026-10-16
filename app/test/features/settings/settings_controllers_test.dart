// Pruebas de los controladores de Ajustes (fase 12, cobertura del estado §11): dispositivos, uso de
// espacio, estado de 2FA, ajustes de sincronización e importar/exportar (con repositorio real en
// memoria; el selector de archivos no existe en el entorno de pruebas, que es justo el camino de
// error a cubrir).
import 'package:axonote_app/app/local_session.dart';
import 'package:axonote_app/bootstrap/providers.dart';
import 'package:axonote_app/features/settings/state/devices_controller.dart';
import 'package:axonote_app/features/settings/state/import_export_controller.dart';
import 'package:axonote_app/features/settings/state/mfa_status_controller.dart';
import 'package:axonote_app/features/settings/state/storage_controller.dart';
import 'package:axonote_app/features/settings/state/sync_settings_controller.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/support/fakes.dart';
import '../notes/support/notes_harness.dart';
import 'support/settings_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dispositivos', () {
    test('carga ordenando el actual primero y quitar un dispositivo', () async {
      final container = settingsContainer();
      addTearDown(container.dispose);
      final devices = await container.read(devicesProvider.future);
      expect(devices.first.current, isTrue);
      expect(devices, hasLength(3));

      final result = await container
          .read(devicesProvider.notifier)
          .remove('d2');
      expect(result.isOk, isTrue);
      expect(container.read(devicesProvider).value, hasLength(2));
    });

    test('un fallo al quitar devuelve Err', () async {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          deviceRepositoryProvider.overrideWithValue(_RemoveFailingDevices()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(devicesProvider.future);
      final result = await container
          .read(devicesProvider.notifier)
          .remove('d2');
      expect(result.isOk, isFalse);
    });
  });

  group('Uso de espacio', () {
    test('carga el uso real', () async {
      final container = settingsContainer();
      addTearDown(container.dispose);
      final usage = await container.read(storageUsageProvider.future);
      expect(usage.quotaBytes, greaterThan(0));
      await container.read(storageUsageProvider.notifier).load();
      expect(container.read(storageUsageProvider).hasValue, isTrue);
    });
  });

  group('Estado de 2FA', () {
    test('carga y recarga el estado', () async {
      final auth = FakeAuthRepository();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      await container.read(mfaStatusProvider.future);
      await container.read(mfaStatusProvider.notifier).load();
      expect(container.read(mfaStatusProvider).hasValue, isTrue);
    });
  });

  group('Ajustes de sincronización', () {
    test('sin base local devuelve los valores por defecto y los cambios se reflejan', () async {
      final container = ProviderContainer(retry: (_, _) => null);
      addTearDown(container.dispose);
      final initial = await container.read(syncSettingsProvider.future);
      expect(initial.autoSync, isTrue);

      await container.read(syncSettingsProvider.notifier).setAutoSync(false);
      await container.read(syncSettingsProvider.notifier).setWifiOnly(true);
      final next = container.read(syncSettingsProvider).value!;
      expect(next.autoSync, isFalse);
      expect(next.wifiOnly, isTrue);
    });
  });

  group('Importar y exportar', () {
    test('sin sesión (repositorio nulo) devuelve LockedError', () async {
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [noteRepositoryProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);
      final controller = container.read(importExportControllerProvider);
      expect((await controller.importNotes()).isOk, isFalse);
      expect((await controller.exportAllNotes()).isOk, isFalse);
      expect((await controller.exportNote('n1')).isOk, isFalse);
    });

    test(
      'con repositorio pero sin selector de archivos cae en error controlado',
      () async {
        final h = await buildNotesHarness();
        final controller = h.container.read(importExportControllerProvider);
        // El selector de archivos no existe en el entorno de pruebas: cada acción devuelve Err.
        expect((await controller.importNotes()).isOk, isFalse);
        expect((await controller.exportAllNotes()).isOk, isFalse);
        final id = (await h.local.local.notes.list()).first.id;
        expect((await controller.exportNote(id)).isOk, isFalse);
      },
    );
  });
}

/// Repositorio de dispositivos cuyo `remove` siempre falla (para el camino de error).
class _RemoveFailingDevices implements DeviceRepository {
  @override
  Future<List<Device>> list() async => [
    Device(
      id: 'd1',
      name: 'Pixel',
      platform: DevicePlatform.android,
      lastActiveAt: DateTime.utc(2026),
      current: true,
    ),
  ];

  @override
  Future<void> remove(String deviceId) async =>
      throw const AppFailure(ServerError(status: 500));
}
