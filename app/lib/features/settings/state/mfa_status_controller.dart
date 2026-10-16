import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap/providers.dart';

/// Estado de la verificación en dos pasos (`GET /mfa`), para el contador real de
/// «Privacidad y seguridad».
class MfaStatusController extends AsyncNotifier<MfaStatus> {
  @override
  Future<MfaStatus> build() => ref.read(authRepositoryProvider).mfaStatus();

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).mfaStatus(),
    );
  }
}

final mfaStatusProvider = AsyncNotifierProvider<MfaStatusController, MfaStatus>(
  MfaStatusController.new,
);
