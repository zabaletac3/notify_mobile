import 'dart:convert';
import 'dart:io';

import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_app/data/local/app_database.dart';
import 'package:axonote_app/data/local/local_account.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la base de la cuenta no se abre sin la clave ni con otra', () async {
    final dir = Directory.systemTemp.createTempSync('axonote-enc');
    final master = generateKeyBytes();
    final vault = Vault(userId: 'u1')..unlockWith(master);

    final local = await LocalDatabase.open(
      directory: dir,
      userId: 'u1',
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

    final path = '${dir.path}/axonote_u1.db';
    final file = File(path);
    expect(file.existsSync(), isTrue);
    // El archivo está cifrado: el contenido en claro no aparece en los bytes.
    final raw = utf8.decode(file.readAsBytesSync(), allowMalformed: true);
    expect(raw, isNot(contains('tortuga-azul-42')));
    expect(raw, isNot(contains('Contraseñas del banco')));

    // Sin clave: no se puede consultar (el archivo está cifrado).
    final noKey = AppDatabase(NativeDatabase(file));
    await expectLater(
      noKey.customSelect('SELECT count(*) FROM notes').get(),
      throwsA(anything),
    );
    await noKey.close();

    // Con otra clave: falla al abrir, con un fallo de la aplicación tipado.
    final wrongVault = Vault(userId: 'u1')..unlockWith(generateKeyBytes());
    await expectLater(
      LocalDatabase.open(
        directory: dir,
        userId: 'u1',
        vault: wrongVault,
        deviceId: 'd1',
      ),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', 'decrypt')),
    );

    // Con la clave correcta: se lee.
    final correctVault = Vault(userId: 'u1')..unlockWith(master);
    final reopened = await LocalDatabase.open(
      directory: dir,
      userId: 'u1',
      vault: correctVault,
      deviceId: 'd1',
    );
    final notes = await reopened.notes.list();
    final full = await reopened.notes.get(notes.single.id);
    expect(full.title, 'Contraseñas del banco');
    expect(full.content, 'tortuga-azul-42');
    await reopened.close();

    dir.deleteSync(recursive: true);
  });

  test('sin el cofre desbloqueado no se puede abrir la base', () async {
    final dir = Directory.systemTemp.createTempSync('axonote-locked');
    final locked = Vault(userId: 'u1');
    await expectLater(
      LocalDatabase.open(
        directory: dir,
        userId: 'u1',
        vault: locked,
        deviceId: 'd1',
      ),
      throwsA(isA<AppFailure>().having((e) => e.kind, 'kind', 'locked')),
    );
    dir.deleteSync(recursive: true);
  });
}
