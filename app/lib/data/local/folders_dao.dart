import 'package:drift/drift.dart';

import 'app_database.dart';
import 'rows.dart';

/// DAO de la tabla `folders`.
class FoldersDao {
  FoldersDao(this._db);

  final AppDatabase _db;

  Future<List<FolderRow>> all() => _query('SELECT * FROM folders');

  Future<FolderRow?> byId(String id) async {
    final rows = await _query('SELECT * FROM folders WHERE id = ? LIMIT 1', [
      Variable<String>(id),
    ]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<FolderRow>> _query(
    String sql, [
    List<Variable> variables = const [],
  ]) async {
    final rows = await _db.customSelect(sql, variables: variables).get();
    return [for (final row in rows) _map(row)];
  }

  Future<void> upsert(FolderRow row) async {
    await _db.customInsert(
      'INSERT INTO folders(id, name, created_at, updated_at, revision, wrapped_key, unreadable, '
      'raw_payload) VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET '
      'name = excluded.name, created_at = excluded.created_at, updated_at = excluded.updated_at, '
      'revision = excluded.revision, wrapped_key = excluded.wrapped_key, '
      'unreadable = excluded.unreadable, raw_payload = excluded.raw_payload',
      variables: [
        Variable<String>(row.id),
        Variable<String>(row.name),
        Variable<String>(row.createdAt),
        Variable<String>(row.updatedAt),
        Variable<int>(row.revision),
        Variable<String>(row.wrappedKey),
        Variable<int>(row.unreadable ? 1 : 0),
        Variable<String>(row.rawPayload),
      ],
    );
    _db.notifyUpdates({const TableUpdate('folders')});
  }

  Future<void> delete(String id) async {
    await _db.customUpdate(
      'DELETE FROM folders WHERE id = ?',
      variables: [Variable<String>(id)],
    );
    _db.notifyUpdates({const TableUpdate('folders')});
  }

  Future<int> count() async {
    final rows = await _db
        .customSelect('SELECT COUNT(*) AS c FROM folders')
        .get();
    return rows.first.read<int>('c');
  }

  FolderRow _map(QueryRow row) => FolderRow(
    id: row.read<String>('id'),
    name: row.read<String>('name'),
    createdAt: row.read<String>('created_at'),
    updatedAt: row.read<String>('updated_at'),
    revision: row.read<int>('revision'),
    wrappedKey: row.read<String>('wrapped_key'),
    unreadable: row.read<int>('unreadable') != 0,
    rawPayload: row.read<String?>('raw_payload'),
  );
}
