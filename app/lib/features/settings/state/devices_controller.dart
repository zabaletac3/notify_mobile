import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';

/// Dispositivos con sesión activa (fase 11.2). Se cargan al entrar; quitar uno cierra su sesión.
class DevicesController extends AsyncNotifier<List<Device>> {
  @override
  Future<List<Device>> build() => _load();

  Future<List<Device>> _load() async {
    final list = await ref.read(deviceRepositoryProvider).list();
    // El dispositivo actual primero.
    return [...list]
      ..sort((a, b) => (b.current ? 1 : 0).compareTo(a.current ? 1 : 0));
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  /// Quita (cierra la sesión de) un dispositivo. Devuelve el resultado para avisar.
  Future<Result<bool>> remove(String id) async {
    try {
      await ref.read(deviceRepositoryProvider).remove(id);
      final current = state.value ?? const <Device>[];
      state = AsyncData(current.where((d) => d.id != id).toList());
      return const Ok(true);
    } on AppFailure catch (e) {
      return Err(e.error);
    } catch (_) {
      return const Err(UnknownError());
    }
  }
}

final devicesProvider = AsyncNotifierProvider<DevicesController, List<Device>>(
  DevicesController.new,
);
