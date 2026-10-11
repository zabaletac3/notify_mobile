import 'dart:io';

import 'package:axonote_app/data/local/local_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el borrado por cuenta (A1) elimina la base y sus auxiliares', () async {
    final dir = Directory.systemTemp.createTempSync('axonote-wipe');
    for (final name in [
      'axonote_u1.db',
      'axonote_u1.db-wal',
      'axonote_u1.db-shm',
      'axonote_u1.db-journal',
      'axonote_u2.db',
    ]) {
      File('${dir.path}/$name').writeAsStringSync('x');
    }

    await LocalDatabase.wipe(dir, 'u1');

    for (final name in [
      'axonote_u1.db',
      'axonote_u1.db-wal',
      'axonote_u1.db-shm',
      'axonote_u1.db-journal',
    ]) {
      expect(File('${dir.path}/$name').existsSync(), isFalse, reason: name);
    }
    expect(File('${dir.path}/axonote_u2.db').existsSync(), isTrue);
    dir.deleteSync(recursive: true);
  });
}
