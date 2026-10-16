import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';

/// Uso de espacio de la cuenta (fase 11.2). Se carga al entrar en la pantalla.
class StorageController extends AsyncNotifier<StorageUsage> {
  @override
  Future<StorageUsage> build() => ref.read(storageRepositoryProvider).usage();

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(storageRepositoryProvider).usage(),
    );
  }
}

final storageUsageProvider =
    AsyncNotifierProvider<StorageController, StorageUsage>(
      StorageController.new,
    );
