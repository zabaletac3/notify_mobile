import 'dart:io';

import 'package:axonote_app/data/local/app_database.dart';
import 'package:axonote_app/data/local/schema.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

Future<Set<String>> _objectNames(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
      )
      .get();
  return {for (final row in rows) row.read<String>('name')};
}

Future<String> _userVersion(AppDatabase db) async {
  final rows = await db.customSelect('PRAGMA user_version').get();
  return rows.first.data.values.first.toString();
}

Future<void> _open(AppDatabase db) => db.customSelect('SELECT 1').get();

void main() {
  test('la versión 1 crea el esquema completo (tablas, FTS, índices y disparadores)', () async {
    final db = AppDatabase.memory();
    await _open(db);
    final names = await _objectNames(db);
    for (final expected in [
      'notes',
      'note_tags',
      'folders',
      'outbox',
      'conflicts',
      'shares',
      'meta',
      'notes_fts',
      'notes_deleted_pinned_updated',
      'notes_folder_deleted',
      'notes_deleted_updated',
      'note_tags_tag',
      'notes_ai',
      'notes_ad',
      'notes_au',
    ]) {
      expect(names, contains(expected), reason: 'falta $expected');
    }
    expect(await _userVersion(db), '1');
    await db.close();
  });

  test('los pasos de migración son explícitos y por versión', () {
    expect(migrationStatements(0, 1), equals(schemaV1));
    expect(migrationStatements(1, 1), isEmpty);
    expect(migrationStatements(1, 1), isEmpty);
    expect(() => migrationStatements(1, 2), throwsStateError);
    expect(() => migrationStatements(0, 3), throwsStateError);
  });

  test(
    'los disparadores mantienen notes_fts al día (external content)',
    () async {
      final db = AppDatabase.memory();
      await _open(db);
      await db.customStatement(
        "INSERT INTO notes(id, title, content, preview, tags_json, created_at, updated_at, "
        "revision, sync_status, last_edited_device_id, wrapped_key) "
        "VALUES ('a', 'Apuntes', 'cuerpo acuatico', '', '[\"mar\"]', 't', 't', 0, 'pending', 'd', 'w')",
      );
      Future<int> matches(String term) async {
        final rows = await db
            .customSelect(
              "SELECT rowid FROM notes_fts WHERE notes_fts MATCH ?",
              variables: [Variable<String>(term)],
            )
            .get();
        return rows.length;
      }

      expect(await matches('acuatico'), 1);

      await db.customStatement(
        "UPDATE notes SET content = 'otra cosa' WHERE id = 'a'",
      );
      expect(await matches('acuatico'), 0);
      expect(await matches('otra'), 1);

      await db.customStatement("DELETE FROM notes WHERE id = 'a'");
      expect(await matches('otra'), 0);
      await db.close();
    },
  );

  test(
    'reabrir la misma base no la vuelve a crear y conserva los datos',
    () async {
      final dir = Directory.systemTemp.createTempSync('axonote-mig');
      final path = '${dir.path}/plain.db';
      var db = AppDatabase(NativeDatabase(File(path)));
      await _open(db);
      await db.customStatement(
        "INSERT INTO meta(key, value) VALUES ('cursor', '7')",
      );
      final version = await _userVersion(db);
      await db.close();

      db = AppDatabase(NativeDatabase(File(path)));
      await _open(db);
      final rows = await db
          .customSelect("SELECT value FROM meta WHERE key = 'cursor'")
          .get();
      expect(rows.first.read<String>('value'), '7');
      expect(await _userVersion(db), version);
      await db.close();
      dir.deleteSync(recursive: true);
    },
  );

  test(
    'el esquema SQL de la versión 1 se puede aplicar sobre una base cruda',
    () {
      final raw = sqlite3.sqlite3.openInMemory();
      for (final statement in migrationStatements(0, 1)) {
        raw.execute(statement);
      }
      final names = raw
          .select(
            "SELECT name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
          )
          .map((row) => row['name'] as String)
          .toSet();
      expect(
        names,
        containsAll(['notes', 'notes_fts', 'outbox', 'conflicts', 'shares']),
      );
      raw.close();
    },
  );
}
