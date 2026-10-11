// Prueba EN DISPOSITIVO (ZTE) del cifrado de la base local (plan §6, D3): en Android se enlaza la
// librería nativa de verdad (libsqlite3mc.so), así que aquí se comprueba que el archivo no se abre
// sin la clave ni con otra y que los bytes no contienen el texto en claro. Misma prueba que
// `app/test/data/local/local_encryption_test.dart`, pero con la librería nativa real.
//
//   flutter test integration_test/local_encryption_device_test.dart -d LZ0V50COPBC002769
import 'dart:convert';
import 'dart:io';

import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_app/data/local/local_account.dart';
import 'package:axonote_app/data/local/schema.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la base cifrada no se abre sin la clave ni con otra', (
    tester,
  ) async {
    final dir = await getApplicationSupportDirectory();
    const userId = 'enc_device';
    await LocalDatabase.wipe(dir, userId);
    final master = generateKeyBytes();
    final vault = Vault(userId: userId)..unlockWith(master);

    final local = await LocalDatabase.open(
      directory: dir,
      userId: userId,
      vault: vault,
      deviceId: 'd1',
    );
    await local.notes.create(
      const NoteDraft(
        title: 'Contraseñas del banco',
        content: 'tortuga-azul-42',
      ),
    );
    await local.close();

    final file = File('${dir.path}/${databaseFileName(userId)}');
    expect(file.existsSync(), isTrue);
    final raw = utf8.decode(file.readAsBytesSync(), allowMalformed: true);
    expect(raw, isNot(contains('tortuga-azul-42')));
    expect(raw, isNot(contains('Contraseñas del banco')));

    // Con otra clave: falla al abrir con un fallo de la aplicación tipado.
    final wrong = Vault(userId: userId)..unlockWith(generateKeyBytes());
    await expectLater(
      LocalDatabase.open(
        directory: dir,
        userId: userId,
        vault: wrong,
        deviceId: 'd1',
      ),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', 'decrypt')),
    );

    // Con la clave correcta: se lee.
    final again = Vault(userId: userId)..unlockWith(master);
    final reopened = await LocalDatabase.open(
      directory: dir,
      userId: userId,
      vault: again,
      deviceId: 'd1',
    );
    final notes = await reopened.notes.list();
    final full = await reopened.notes.get(notes.single.id);
    expect(full.title, 'Contraseñas del banco');
    expect(full.content, 'tortuga-azul-42');
    await reopened.close();

    await LocalDatabase.wipe(dir, userId);
  });
}
