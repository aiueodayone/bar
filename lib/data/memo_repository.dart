import 'package:sqflite/sqflite.dart';

import '../models/memo.dart';
import 'database_helper.dart';

/// メモの永続化(検索・ジャンル絞り込みを含む)を担うリポジトリ。
class MemoRepository {
  MemoRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<List<Memo>> fetchMemos({
    String? genreId,
    String searchQuery = '',
  }) async {
    final db = await _dbHelper.database;
    final where = <String>[];
    final args = <Object?>[];

    if (genreId == 'unassigned') {
      where.add('genre_id IS NULL');
    } else if (genreId != null) {
      where.add('genre_id = ?');
      args.add(genreId);
    }

    final trimmed = searchQuery.trim();
    if (trimmed.isNotEmpty) {
      where.add('(title LIKE ? OR content LIKE ?)');
      args.add('%$trimmed%');
      args.add('%$trimmed%');
    }

    final rows = await db.query(
      'memos',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'updated_at DESC',
    );
    return rows.map(Memo.fromMap).toList();
  }

  Future<Memo?> fetchMemoById(String id) async {
    final db = await _dbHelper.database;
    final rows = await db.query('memos', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Memo.fromMap(rows.first);
  }

  Future<void> upsertMemo(Memo memo) async {
    final db = await _dbHelper.database;
    await db.insert(
      'memos',
      memo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteMemo(String id) async {
    final db = await _dbHelper.database;
    await db.delete('memos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countByGenre(String genreId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM memos WHERE genre_id = ?',
      [genreId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
