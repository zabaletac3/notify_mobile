/// Esquema de la base local (plan §6) y sus pasos de migración.
///
/// La base entera está cifrada con SQLite3MultipleCiphers (D3); dentro, el contenido va en claro
/// (columnas `title`, `content`, `preview`, `tags_json`) y el índice FTS5 (`notes_fts`) lo indexa.
/// La `wrapped_key` se guarda para reutilizar la clave del elemento al subir (A5) y
/// `raw_payload`/`unreadable` para las filas que no se pudieron descifrar (A6).
///
/// Las fechas son **texto ISO 8601 UTC con milisegundos**, idénticas a las del contrato: nunca se
/// convierten a entero ni a `DateTime` para guardarlas.
library;

/// Nombre del archivo de base por cuenta (A1): `axonote_<userId>.db`.
String databaseFileName(String userId) => 'axonote_$userId.db';

/// Tablas, índices y disparadores de la versión 1 (una sentencia por elemento).
const List<String> schemaV1 = [
  '''
  CREATE TABLE notes(
    id TEXT NOT NULL PRIMARY KEY,
    folder_id TEXT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    preview TEXT NOT NULL,
    tags_json TEXT NOT NULL,
    pinned INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    deleted_at TEXT,
    revision INTEGER NOT NULL,
    sync_status TEXT NOT NULL,
    last_edited_device_id TEXT NOT NULL,
    wrapped_key TEXT NOT NULL,
    unreadable INTEGER NOT NULL DEFAULT 0,
    raw_payload TEXT
  )
  ''',
  'CREATE INDEX notes_deleted_pinned_updated ON notes(deleted_at, pinned, updated_at)',
  'CREATE INDEX notes_folder_deleted ON notes(folder_id, deleted_at)',
  // Índice añadido en la fase 6 para la lista inicial ordenada por `updated_at` sin límite de
  // materialización (plan §11): el índice de la §6 tiene `pinned` entre medias y no sirve para
  // `WHERE deleted_at IS NULL ORDER BY updated_at DESC`. Ver docs/decisions.md.
  'CREATE INDEX notes_deleted_updated ON notes(deleted_at, updated_at)',
  '''
  CREATE TABLE note_tags(
    note_id TEXT NOT NULL,
    tag TEXT NOT NULL,
    PRIMARY KEY(note_id, tag)
  )
  ''',
  'CREATE INDEX note_tags_tag ON note_tags(tag)',
  '''
  CREATE TABLE folders(
    id TEXT NOT NULL PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    revision INTEGER NOT NULL,
    wrapped_key TEXT NOT NULL,
    unreadable INTEGER NOT NULL DEFAULT 0,
    raw_payload TEXT
  )
  ''',
  '''
  CREATE TABLE outbox(
    seq INTEGER PRIMARY KEY AUTOINCREMENT,
    entity TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    op TEXT NOT NULL,
    base_revision INTEGER NOT NULL,
    version INTEGER NOT NULL,
    changed_at TEXT NOT NULL,
    UNIQUE(entity, entity_id)
  )
  ''',
  '''
  CREATE TABLE conflicts(
    note_id TEXT NOT NULL PRIMARY KEY,
    remote_json TEXT NOT NULL,
    remote_wrapped_key TEXT NOT NULL,
    remote_revision INTEGER NOT NULL,
    remote_device_name TEXT NOT NULL,
    detected_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE shares(
    note_id TEXT NOT NULL PRIMARY KEY,
    slug TEXT NOT NULL,
    wrapped_share_key TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE meta(
    key TEXT NOT NULL PRIMARY KEY,
    value TEXT
  )
  ''',
  // FTS5 de contenido externo sobre notes(title, content, tags_json). El tokenizador
  // `unicode61 remove_diacritics 2` da búsquedas insensibles a tildes (A7).
  '''
  CREATE VIRTUAL TABLE notes_fts USING fts5(
    title, content, tags_json,
    content='notes', content_rowid='rowid',
    tokenize='unicode61 remove_diacritics 2'
  )
  ''',
  '''
  CREATE TRIGGER notes_ai AFTER INSERT ON notes BEGIN
    INSERT INTO notes_fts(rowid, title, content, tags_json)
    VALUES (new.rowid, new.title, new.content, new.tags_json);
  END
  ''',
  '''
  CREATE TRIGGER notes_ad AFTER DELETE ON notes BEGIN
    INSERT INTO notes_fts(notes_fts, rowid, title, content, tags_json)
    VALUES ('delete', old.rowid, old.title, old.content, old.tags_json);
  END
  ''',
  '''
  CREATE TRIGGER notes_au AFTER UPDATE ON notes BEGIN
    INSERT INTO notes_fts(notes_fts, rowid, title, content, tags_json)
    VALUES ('delete', old.rowid, old.title, old.content, old.tags_json);
    INSERT INTO notes_fts(rowid, title, content, tags_json)
    VALUES (new.rowid, new.title, new.content, new.tags_json);
  END
  ''',
];

/// Aplica los pasos de migración desde [fromVersion] hasta [toVersion], uno por versión.
/// La versión 1 crea todo el esquema. Las versiones futuras añaden su paso aquí.
List<String> migrationStatements(int fromVersion, int toVersion) {
  final statements = <String>[];
  for (var version = fromVersion + 1; version <= toVersion; version++) {
    switch (version) {
      case 1:
        statements.addAll(schemaV1);
      default:
        throw StateError('No hay migración definida para la versión $version');
    }
  }
  return statements;
}
