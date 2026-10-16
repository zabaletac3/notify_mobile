import 'package:axonote_app/app/local_session.dart';
import 'package:axonote_app/bootstrap/providers.dart';
import 'package:axonote_app/features/auth/state/vault_lifecycle.dart';
import 'package:axonote_app/features/notes/ui/notes_screen.dart';
import 'package:axonote_app/features/share/state/share_controller.dart';
import 'package:axonote_app/features/vault/state/clock.dart';
import 'package:axonote_app/features/vault/state/timer_factory.dart';
import 'package:axonote_app/features/vault/state/vault_lock.dart';
import 'package:axonote_app/ui/components.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_platform/axonote_platform.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/local/local_harness.dart';
import '../auth/support/fakes.dart';
import '../notes/support/notes_harness.dart'
    show NotesHarness, baseNow, loadInter, notesGolden;

/// Hoja «Compartir nota» (tablero «Android — Compartir nota»), con enlace activo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadInter);

  testWidgets('hoja compartir nota', (t) async {
    await notesGolden(
      t,
      'share',
      _harness,
      (_) => const NotesScreen(),
      afterPump: (tester, _) async {
        await tester.longPress(
          find.byWidgetPredicate(
            (w) => w is AxoNoteCard && w.title == 'Resumen: Bases de datos II',
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Compartir'));
        await tester.pumpAndSettle();
      },
    );
  });
}

Future<NotesHarness> _harness() async {
  AxonotePlatform.instance = FakeAxonotePlatform();
  final clock = FakeClock(baseNow);
  final local = LocalHarness(now: () => clock.now(), deviceId: 'd_test');
  final noteId = await _seed(local, clock);
  final link = ShareLink(
    id: 's1',
    noteId: noteId,
    url: 'https://apunte.app/n/8f3k2dq7#k=AAAABBBBCCCCDDDDEEEEFFFFGGGGHHHHIIIIJJJJK',
    createdAt: DateTime.utc(2026, 10, 15, 9),
  );
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      noteRepositoryProvider.overrideWithValue(local.local.notes),
      folderRepositoryProvider.overrideWithValue(local.local.folders),
      clockProvider.overrideWithValue(clock),
      vaultTimerFactoryProvider.overrideWithValue(FakeTimerFactory(clock)),
      vaultLifecycleProvider.overrideWithValue(VaultLifecycle.none),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      vaultPrefsProvider.overrideWithValue(FakeVaultPrefs()),
      argon2idProvider.overrideWithValue(FakeArgon2id()),
      deviceNameProvider.overrideWithValue('Test'),
      localDataCleanerProvider.overrideWithValue(FakeCleaner()),
      shareControllerProvider.overrideWith(() => _StubShareController(link)),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(local.close);
  return NotesHarness(local, clock, container, const {});
}

/// Controlador de enlaces con un enlace fijo, sin vault ni red.
class _StubShareController extends ShareController {
  _StubShareController(this.link);

  final ShareLink link;

  @override
  ShareState build() => ShareState(links: {link.noteId: link});

  @override
  Future<Result<ShareLink?>> load(Id noteId) async => Ok(link);

  @override
  Future<Result<ShareLink>> create(Id noteId) async => Ok(link);

  @override
  Future<Result<void>> revoke(Id noteId) async => const Ok(null);
}

Future<Id> _seed(LocalHarness local, FakeClock clock) async {
  clock.set(DateTime(2026, 10, 14, 9, 12));
  final note = await local.local.notes.create(
    const NoteDraft(
      title: 'Resumen: Bases de datos II',
      content: 'Normalización hasta 3FN, ejemplos con la tabla de pedidos.',
    ),
  );
  clock.set(baseNow);
  return note.id;
}
