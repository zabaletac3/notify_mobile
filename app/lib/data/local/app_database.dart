import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:meta/meta.dart';
import 'package:sqlite3/sqlite3.dart';

import 'schema.dart';

/// Base de datos local de una cuenta (plan §6, D3/D10).
///
/// Toda la base está cifrada con SQLite3MultipleCiphers; dentro, el contenido va en claro para
/// poder indexarlo con FTS5. Se abre siempre con la clave derivada de la clave maestra
/// (`Vault.localDbKey`, A1/A2); sin ella el archivo no se puede leer.
///
/// El esquema se construye con SQL explícito ([schemaV1]) en vez de tablas generadas: así la
/// forma es exactamente la de la §6 y las versiones de migración son explícitas.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);

  /// Base de datos en memoria, **sin cifrar**: solo para pruebas y datos de ejemplo.
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  /// Base de datos sobre un archivo ya abierto (lo usa el código nativo de la app).
  factory AppDatabase.opened(QueryExecutor executor) => AppDatabase(executor);

  /// Abre (o crea) la base cifrada de una cuenta en [file]. [key] son los 32 bytes de
  /// `Vault.localDbKey()`; se pasan a SQLite3MultipleCiphers como clave cruda. La clave **nunca**
  /// se escribe en logs ni en disco.
  static AppDatabase openEncrypted({
    required File file,
    required Uint8List key,
  }) {
    final hex = _toHex(key);
    return AppDatabase(
      NativeDatabase.createInBackground(
        file,
        setup: (Database db) {
          db.execute('PRAGMA key = "x\'$hex\'"');
        },
      ),
    );
  }

  @override
  int get schemaVersion => 1;

  /// No usamos tablas generadas por drift, así que no hay entidades que registrar.
  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) => _migrate(0, schemaVersion),
      onUpgrade: (m, from, to) => _migrate(from, to),
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
        if (!details.wasCreated) {
          await customStatement('PRAGMA journal_mode = WAL');
        }
      },
    );
  }

  Future<void> _migrate(int from, int to) async {
    for (final statement in migrationStatements(from, to)) {
      await customStatement(statement);
    }
  }

  /// Expuesto para la prueba de migración: aplica los pasos de una versión concreta sobre una
  /// base ya abierta (normalmente una recién creada y vacía, con `PRAGMA user_version = 0`).
  @visibleForTesting
  Future<void> migrateFrom(int from, int to) => _migrate(from, to);

  static String _toHex(Uint8List bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
