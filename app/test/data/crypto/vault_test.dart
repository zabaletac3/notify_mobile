import 'dart:typed_data';

import 'package:axonote_app/data/crypto/vault.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// 32 bytes rellenos de `fill` (distintos valores → claves distintas y comparables).
SecretKeyBytes _key([int fill = 1]) =>
    SecretKeyBytes(Uint8List.fromList(List.filled(32, fill)));

void main() {
  const userId = 'u1';

  test('recién creado está bloqueado', () {
    final vault = Vault(userId: userId);
    expect(vault.isUnlocked, isFalse);
    expect(() => vault.requireKey(), throwsA(isA<VaultLockedError>()));
  });

  test('unlockWith lo desbloquea', () {
    final vault = Vault(userId: userId);
    vault.unlockWith(_key());
    expect(vault.isUnlocked, isTrue);
    expect(() => vault.requireKey(), returnsNormally);
  });

  test('lock borra la clave maestra de memoria', () {
    final vault = Vault(userId: userId);
    final master = _key();
    vault.unlockWith(master);
    vault.lock();
    expect(vault.isUnlocked, isFalse);
    expect(master.isDisposed, isTrue);
    expect(() => vault.requireKey(), throwsA(isA<VaultLockedError>()));
  });

  test('dataAad y keyAad ligan el AAD a la cuenta, el tipo y el id', () {
    final vault = Vault(userId: userId);
    expect(
      vault.dataAad(ItemEntity.note, 'n1'),
      'apunte/v1/data/u1/note/n1',
    );
    expect(
      vault.keyAad(ItemEntity.folder, 'f1'),
      'apunte/v1/key/u1/folder/f1',
    );
  });

  test('localDbKey lanza VaultLockedError si está bloqueado', () {
    final vault = Vault(userId: userId);
    expect(() => vault.localDbKey(), throwsA(isA<VaultLockedError>()));
  });

  test('localDbKey es determinista para la misma cuenta', () async {
    final a = Vault(userId: userId)..unlockWith(_key(7));
    final b = Vault(userId: userId)..unlockWith(_key(7));
    final keyA = await a.localDbKey();
    final keyB = await b.localDbKey();
    expect(keyA.bytes, equals(keyB.bytes));
  });

  group('claves de elemento', () {
    late Vault vault;

    setUp(() {
      vault = Vault(userId: userId)..unlockWith(_key());
    });

    test('newItemKey lanza si está bloqueado', () async {
      final locked = Vault(userId: userId);
      await expectLater(
        locked.newItemKey(ItemEntity.note, 'n1'),
        throwsA(isA<VaultLockedError>()),
      );
    });

    test('newItemKey produce una clave desenvolvible con itemKey', () async {
      final created = await vault.newItemKey(ItemEntity.note, 'n1');
      final loaded = await vault.itemKey(
        ItemEntity.note,
        'n1',
        created.wrapped,
      );
      expect(loaded.bytes, equals(created.key.bytes));
    });

    test('itemKey reutiliza la caché en vez de desenvolver de nuevo', () async {
      final created = await vault.newItemKey(ItemEntity.note, 'n1');
      final first = await vault.itemKey(ItemEntity.note, 'n1', created.wrapped);
      final second = await vault.itemKey(ItemEntity.note, 'n1', created.wrapped);
      expect(identical(first, second), isTrue);
    });

    test('itemKey con un wrapped de otra cuenta no corresponde (DecryptError)', () async {
      final created = await vault.newItemKey(ItemEntity.note, 'n1');
      final other = Vault(userId: 'otra-cuenta')..unlockWith(_key());
      await expectLater(
        other.itemKey(ItemEntity.note, 'n1', created.wrapped),
        throwsA(isA<DecryptError>()),
      );
    });

    test('rotateItemKey da una clave distinta de la anterior', () async {
      final first = await vault.newItemKey(ItemEntity.note, 'n1');
      final rotated = await vault.rotateItemKey(ItemEntity.note, 'n1');
      expect(rotated.wrapped, isNot(first.wrapped));
      expect(rotated.key.bytes, isNot(equals(first.key.bytes)));
    });

    test('lock() también borra las claves de elemento en caché', () async {
      final created = await vault.newItemKey(ItemEntity.note, 'n1');
      vault.lock();
      expect(created.key.isDisposed, isTrue);
    });
  });
}
