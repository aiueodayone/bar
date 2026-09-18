import 'package:sqflite/sqflite.dart';

import '../models/genre.dart';
import 'database_helper.dart';

/// ジャンル(カテゴリ)の永続化を担うリポジトリ。
class GenreRepository {
  GenreRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<List<Genre>> fetchGenres() async {
    final db = await _dbHelper.database;
    final rows = await db.query('genres', orderBy: 'sort_order ASC');
    return rows.map(Genre.fromMap).toList();
  }

  Future<void> upsertGenre(Genre genre, {int sortOrder = 0}) async {
    final db = await _dbHelper.database;
    // conflictAlgorithm を指定しないと db.insert() は既定で abort になり、
    // 同じ id の行が既にあると UNIQUE 制約違反で例外を投げてしまう。
    // バックアップ復元は「同じ id なら上書き」を前提にしているため、
    // MemoRepository.upsertMemo と同じく replace にする。
    await db.insert('genres', {
      ...genre.toMap(),
      'sort_order': sortOrder,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateGenre(Genre genre) async {
    final db = await _dbHelper.database;
    await db.update(
      'genres',
      genre.toMap(),
      where: 'id = ?',
      whereArgs: [genre.id],
    );
  }

  Future<void> deleteGenre(String id) async {
    final db = await _dbHelper.database;
    await db.delete('genres', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> nextSortOrder() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT MAX(sort_order) AS m FROM genres');
    final max = result.first['m'] as int?;
    return (max ?? -1) + 1;
  }
}
