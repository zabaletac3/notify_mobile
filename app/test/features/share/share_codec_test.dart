import 'package:axonote_app/data/crypto/share_codec.dart';
import 'package:axonote_crypto/axonote_crypto.dart';
import 'package:axonote_domain/axonote_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../data/local/local_harness.dart';
import 'support/fake_share_repository.dart';

void main() {
  test('ida y vuelta: crear, reconstruir URL y actualizar la copia', () async {
    final vault = testVault();
    final repo = FakeShareRepository();

    final input = await createShare(
      vault,
      noteId: 'n1',
      title: 'Resumen',
      content: '# Hola\n\nmundo',
    );
    expect(isValidSlug(input.slug), isTrue);

    final stored = await repo.createLink('n1', input);
    final key = await openShareKey(vault, stored);
    final url = shareUrl('https://apunte.app', stored, key);
    expect(url, startsWith('https://apunte.app/n/'));
    expect(shareKeyFromFragment(url.split('#').last), isNotNull);

    // La URL completa (con el fragmento) abre la copia.
    final opened = await openSharedNote(
      stored.slug,
      url.split('#').last,
      stored.payload,
      stored.updatedAt,
    );
    expect(opened.title, 'Resumen');
    expect(opened.content, '# Hola\n\nmundo');

    // Al guardar la nota, la copia pública se actualiza y se vuelve a abrir con el texto nuevo.
    final updated = await sealSharedNote(
      key,
      stored.slug,
      title: 'Resumen 2',
      content: 'nuevo',
    );
    final reopened = await openSharedNote(
      stored.slug,
      url.split('#').last,
      updated,
      stored.updatedAt,
    );
    expect(reopened.title, 'Resumen 2');
    expect(reopened.content, 'nuevo');
  });

  test('una clave ajena no abre la copia', () async {
    final vault = testVault();
    final input = await createShare(
      vault,
      noteId: 'n1',
      title: 'T',
      content: 'C',
    );
    final other = testVault();
    final stored = SharedNote(
      id: 's',
      noteId: 'n1',
      slug: input.slug,
      wrappedShareKey: input.wrappedShareKey,
      payload: input.payload,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    // Con la maestra equivocada, ni siquiera se puede desenvolver la clave del enlace.
    await expectLater(openShareKey(other, stored), throwsA(anything));
  });
}
