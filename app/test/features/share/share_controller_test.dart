import 'package:axonote_app/app/local_session.dart';
import 'package:axonote_app/bootstrap/providers.dart';
import 'package:axonote_app/data/crypto/share_codec.dart';
import 'package:axonote_app/features/auth/state/vault_lifecycle.dart';
import 'package:axonote_app/features/share/state/share_controller.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/features/vault/state/timer_factory.dart';
import 'package:axonote_app/features/vault/state/vault_lock.dart';
import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_crypto/axonote_crypto.dart' show openLinkPayload;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/local/local_harness.dart';
import '../auth/support/fakes.dart';
import 'support/fake_share_repository.dart';

void main() {
  late LocalHarness harness;
  late FakeShareRepository repo;
  late ProviderContainer container;

  setUp(() async {
    AxonotePlatform.instance = FakeAxonotePlatform();
    harness = LocalHarness();
    repo = FakeShareRepository();
    final clock = FakeClock(DateTime.utc(2026, 10, 15, 9));
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        noteRepositoryProvider.overrideWithValue(harness.local.notes),
        folderRepositoryProvider.overrideWithValue(harness.local.folders),
        shareRepositoryProvider.overrideWithValue(repo),
        clockProvider.overrideWithValue(clock),
        vaultTimerFactoryProvider.overrideWithValue(FakeTimerFactory(clock)),
        vaultPrefsProvider.overrideWithValue(FakeVaultPrefs()),
        argon2idProvider.overrideWithValue(FakeArgon2id()),
        deviceNameProvider.overrideWithValue('Test'),
        vaultLifecycleProvider.overrideWithValue(VaultLifecycle.none),
      ],
    );
    await container
        .read(vaultLockControllerProvider)
        .unlock(userId: 'u_test', masterKey: crypto.generateKeyBytes());
  });

  tearDown(() async {
    container.dispose();
    await harness.close();
  });

  Future<Note> createNote() => harness.local.notes.create(
    const NoteDraft(title: 'Resumen', content: '# Hola\n\nmundo'),
  );

  test('crear guarda el enlace con su URL y el mapa del estado', () async {
    final note = await createNote();
    final result = await container
        .read(shareControllerProvider.notifier)
        .create(note.id);

    expect(result.isOk, isTrue);
    final link = container.read(shareControllerProvider).linkFor(note.id);
    expect(link, isNotNull);
    expect(link!.url, startsWith('https://apunte.app/n/'));
    expect(repo.links.containsKey(note.id), isTrue);
  });

  test('load reconstruye el enlace existente y revoke lo borra', () async {
    final note = await createNote();
    final controller = container.read(shareControllerProvider.notifier);
    await controller.create(note.id);
    final created = container.read(shareControllerProvider).linkFor(note.id)!;

    // Tras recargar, `load` recupera el enlace del servidor con la misma URL.
    final loaded = await controller.load(note.id);
    expect(loaded.isOk, isTrue);
    expect(
      container.read(shareControllerProvider).linkFor(note.id)?.url,
      created.url,
    );

    await controller.revoke(note.id);
    expect(container.read(shareControllerProvider).linkFor(note.id), isNull);
    expect(container.read(shareControllerProvider).links, isEmpty);
  });

  test('republish actualiza la copia pública con el texto actual', () async {
    final note = await createNote();
    final controller = container.read(shareControllerProvider.notifier);
    await controller.create(note.id);

    await harness.local.notes.update(
      note.id,
      const NoteDraft(title: 'Resumen 2', content: 'nuevo'),
    );
    await controller.republish(note.id);

    expect(repo.updatedPayloads, isNotEmpty);
    final stored = repo.links[note.id]!;
    final vault = container.read(vaultLockControllerProvider).vault;
    final opened = await openLinkPayload(
      await openShareKey(vault, stored),
      stored.slug,
      stored.payload,
    );
    expect(opened.title, 'Resumen 2');
    expect(opened.content, 'nuevo');
  });

  test('sin enlace, republish no toca el servidor', () async {
    final note = await createNote();
    await container.read(shareControllerProvider.notifier).republish(note.id);
    expect(repo.updatedPayloads, isEmpty);
  });

  test('sin cofre desbloqueado, crear falla con bloqueado', () async {
    final note = await createNote();
    container.read(vaultLockControllerProvider).lock();
    final result = await container
        .read(shareControllerProvider.notifier)
        .create(note.id);
    expect(result.isOk, isFalse);
    expect(container.read(shareControllerProvider).error, isA<LockedError>());
  });
}
