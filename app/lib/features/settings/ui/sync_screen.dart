import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';
import '../../../ui/components.dart';
import '../../../ui/tokens.dart';
import '../../sync/state/sync_controller.dart';
import '../../sync/state/sync_settings.dart';
import '../state/devices_controller.dart';
import '../state/sync_settings_controller.dart';
import 'settings_widgets.dart';

/// Sincronización y dispositivos (`/settings/sync`, tablero «Android — Sincronización y
/// dispositivos»): estado de sincronización (fase 7), ajustes reales (`SyncSettings`, los respeta el
/// motor) y lista de dispositivos (fase 11.2).
class SyncScreen extends ConsumerWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(syncSettingsProvider).value ?? const SyncSettings();
    final ctrl = ref.read(syncSettingsProvider.notifier);
    final sync = ref.watch(syncControllerProvider);
    return SettingsScaffold(
      title: 'Sincronización y dispositivos',
      children: [
        _SyncStatusCard(state: sync),
        AxoSettingsGroup(
          title: 'Sincronización',
          children: [
            AxoSettingRow(
              label: 'Sincronizar automáticamente',
              control: AxoSwitch(
                value: s.autoSync,
                onChanged: ctrl.setAutoSync,
              ),
            ),
            AxoSettingRow(
              label: 'Solo con Wi-Fi',
              description: 'Evita gastar datos móviles',
              control: AxoSwitch(
                value: s.wifiOnly,
                onChanged: ctrl.setWifiOnly,
              ),
            ),
            AxoSettingRow(
              label: 'Sincronizar ahora',
              action: sync.phase == SyncPhase.syncing
                  ? 'Sincronizando…'
                  : 'Ahora',
              onAction: sync.phase == SyncPhase.syncing
                  ? null
                  : () => ref.read(syncControllerProvider.notifier).syncNow(),
            ),
          ],
        ),
        const _DevicesGroup(),
      ],
    );
  }
}

class _DevicesGroup extends ConsumerWidget {
  const _DevicesGroup();

  static const Map<DevicePlatform, String> _platforms = {
    DevicePlatform.android: 'Android',
    DevicePlatform.linux: 'Linux',
    DevicePlatform.windows: 'Windows',
    DevicePlatform.web: 'Web',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    return AxoSettingsGroup(
      title: 'Dispositivos',
      children: devices.when(
        loading: () => const [
          AxoSettingRow(
            label: 'Cargando…',
            description: 'Consultando dispositivos',
          ),
        ],
        error: (_, _) => const [
          AxoSettingRow(label: 'No se pudieron cargar los dispositivos'),
        ],
        data: (list) => [
          for (final device in list)
            AxoSettingRow(
              label: device.name,
              description: _describe(ref, device),
              action: device.current ? null : 'Quitar',
              onAction: device.current
                  ? null
                  : () async {
                      final result = await ref
                          .read(devicesProvider.notifier)
                          .remove(device.id);
                      if (!context.mounted) return;
                      showAxoToast(
                        context,
                        message: result.isOk
                            ? 'Dispositivo eliminado'
                            : 'No se pudo quitar el dispositivo',
                        variant: result.isOk
                            ? AxoToastVariant.success
                            : AxoToastVariant.error,
                      );
                    },
            ),
        ],
      ),
    );
  }

  String _describe(WidgetRef ref, Device device) {
    final platform = _platforms[device.platform] ?? '';
    if (device.current) return 'Este dispositivo · $platform · activo ahora';
    return '$platform · ${_relative(ref, device.lastActiveAt)}';
  }

  String _relative(WidgetRef ref, DateTime at) {
    final diff = ref.read(clockProvider).now().difference(at);
    if (diff.inMinutes < 1) return 'activo ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} horas';
    return 'hace ${diff.inDays} días';
  }
}

class _SyncStatusCard extends ConsumerWidget {
  const _SyncStatusCard({required this.state});

  final SyncUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<AxoColors>()!;
    final (label, color) = _status(state, c);
    final now = ref.watch(clockProvider).now();
    return Material(
      color: c.bgSelected,
      borderRadius: BorderRadius.circular(AxoRadii.xl),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AxoSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AxoType.button.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    state.lastSyncedAt == null
                        ? 'Aún no se ha sincronizado'
                        : 'Última sincronización ${_relative(DateTime.parse(state.lastSyncedAt!), now)}',
                    style: AxoType.settingsRowDescription.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (String, Color) _status(SyncUiState state, AxoColors c) {
    if (state.phase == SyncPhase.syncing) {
      return ('Sincronizando…', c.accentDefault);
    }
    if (state.phase == SyncPhase.offline) {
      return ('Sin conexión', c.statusDanger);
    }
    if (state.phase == SyncPhase.error) {
      return ('No se pudo sincronizar', c.statusDanger);
    }
    if (state.pendingCount > 0) {
      return ('Cambios pendientes', c.tagAmber);
    }
    return ('Todo sincronizado', c.statusSuccess);
  }

  String _relative(DateTime at, DateTime now) {
    final diff = now.difference(at);
    if (diff.inMinutes < 1) return 'ahora mismo';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} minutos';
    if (diff.inHours < 24) return 'hace ${diff.inHours} horas';
    return 'hace ${diff.inDays} días';
  }
}
