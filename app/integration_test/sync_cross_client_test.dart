// Prueba manual EN DISPOSITIVO de la fase 7 (plan §10, «Hecho cuando» de la fase: web y móvil
// sobre la misma cuenta en el backend local, sin pérdida de datos). No hay pantallas todavía
// (llegan en la fase 8): esta prueba conduce el móvil directamente sobre `axonote_api` +
// `axonote_crypto` + `LocalDatabase` + `SyncEngine`, sin interfaz. El procedimiento completo,
// paso a paso (incluido qué hacer en el navegador entre cada comando), está en
// `docs/guides/fase7-prueba-manual.md`: léelo antes de correr nada de esto.
//
// Cada `testWidgets` de este archivo es un paso **independiente**: se corren por separado, en
// orden, con acciones manuales en la web entre medias (la guía dice cuáles). Todos comparten la
// misma cuenta fija (ver las constantes de abajo) para que un paso pueda abrir lo que dejó el
// anterior, aunque cada `flutter test` sea un proceso nuevo en el teléfono.
//
//   adb reverse tcp:8080 tcp:8080
//   flutter test integration_test/sync_cross_client_test.dart -d $SERIE \
//     --plain-name "paso 1"
//   # … acciones en la web (ver la guía) …
//   flutter test integration_test/sync_cross_client_test.dart -d $SERIE \
//     --plain-name "paso 2"
//   # … acciones en la web …
//   flutter test integration_test/sync_cross_client_test.dart -d $SERIE \
//     --plain-name "paso 3"
import 'package:axonote_api/axonote_api.dart';
import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_app/data/local/local_account.dart';
import 'package:axonote_app/data/local/local_item_codec.dart';
import 'package:axonote_app/data/remote/remote_sync_transport.dart';
import 'package:axonote_crypto/axonote_crypto.dart' as crypto;
import 'package:axonote_domain/axonote_domain.dart';
import 'package:axonote_sync/axonote_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Cuenta fija de esta prueba manual: el correo y la contraseña hay que teclearlos también en la
/// web (misma cuenta en ambos clientes). Si repites el paso 1 con una cuenta que ya existe, el
/// registro fallará con un fallo de validación (correo repetido): la prueba lo interpreta como
/// «ya existe» y sigue con el inicio de sesión en vez de registrar otra vez.
const _email = 'axonote-fase7@example.com';
const _password = 'clave-de-prueba-fase7-AxoNote';
const _userId = '018f6f9a-7b1c-7c3e-fase-000000000777';
const _deviceId = 'd_fase7_movil';
const _deviceName = 'Móvil de prueba (fase 7)';
const _apiUrl = 'http://localhost:8080/v1';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('paso 1 · crea la cuenta (si falta) y sube la primera nota', (
    tester,
  ) async {
    final sodium = await crypto.SodiumArgon2id.load();
    final tokens = MemoryTokenStore();
    final http = HttpClient(HttpClientOptions(baseUrl: _apiUrl, tokens: tokens));
    final auth = AuthApi(http, deviceName: _deviceName);
    final account = AccountApi(http);

    crypto.SecretKeyBytes masterKey;
    try {
      // ¿Ya existe la cuenta? Si el correo no está registrado, esto falla (not-found/unauthorized)
      // y se sigue con el registro de abajo.
      final kdf = await auth.prelogin(_email);
      final derived = await crypto.deriveFromPassword(_password, kdf, sodium);
      final loginResult = await auth.login(_email, derived.authKey);
      expect(
        loginResult,
        isA<LoginSession>(),
        reason: 'esta cuenta no debería tener verificación en dos pasos',
      );
      final bundle = await account.keys();
      final unlocked = await crypto.unlockWithPassword(
        password: _password,
        userId: _userId,
        keys: KeyBundle(
          kdf: KdfParams(
            alg: bundle.kdf.alg,
            memoryKiB: bundle.kdf.memoryKiB,
            iterations: bundle.kdf.iterations,
            parallelism: bundle.kdf.parallelism,
            salt: bundle.kdf.salt,
          ),
          wrappedMasterKey: bundle.wrappedMasterKey,
          recoveryWrappedMasterKey: bundle.recoveryWrappedMasterKey,
          keysVersion: bundle.keysVersion,
        ),
        argon2id: sodium,
      );
      masterKey = unlocked.masterKey;
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      final created = await crypto.createAccountKeys(
        password: _password,
        userId: _userId,
        argon2id: sodium,
        kdfBase: crypto.lightKdf,
      );
      await auth.register(
        RegisterRequestDto(
          userId: _userId,
          fullName: 'Prueba cruzada fase 7',
          email: _email,
          acceptedTerms: true,
          authKey: created.authKey,
          recoveryAuth: created.recoveryAuth,
          keys: KeyBundleDto(
            kdf: KdfParamsDto(
              alg: created.keys.kdf.alg,
              memoryKiB: created.keys.kdf.memoryKiB,
              iterations: created.keys.kdf.iterations,
              parallelism: created.keys.kdf.parallelism,
              salt: created.keys.kdf.salt,
            ),
            wrappedMasterKey: created.keys.wrappedMasterKey,
            recoveryWrappedMasterKey: created.keys.recoveryWrappedMasterKey,
            keysVersion: created.keys.keysVersion,
          ),
        ),
      );
      // ignore: avoid_print
      print(
        'Lee el código de verificación en la terminal del backend (make run, '
        'MAIL_PROVIDER=log) y vuelve a correr este mismo paso: con la cuenta ya registrada, '
        'la próxima vez entra por el camino de inicio de sesión de arriba.\n'
        'Si prefieres no reintentar, verifica a mano con curl/httpie contra '
        'POST $_apiUrl/auth/verify-email antes de seguir con el paso 2.',
      );
      masterKey = created.masterKey;
    }

    final dir = await getApplicationSupportDirectory();
    await LocalDatabase.wipe(dir, _userId);
    final vault = Vault(userId: _userId)..unlockWith(masterKey);
    final local = await LocalDatabase.open(
      directory: dir,
      userId: _userId,
      vault: vault,
      deviceId: _deviceId,
      deviceName: _deviceName,
    );

    final note = await local.notes.create(
      const NoteDraft(
        title: 'Nota desde el móvil',
        content: 'Creada en el paso 1 de la prueba cruzada de la fase 7.',
      ),
    );

    final engine = SyncEngine(
      store: local.syncStore,
      transport: RemoteSyncTransport(
        SyncApi(http),
        deviceId: _deviceId,
        deviceName: _deviceName,
      ),
      codec: LocalItemCodec(local.deps),
    );
    await engine.syncNow();

    // ignore: avoid_print
    print(
      'Cuenta: $_email / $_password\n'
      'Nota creada: ${note.id} — ábrela ahora en la web con esta misma cuenta.',
    );

    expect(await local.syncStore.pendingCount(), 0);
    await local.close();
  });

  testWidgets(
    'paso 2 · baja lo editado en la web y comprueba un conflicto',
    (tester) async {
      final engine = await _reopenAndSync();
      // En este punto la guía ya pidió editar «Nota desde el móvil» en la web (sube a
      // revisión 1) y crear una nota nueva allí: una segunda sincronización debe traer las dos
      // cosas.
      final notes = await engine.local.notes.list();
      expect(
        notes.length,
        greaterThanOrEqualTo(2),
        reason: 'debería haber bajado también la nota creada en la web',
      );

      // Conflicto en los dos sentidos: se edita aquí SIN sincronizar — la guía ya pidió editar la
      // misma nota en la web también, sin que este paso haya sincronizado entre medias.
      final shared = notes.firstWhere((n) => n.title == 'Nota desde el móvil');
      await engine.local.notes.update(
        shared.id,
        const NoteDraft(content: 'Editada en el móvil, sin sincronizar antes.'),
      );
      await engine.syncEngine.syncNow();

      final snapshot = await engine.syncEngine.snapshot();
      expect(
        snapshot.conflicts,
        isNotEmpty,
        reason:
            'si la web no editó la misma nota antes de este paso, no habrá conflicto: repite '
            'el paso 2 después de editarla en la web (ver la guía)',
      );
      final conflict = snapshot.conflicts.first;
      // ignore: avoid_print
      print(
        'Conflicto detectado en ${conflict.noteId}.\n'
        'Local (este móvil): «${conflict.local.content}»\n'
        'Remoto (la web): «${conflict.remote.content}»',
      );

      await engine.syncEngine.resolveConflict(
        conflict.noteId,
        ConflictResolution.both,
      );
      await engine.syncEngine.syncNow();
      expect((await engine.syncEngine.snapshot()).conflicts, isEmpty);

      await engine.local.close();
    },
  );

  testWidgets('paso 3 · papelera y borrado se reflejan en los dos sentidos', (
    tester,
  ) async {
    final engine = await _reopenAndSync();
    final active = await engine.local.notes.list();
    final toTrash = active.first;
    await engine.local.notes.moveToTrash(toTrash.id);
    await engine.syncEngine.syncNow();

    // ignore: avoid_print
    print(
      'Movida a la papelera desde el móvil: ${toTrash.id}. Compruébalo en la web y, allí, '
      'borra definitivamente otra nota distinta; luego vuelve a correr este mismo paso para '
      'comprobar que el móvil también la borra al sincronizar.',
    );

    await engine.syncEngine.syncNow();
    await engine.local.close();
  });
}

class _ReopenedEngine {
  _ReopenedEngine(this.local, this.syncEngine);

  final LocalDatabase local;
  final SyncEngine syncEngine;
}

Future<_ReopenedEngine> _reopenAndSync() async {
  final sodium = await crypto.SodiumArgon2id.load();
  final tokens = MemoryTokenStore();
  final http = HttpClient(HttpClientOptions(baseUrl: _apiUrl, tokens: tokens));
  final auth = AuthApi(http, deviceName: _deviceName);
  final account = AccountApi(http);

  final kdf = await auth.prelogin(_email);
  final derived = await crypto.deriveFromPassword(_password, kdf, sodium);
  final loginResult = await auth.login(_email, derived.authKey);
  if (loginResult is! LoginSession) {
    throw StateError('la cuenta de prueba no debería pedir segundo paso');
  }
  final bundle = await account.keys();
  final unlocked = await crypto.unlockWithPassword(
    password: _password,
    userId: _userId,
    keys: KeyBundle(
      kdf: KdfParams(
        alg: bundle.kdf.alg,
        memoryKiB: bundle.kdf.memoryKiB,
        iterations: bundle.kdf.iterations,
        parallelism: bundle.kdf.parallelism,
        salt: bundle.kdf.salt,
      ),
      wrappedMasterKey: bundle.wrappedMasterKey,
      recoveryWrappedMasterKey: bundle.recoveryWrappedMasterKey,
      keysVersion: bundle.keysVersion,
    ),
    argon2id: sodium,
  );

  final dir = await getApplicationSupportDirectory();
  final vault = Vault(userId: _userId)..unlockWith(unlocked.masterKey);
  final local = await LocalDatabase.open(
    directory: dir,
    userId: _userId,
    vault: vault,
    deviceId: _deviceId,
    deviceName: _deviceName,
  );
  final engine = SyncEngine(
    store: local.syncStore,
    transport: RemoteSyncTransport(
      SyncApi(http),
      deviceId: _deviceId,
      deviceName: _deviceName,
    ),
    codec: LocalItemCodec(local.deps),
  );
  await engine.syncNow();
  return _ReopenedEngine(local, engine);
}
