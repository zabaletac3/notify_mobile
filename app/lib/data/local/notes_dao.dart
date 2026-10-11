import 'package:axonote_domain/axonote_domain.dart';
import 'package:drift/drift.dart';

import 'app_database.dart';
import 'rows.dart';

/// DAO de la tabla `notes` y su índice FTS5. El contenido va en claro dentro de la base cifrada;
/// los disparadores mantienen `notes_fts` al día (plan §6).
class NotesDao {
  NotesDao(this._db);

  final AppDatabase _db;

  static const List<String> _columns = [
    'id',
    'folder_id',
    'title',
    'content',
    'preview',
    'tags_json',
    'pinned',
    'created_at',
    'updated_at',
    'deleted_at',
    'revision',
    'sync_status',
    'last_edited_device_id',
    'wrapped_key',
    'unreadable',
    'raw_payload',
  ];

  /// Columnas de lista: igual que [_columns] pero sin `content` (plan §4.4: consultas ligeras
  /// para la lista; el cuerpo solo se lee al abrir una nota).
  static const List<String> _summaryColumns = [
    'id',
    'folder_id',
    'title',
    'preview',
    'tags_json',
    'pinned',
    'created_at',
    'updated_at',
    'deleted_at',
    'revision',
    'sync_status',
    'last_edited_device_id',
    'wrapped_key',
    'unreadable',
    'raw_payload',
  ];

  String get _selectColumns => _columns.join(', ');

  /// Consulta de la lista: filtro, orden y página, todo en SQL. Devuelve resúmenes (sin `content`).
  Future<List<NoteRow>> query(NoteQuery query) {
    final filter = query.filter ?? const NotesFilterAll();
    final where = <String>[];
    final variables = <Variable>[];
    switch (filter) {
      case NotesFilterTrash():
        where.add('n.deleted_at IS NOT NULL');
      case NotesFilterPinned():
        where
          ..add('n.deleted_at IS NULL')
          ..add('n.pinned = 1');
      case NotesFilterFolder(folderId: final folderId):
        where
          ..add('n.deleted_at IS NULL')
          ..add('n.folder_id IS ?');
        variables.add(Variable<String>(folderId));
      case NotesFilterTag(tag: final tag):
        where
          ..add('n.deleted_at IS NULL')
          ..add('n.id IN (SELECT note_id FROM note_tags WHERE tag = ?)');
        variables.add(Variable<String>(tag));
      case NotesFilterAll():
        where.add('n.deleted_at IS NULL');
    }
    final order = switch (query.sort ?? NoteSort.updated) {
      NoteSort.updated => 'n.updated_at DESC',
      NoteSort.created => 'n.created_at DESC',
      NoteSort.title => 'n.title COLLATE NOCASE ASC',
    };
    var sql =
        'SELECT ${_summaryColumns.map((c) => 'n.$c').join(', ')} FROM notes n';
    if (where.isNotEmpty) sql += ' WHERE ${where.join(' AND ')}';
    sql += ' ORDER BY $order';
    if (query.limit != null) {
      sql += ' LIMIT ? OFFSET ?';
      variables
        ..add(Variable<int>(query.limit!))
        ..add(Variable<int>(query.offset));
    }
    return _query(sql, variables: variables, withContent: false);
  }

  Future<List<NoteRow>> byFolder(String? folderId) => _query(
    'SELECT $_selectColumns FROM notes WHERE folder_id IS ?',
    variables: [Variable<String>(folderId)],
  );

  Future<List<NoteRow>> expired(String limitIso) => _query(
    'SELECT $_selectColumns FROM notes WHERE deleted_at IS NOT NULL AND deleted_at <= ?',
    variables: [Variable<String>(limitIso)],
  );

  Future<List<NoteRow>> trashed() =>
      _query('SELECT $_selectColumns FROM notes WHERE deleted_at IS NOT NULL');

  Future<NoteRow?> byId(String id) async {
    final rows = await _query(
      'SELECT $_selectColumns FROM notes WHERE id = ? LIMIT 1',
      variables: [Variable<String>(id)],
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Búsqueda FTS5 (prefijos, insensible a tildes). [match] ya viene saneado. Devuelve resúmenes
  /// (sin `content`) y respeta el límite de página de [query].
  Future<List<NoteRow>> search(String match, {int? limit}) => _query(
    'SELECT ${_summaryColumns.map((c) => 'n.$c').join(', ')} FROM notes n '
    'JOIN notes_fts ON notes_fts.rowid = n.rowid '
    'WHERE notes_fts MATCH ? AND n.deleted_at IS NULL'
    '${limit != null ? ' LIMIT ?' : ''}',
    variables: [
      Variable<String>(match),
      if (limit != null) Variable<int>(limit),
    ],
    withContent: false,
  );

  Future<List<NoteRow>> _query(
    String sql, {
    List<Variable> variables = const [],
    bool withContent = true,
  }) async {
    final rows = await _db.customSelect(sql, variables: variables).get();
    return [for (final row in rows) _map(row, withContent: withContent)];
  }

  /// Inserta o reemplaza la fila y sus etiquetas. Debe ir dentro de una transacción.
  Future<void> upsert(NoteRow row) async {
    await _db.customInsert(
      'INSERT INTO notes(${_columns.join(', ')}) '
      'VALUES (${List.filled(_columns.length, '?').join(', ')}) '
      'ON CONFLICT(id) DO UPDATE SET '
      'folder_id = excluded.folder_id, title = excluded.title, content = excluded.content, '
      'preview = excluded.preview, tags_json = excluded.tags_json, pinned = excluded.pinned, '
      'created_at = excluded.created_at, updated_at = excluded.updated_at, '
      'deleted_at = excluded.deleted_at, revision = excluded.revision, '
      'sync_status = excluded.sync_status, last_edited_device_id = excluded.last_edited_device_id, '
      'wrapped_key = excluded.wrapped_key, unreadable = excluded.unreadable, '
      'raw_payload = excluded.raw_payload',
      variables: _variables(row),
    );
    await _db.customUpdate(
      'DELETE FROM note_tags WHERE note_id = ?',
      variables: [Variable<String>(row.id)],
    );
    for (final tag in row.tags) {
      await _db.customInsert(
        'INSERT OR IGNORE INTO note_tags(note_id, tag) VALUES (?, ?)',
        variables: [Variable<String>(row.id), Variable<String>(tag)],
      );
    }
    _db.notifyUpdates({const TableUpdate('notes')});
  }

  Future<void> delete(String id) async {
    await _db.customUpdate(
      'DELETE FROM notes WHERE id = ?',
      variables: [Variable<String>(id)],
    );
    _db.notifyUpdates({const TableUpdate('notes')});
  }

  /// Inserta muchas notas de golpe (generador de datos de prueba). Debe ir dentro de una
  /// transacción; notifica una sola vez al final.
  Future<void> upsertAll(Iterable<NoteRow> rows) async {
    for (final row in rows) {
      await _db.customInsert(
        'INSERT OR REPLACE INTO notes(${_columns.join(', ')}) '
        'VALUES (${List.filled(_columns.length, '?').join(', ')})',
        variables: _variables(row),
      );
      for (final tag in row.tags) {
        await _db.customInsert(
          'INSERT OR IGNORE INTO note_tags(note_id, tag) VALUES (?, ?)',
          variables: [Variable<String>(row.id), Variable<String>(tag)],
        );
      }
    }
    _db.notifyUpdates({const TableUpdate('notes')});
  }

  Future<int> count() async {
    final rows = await _db
        .customSelect('SELECT COUNT(*) AS c FROM notes')
        .get();
    return rows.first.read<int>('c');
  }

  Future<int> countWhere(String where) async {
    final rows = await _db
        .customSelect('SELECT COUNT(*) AS c FROM notes WHERE $where')
        .get();
    return rows.first.read<int>('c');
  }

  Future<Map<String, int>> countByFolder() async {
    final rows = await _db
        .customSelect(
          'SELECT folder_id AS f, COUNT(*) AS c FROM notes WHERE deleted_at IS NULL '
          'GROUP BY folder_id',
        )
        .get();
    return {
      for (final row in rows)
        if (row.readNullable<String>('f') != null)
          row.read<String>('f'): row.read<int>('c'),
    };
  }

  Future<Map<String, int>> countByTag() async {
    final rows = await _db
        .customSelect(
          'SELECT t.tag AS tag, COUNT(*) AS c FROM note_tags t '
          'JOIN notes n ON n.id = t.note_id WHERE n.deleted_at IS NULL GROUP BY t.tag',
        )
        .get();
    return {
      for (final row in rows) row.read<String>('tag'): row.read<int>('c'),
    };
  }

  List<Variable> _variables(NoteRow row) => [
    Variable<String>(row.id),
    Variable<String>(row.folderId),
    Variable<String>(row.title),
    Variable<String>(row.content),
    Variable<String>(row.preview),
    Variable<String>(row.tagsJson),
    Variable<int>(row.pinned ? 1 : 0),
    Variable<String>(row.createdAt),
    Variable<String>(row.updatedAt),
    Variable<String>(row.deletedAt),
    Variable<int>(row.revision),
    Variable<String>(row.syncStatus.wire),
    Variable<String>(row.lastEditedDeviceId),
    Variable<String>(row.wrappedKey),
    Variable<int>(row.unreadable ? 1 : 0),
    Variable<String>(row.rawPayload),
  ];

  NoteRow _map(QueryRow row, {bool withContent = true}) => NoteRow(
    id: row.read<String>('id'),
    folderId: row.read<String?>('folder_id'),
    title: row.read<String>('title'),
    content: withContent ? row.read<String>('content') : '',
    preview: row.read<String>('preview'),
    tagsJson: row.read<String>('tags_json'),
    pinned: row.read<int>('pinned') != 0,
    createdAt: row.read<String>('created_at'),
    updatedAt: row.read<String>('updated_at'),
    deletedAt: row.read<String?>('deleted_at'),
    revision: row.read<int>('revision'),
    syncStatus: NoteSyncStatus.values.firstWhere(
      (s) => s.wire == row.read<String>('sync_status'),
      orElse: () => NoteSyncStatus.synced,
    ),
    lastEditedDeviceId: row.read<String>('last_edited_device_id'),
    wrappedKey: row.read<String>('wrapped_key'),
    unreadable: row.read<int>('unreadable') != 0,
    rawPayload: row.read<String?>('raw_payload'),
  );
}
