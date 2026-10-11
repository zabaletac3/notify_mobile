import 'package:axonote_app/data/secure/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FakeSecureStore: write → read → delete', () async {
    final store = FakeSecureStore();
    expect(await store.read('a'), isNull);
    await store.write('a', '1');
    expect(await store.read('a'), '1');
    await store.delete('a');
    expect(await store.read('a'), isNull);
  });

  test(
    'FakeSecureStore.deleteWhere borra solo lo que cumple el filtro',
    () async {
      final store = FakeSecureStore();
      await store.write('lockPrefs.u1', 'x');
      await store.write('lockPrefs.u2', 'y');
      await store.write('session.userId', 'u1');
      await store.deleteWhere((key) => key.startsWith('lockPrefs.'));
      expect(await store.read('lockPrefs.u1'), isNull);
      expect(await store.read('lockPrefs.u2'), isNull);
      expect(await store.read('session.userId'), 'u1');
    },
  );
}
